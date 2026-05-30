const Map<String, String> smsCategoryKeywords = <String, String>{
  'swiggy': 'Food',
  'zomato': 'Food',
  'dominos': 'Food',
  'amazon': 'Shopping',
  'flipkart': 'Shopping',
  'myntra': 'Shopping',
  'uber': 'Travel',
  'ola': 'Travel',
  'netflix': 'Entertainment',
  'hotstar': 'Entertainment',
};

String detectSmsCategory(String merchant, {String? messageBody}) {
  final body = messageBody?.toLowerCase() ?? '';
  if (body.contains('atm') || body.contains('withdrawn')) {
    return 'Cash';
  }

  final lower = merchant.toLowerCase();
  for (final entry in smsCategoryKeywords.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return 'Others';
}
