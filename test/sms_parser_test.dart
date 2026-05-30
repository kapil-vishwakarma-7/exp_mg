import 'package:expense_tracker/features/sms/models/sms_message.dart';
import 'package:expense_tracker/features/sms/services/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = SmsParser();

  test('parses Swiggy debit with date and 12h time', () {
    final sms = SmsMessage(
      body:
          'INR 1200 debited from A/c XXXX4321 at Swiggy on 30 May 12:45PM. Bal: 8000',
      date: DateTime(2026, 5, 30, 10, 0),
      sender: 'HDFCBK',
    );
    final result = parser.parse(sms);

    expect(result, isNotNull);
    expect(result!.amount, 1200);
    expect(result.type, 'debit');
    expect(result.merchant.toLowerCase(), contains('swiggy'));
    expect(result.account, '4321');
    expect(result.balance, 8000);
    expect(result.category, 'Food');
    expect(result.transactionTime.hour, 12);
    expect(result.transactionTime.minute, 45);
    expect(result.transactionTime.day, 30);
    expect(result.transactionTime.month, 5);
  });

  test('parses Amazon UPI payment', () {
    final sms = SmsMessage(
      body: 'Rs 500 paid to Amazon via UPI',
      date: DateTime(2026, 5, 30, 14, 0),
      sender: 'PAYTM',
    );
    final result = parser.parse(sms);

    expect(result, isNotNull);
    expect(result!.amount, 500);
    expect(result.type, 'debit');
    expect(result.merchant.toLowerCase(), contains('amazon'));
    expect(result.category, 'Shopping');
  });

  test('parses credited SMS', () {
    final sms = SmsMessage(
      body: 'INR 2000 credited to your account',
      date: DateTime(2026, 5, 30),
      sender: 'SBI',
    );
    final result = parser.parse(sms);

    expect(result, isNotNull);
    expect(result!.amount, 2000);
    expect(result.type, 'credit');
  });

  test('parses dd-mm-yy with 24h time', () {
    final sms = SmsMessage(
      body: 'INR 800 debited at Zomato on 30-05-26 14:32',
      date: DateTime(2026, 5, 30),
      sender: 'ICICI',
    );
    final result = parser.parse(sms);

    expect(result?.transactionTime.hour, 14);
    expect(result?.transactionTime.minute, 32);
    expect(result?.category, 'Food');
  });

  test('skips OTP', () {
    final sms = SmsMessage(
      body: 'Your OTP is 123456. Do not share.',
      date: DateTime(2026, 5, 30),
      sender: 'BANK',
    );
    expect(parser.parse(sms), isNull);
  });
}
