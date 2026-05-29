/// Normalizes a [DateTime] to date-only (midnight local).
DateTime dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

/// Compares two dates ignoring time. Returns 0 if equal, -1 if a < b, 1 if a > b.
int compareDate(DateTime a, DateTime b) {
  return dateOnly(a).compareTo(dateOnly(b));
}

/// True when [day] is on or after [due].
bool isOnOrAfterDueDate(DateTime day, DateTime due) {
  return compareDate(day, due) >= 0;
}

/// SQLite-friendly date string (yyyy-MM-dd).
String formatDbDate(DateTime value) {
  final d = dateOnly(value);
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$month-$day';
}

/// ISO8601 string for date queries (normalized to midnight local).
String toIsoDateString(DateTime value) {
  return dateOnly(value).toIso8601String();
}

/// Parses yyyy-MM-dd or full ISO8601, always returns date-only local.
DateTime parseDbDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Empty date string');
  }
  if (trimmed.length >= 10 && !trimmed.contains('T')) {
    final parts = trimmed.split('-');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
  }
  return dateOnly(DateTime.parse(trimmed));
}

/// Returns the next due date after [current] for the given [frequency] and [interval].
DateTime getNextDate(DateTime current, String frequency, int interval) {
  final normalized = dateOnly(current);
  final key = frequency.toLowerCase();

  switch (key) {
    case 'daily':
      return normalized.add(Duration(days: interval));
    case 'weekly':
      return normalized.add(Duration(days: 7 * interval));
    case 'monthly':
      return _addMonths(normalized, interval);
    case 'yearly':
      return _addYears(normalized, interval);
    default:
      return normalized.add(Duration(days: interval));
  }
}

DateTime _addMonths(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final day = date.day.clamp(1, _daysInMonth(year, month));
  return DateTime(year, month, day);
}

DateTime _addYears(DateTime date, int years) {
  final year = date.year + years;
  final day = date.day.clamp(1, _daysInMonth(year, date.month));
  return DateTime(year, date.month, day);
}

int _daysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

String frequencyToDb(String uiFrequency) => uiFrequency.toLowerCase();
