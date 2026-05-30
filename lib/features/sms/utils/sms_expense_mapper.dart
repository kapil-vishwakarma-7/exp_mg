import '../../expenses/models/expense.dart';
import '../models/parsed_transaction.dart';

Expense parsedTransactionToExpense(ParsedTransaction parsed) {
  final accountNote =
      parsed.account != null ? ' • A/c ${parsed.account}' : '';
  final balanceNote =
      parsed.balance != null ? ' • Bal ${parsed.balance}' : '';

  return Expense(
    title: parsed.merchant,
    amount: parsed.amount,
    category: parsed.category,
    date: parsed.transactionTime,
    transactionTime: parsed.transactionTime,
    note: 'SMS ${parsed.type}$accountNote$balanceNote',
    transactionType: parsed.type,
    merchant: parsed.merchant,
    rawSms: parsed.rawSms,
    smsHash: parsed.dedupeKey,
    createdAt: DateTime.now(),
  );
}
