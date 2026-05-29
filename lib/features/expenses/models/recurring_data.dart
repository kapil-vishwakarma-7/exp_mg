class RecurringData {
  const RecurringData({
    this.isRecurring = false,
    this.frequency = 'Monthly',
    this.interval = 1,
    required this.startDate,
    this.endDate,
    this.autoAdd = true,
  });

  final bool isRecurring;
  final String frequency;
  final int interval;
  final DateTime startDate;
  final DateTime? endDate;
  final bool autoAdd;

  static const List<String> frequencies = <String>[
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
  ];

  RecurringData copyWith({
    bool? isRecurring,
    String? frequency,
    int? interval,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? autoAdd,
  }) {
    return RecurringData(
      isRecurring: isRecurring ?? this.isRecurring,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      autoAdd: autoAdd ?? this.autoAdd,
    );
  }

  String get intervalLabel {
    final unit = switch (frequency) {
      'Daily' => interval == 1 ? 'day' : 'days',
      'Weekly' => interval == 1 ? 'week' : 'weeks',
      'Monthly' => interval == 1 ? 'month' : 'months',
      'Yearly' => interval == 1 ? 'year' : 'years',
      _ => 'period',
    };
    return 'Every $interval $unit';
  }

  String? validate() {
    if (!isRecurring) return null;
    if (!frequencies.contains(frequency)) {
      return 'Select a frequency';
    }
    if (interval < 1) {
      return 'Interval must be at least 1';
    }
    return null;
  }
}
