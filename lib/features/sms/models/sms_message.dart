class SmsMessage {
  const SmsMessage({
    required this.body,
    required this.date,
    required this.sender,
  });

  final String body;
  final DateTime date;
  final String sender;
}
