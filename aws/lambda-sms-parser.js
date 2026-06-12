import {
    BedrockRuntimeClient,
    ConverseCommand,
  } from "@aws-sdk/client-bedrock-runtime";
  
  const REGION = process.env.AWS_REGION || "us-east-1";
  const MODEL_ID = "amazon.nova-lite-v1:0";
  
  const MAX_BATCH_SIZE = 10;
  const TIMEOUT_MS = 5000;
  
  const client = new BedrockRuntimeClient({ region: REGION });
  
  export const handler = async (event) => {
    console.log("===== START =====");
    console.log("RAW EVENT:", JSON.stringify(event));
  
    try {
      let body;
      if (event.body) {
        body =
          typeof event.body === "string"
            ? JSON.parse(event.body)
            : event.body;
      } else {
        body = event;
      }
  
      console.log("PARSED BODY:", JSON.stringify(body));
  
      let messages = body.messages || [];
  
      if (body.sms) {
        messages = [body.sms];
      }
  
      if (!Array.isArray(messages) || messages.length === 0) {
        return response(400, { success: false, error: "No messages provided" });
      }
  
      if (messages.length > MAX_BATCH_SIZE) {
        return response(400, {
          success: false,
          error: `Max ${MAX_BATCH_SIZE} messages allowed`,
        });
      }
  
      console.log("TOTAL MESSAGES:", messages.length);
  
      const results = await Promise.allSettled(
        messages.map((sms, i) => processSingleSMS(sms, i))
      );
  
      const finalResults = results.map((res) =>
        res.status === "fulfilled"
          ? { success: true, data: res.value }
          : { success: false, error: res.reason?.message || "Unknown error" }
      );
  
      return response(200, {
        success: true,
        data: finalResults,
      });
  
    } catch (err) {
      console.error("FATAL ERROR:", err);
  
      return response(500, {
        success: false,
        error: err.message,
      });
    }
  };
  
  // 🔥 PROCESS SINGLE SMS
  async function processSingleSMS(sms, index) {
    console.log(`--- SMS ${index} ---`);
  
    if (!sms) throw new Error("Empty SMS");
  
    const cleanedSms = sms.replace(/\d{6,}/g, "XXXX").trim();
  
    console.log("CLEANED:", cleanedSms);
  
    const ruleSub = detectSubscription(cleanedSms);
  
    const prompt = `
  Extract structured financial data from this SMS.
  
  Return STRICT JSON ONLY.
  
  Rules:
  - No explanation
  - No markdown
  - Must start with { and end with }
  
  Schema:
  {
    "amount": number|null,
    "type": "expense|income|transfer|unknown",
    "merchant": string|null,
    "confidence": "low|medium|high",
    "is_subscription": boolean,
    "subscription_confidence": "low|medium|high"
  }
  
  SMS:
  ${cleanedSms}
  `;
  
    const command = new ConverseCommand({
      modelId: MODEL_ID,
      messages: [
        {
          role: "user",
          content: [{ text: prompt }],
        },
      ],
      inferenceConfig: {
        maxTokens: 200,
        temperature: 0,
      },
    });
  
    const timeout = new Promise((_, reject) =>
      setTimeout(() => reject(new Error("Timeout")), TIMEOUT_MS)
    );
  
    const result = await Promise.race([
      client.send(command),
      timeout,
    ]);
  
    const rawText = result?.output?.message?.content?.[0]?.text;
  
    console.log("RAW MODEL:", rawText);
  
    if (!rawText) throw new Error("Empty model response");
  
    // 🔥 CLEAN JSON
    const cleanedJSON = extractJSON(rawText);
  
    console.log("CLEANED JSON:", cleanedJSON);
  
    let parsed;
  
    try {
      parsed = JSON.parse(cleanedJSON);
    } catch (err) {
      console.error("JSON FAIL:", err);
      throw new Error("Invalid JSON from model");
    }
  
    // 🔥 MERGE AI + RULE
    const aiSub = parsed.is_subscription;
    const aiConf = parsed.subscription_confidence || "low";
  
    let finalSub = aiSub;
    let finalConf = aiConf;
  
    if (ruleSub.confidence === "high") {
      finalSub = true;
      finalConf = "high";
    }
  
    if (!aiSub && ruleSub.confidence === "medium") {
      finalSub = true;
      finalConf = "medium";
    }
  
    parsed.is_subscription = finalSub;
    parsed.subscription_confidence = finalConf;
  
    return parsed;
  }
  
  // 🔧 CLEAN MODEL OUTPUT
  function extractJSON(text) {
    if (!text) return text;
  
    // Remove markdown
    text = text.replace(/```json/g, "").replace(/```/g, "");
  
    const first = text.indexOf("{");
    const last = text.lastIndexOf("}");
  
    if (first !== -1 && last !== -1) {
      return text.substring(first, last + 1);
    }
  
    return text.trim();
  }
  
  // 🔍 RULE-BASED SUBSCRIPTION
  function detectSubscription(sms) {
    const text = sms.toLowerCase();
  
    const keywords = [
      "subscription",
      "renewal",
      "auto debit",
      "autodebit",
      "mandate",
      "standing instruction",
      "recurring",
    ];
  
    const merchants = [
      "netflix",
      "spotify",
      "prime",
      "hotstar",
      "zee5",
      "sony liv",
      "apple",
      "google",
      "youtube",
    ];
  
    let score = 0;
  
    keywords.forEach((k) => {
      if (text.includes(k)) score += 2;
    });
  
    merchants.forEach((m) => {
      if (text.includes(m)) score += 1;
    });
  
    let confidence = "low";
    if (score >= 3) confidence = "high";
    else if (score >= 2) confidence = "medium";
  
    return {
      isSubscription: score >= 2,
      confidence,
    };
  }
  
  // 🔧 RESPONSE
  function response(statusCode, body) {
    return {
      statusCode,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify(body),
    };
  }