import 'package:expense_tracker/features/sms/models/sms_message.dart';
import 'package:expense_tracker/features/sms/services/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = SmsParser();

  test('parses Amazon debit with account and balance', () {
    final sms = SmsMessage(
      body:
          'INR 500 debited from A/c XXXX1234 at Amazon. Bal: 10,000',
      date: DateTime(2026, 5, 30),
      sender: 'HDFCBK',
    );
    final result = parser.parse(sms);

    expect(result, isNotNull);
    expect(result!.amount, 500);
    expect(result.type, 'debit');
    expect(result.merchant.toLowerCase(), contains('amazon'));
    expect(result.account, '1234');
    expect(result.balance, 10000);
    expect(result.category, 'Shopping');
  });

  test('parses Swiggy debit', () {
    final sms = SmsMessage(
      body: 'Rs. 500 debited from HDFC at Swiggy',
      date: DateTime(2026, 5, 30),
      sender: 'HDFCBK',
    );
    final result = parser.parse(sms);
    expect(result?.merchant.toLowerCase(), contains('swiggy'));
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
