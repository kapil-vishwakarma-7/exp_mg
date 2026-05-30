/// Extracts transaction date/time from Indian bank SMS text.
class SmsDateTimeParser {
  static final List<RegExp> _timePatterns = <RegExp>[
    RegExp(r'(\d{1,2}:\d{2}\s?(?:AM|PM))', caseSensitive: false),
    RegExp(r'\bat\s+(\d{1,2}:\d{2}\s?(?:AM|PM)?)', caseSensitive: false),
    RegExp(r'(\d{1,2}:\d{2})(?!\d)', caseSensitive: false),
  ];

  static final List<RegExp> _dateTimeCombined = <RegExp>[
    RegExp(
      r'(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\s+(\d{1,2}:\d{2}(?:\s?(?:AM|PM))?)',
      caseSensitive: false,
    ),
    RegExp(
      r'on\s+(\d{1,2})\s+([A-Za-z]{3,9})\s+(?:at\s+)?(\d{1,2}:\d{2}\s?(?:AM|PM)?)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(\d{1,2})(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}:\d{2}\s?(?:AM|PM)?)\b',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _datePatterns = <RegExp>[
    RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})'),
    RegExp(
      r'(?:on\s+)?(\d{1,2})\s+([A-Za-z]{3,9})(?:\s+(?:at\s+)?\d{1,2}:\d{2})?',
      caseSensitive: false,
    ),
    RegExp(r'\b(\d{1,2})(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b',
        caseSensitive: false),
  ];

  static const Map<String, int> _months = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  /// Parses inline date/time from SMS; falls back to [smsTimestamp] then [now].
  static DateTime resolve({
    required String body,
    required DateTime smsTimestamp,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();

    for (final pattern in _dateTimeCombined) {
      final match = pattern.firstMatch(body);
      if (match == null) continue;
      final parsed = _parseCombinedMatch(match, pattern.pattern);
      if (parsed != null) return parsed;
    }

    DateTime? datePart;
    for (final pattern in _datePatterns) {
      final match = pattern.firstMatch(body);
      if (match == null) continue;
      datePart = _parseDateMatch(match, pattern.pattern, referenceYear: clock.year);
      if (datePart != null) break;
    }

    Duration? timePart;
    for (final pattern in _timePatterns) {
      final match = pattern.firstMatch(body);
      if (match == null) continue;
      timePart = _parseTimeMatch(match.group(1)!);
      if (timePart != null) break;
    }

    if (datePart != null && timePart != null) {
      return DateTime(
        datePart.year,
        datePart.month,
        datePart.day,
        timePart.inHours,
        timePart.inMinutes.remainder(60),
      );
    }

    if (datePart != null) {
      return DateTime(datePart.year, datePart.month, datePart.day);
    }

    if (_hasTimeComponent(smsTimestamp)) {
      return DateTime(
        smsTimestamp.year,
        smsTimestamp.month,
        smsTimestamp.day,
        smsTimestamp.hour,
        smsTimestamp.minute,
        smsTimestamp.second,
      );
    }

    if (smsTimestamp.millisecondsSinceEpoch > 0) {
      return DateTime(
        smsTimestamp.year,
        smsTimestamp.month,
        smsTimestamp.day,
      );
    }

    return clock;
  }

  static bool _hasTimeComponent(DateTime value) {
    return value.hour != 0 || value.minute != 0 || value.second != 0;
  }

  static DateTime? _parseCombinedMatch(RegExpMatch match, String pattern) {
    if (pattern.contains('on\\s+')) {
      final day = int.tryParse(match.group(1)!);
      final month = _monthIndex(match.group(2)!);
      final time = _parseTimeMatch(match.group(3)!);
      if (day == null || month == null || time == null) return null;
      return DateTime(
        DateTime.now().year,
        month,
        day,
        time.inHours,
        time.inMinutes.remainder(60),
      );
    }

    if (pattern.contains('Jan|Feb')) {
      final day = int.tryParse(match.group(1)!);
      final month = _monthIndex(match.group(2)!);
      final time = _parseTimeMatch(match.group(3)!);
      if (day == null || month == null || time == null) return null;
      return DateTime(
        DateTime.now().year,
        month,
        day,
        time.inHours,
        time.inMinutes.remainder(60),
      );
    }

    final p1 = int.parse(match.group(1)!);
    final p2 = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    final time = _parseTimeMatch(match.group(4)!);
    if (time == null) return null;
    final dayFirst = p1 <= 31 && p2 <= 12;
    return DateTime(
      year,
      dayFirst ? p2 : p1,
      dayFirst ? p1 : p2,
      time.inHours,
      time.inMinutes.remainder(60),
    );
  }

  static DateTime? _parseDateMatch(
    RegExpMatch match,
    String pattern, {
    required int referenceYear,
  }) {
    if (pattern.contains('Jan|Feb')) {
      final day = int.tryParse(match.group(1)!);
      final month = _monthIndex(match.group(2)!);
      if (day == null || month == null) return null;
      return DateTime(referenceYear, month, day);
    }

    if (pattern.contains('[A-Za-z]{3,9}')) {
      final day = int.tryParse(match.group(1)!);
      final month = _monthIndex(match.group(2)!);
      if (day == null || month == null) return null;
      return DateTime(referenceYear, month, day);
    }

    final p1 = int.parse(match.group(1)!);
    final p2 = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    final dayFirst = p1 <= 31 && p2 <= 12;
    return DateTime(
      year,
      dayFirst ? p2 : p1,
      dayFirst ? p1 : p2,
    );
  }

  static Duration? _parseTimeMatch(String raw) {
    final trimmed = raw.trim().toUpperCase();
    final match = RegExp(r'(\d{1,2}):(\d{2})\s?(AM|PM)?').firstMatch(trimmed);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3);

    if (meridiem == 'PM' && hour < 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;

    return Duration(hours: hour, minutes: minute);
  }

  static int? _monthIndex(String token) {
    if (token.isEmpty) return null;
    final key = token.toLowerCase();
    return _months[key] ?? _months[key.substring(0, 3)];
  }
}
