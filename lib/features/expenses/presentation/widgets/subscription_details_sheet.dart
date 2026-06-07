import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Data returned when the user fills in subscription details.
class SubscriptionDetails {
  const SubscriptionDetails({
    required this.displayName,
    required this.frequency,
    required this.billingDay,
  });

  /// User-editable name shown in the subscriptions list (e.g. "Netflix HD").
  final String displayName;

  /// 'monthly' | 'weekly' | 'yearly' | 'quarterly'
  final String frequency;

  /// Day of month (1–28) for monthly/yearly billing, or 1–7 for weekly.
  final int billingDay;
}

/// Bottom sheet asking the user to confirm subscription details before the
/// pending recurring transaction is moved into the confirmed list.
///
/// Pre-fills whatever the parser already detected so the user only needs to
/// correct anything that looks wrong.
class SubscriptionDetailsSheet extends StatefulWidget {
  const SubscriptionDetailsSheet({
    super.key,
    required this.merchantName,
    required this.amount,
    required this.detectedFrequency,
    required this.transactionDate,
  });

  final String merchantName;
  final double amount;

  /// Frequency string from the parser/subscription detector, e.g. 'monthly'.
  final String detectedFrequency;

  /// Date of the SMS transaction — used to pre-fill billing day.
  final DateTime transactionDate;

  static Future<SubscriptionDetails?> show(
    BuildContext context, {
    required String merchantName,
    required double amount,
    required String detectedFrequency,
    required DateTime transactionDate,
  }) {
    return showModalBottomSheet<SubscriptionDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubscriptionDetailsSheet(
        merchantName: merchantName,
        amount: amount,
        detectedFrequency: detectedFrequency,
        transactionDate: transactionDate,
      ),
    );
  }

  @override
  State<SubscriptionDetailsSheet> createState() =>
      _SubscriptionDetailsSheetState();
}

class _SubscriptionDetailsSheetState extends State<SubscriptionDetailsSheet> {
  static const List<String> _frequencies = <String>[
    'monthly',
    'weekly',
    'yearly',
    'quarterly',
  ];

  late final TextEditingController _nameController;
  late String _frequency;
  late int _billingDay;

  @override
  void initState() {
    super.initState();
    // Pre-fill name: capitalise merchant
    final name = widget.merchantName.isNotEmpty
        ? widget.merchantName[0].toUpperCase() +
            widget.merchantName.substring(1).toLowerCase()
        : '';
    _nameController = TextEditingController(text: name);

    // Pre-fill frequency from detector; default to monthly if unknown
    _frequency = _frequencies.contains(widget.detectedFrequency)
        ? widget.detectedFrequency
        : 'monthly';

    // Pre-fill billing day from the transaction date
    _billingDay = widget.transactionDate.day.clamp(1, 28);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _frequencyLabel(String f) {
    switch (f) {
      case 'weekly':
        return 'Weekly';
      case 'yearly':
        return 'Yearly';
      case 'quarterly':
        return 'Quarterly';
      default:
        return 'Monthly';
    }
  }

  String get _billingDayLabel {
    if (_frequency == 'weekly') {
      const days = <String>[
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return days[(_billingDay - 1).clamp(0, 6)];
    }
    return 'Day $_billingDay of month';
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subscription name')),
      );
      return;
    }
    Navigator.of(context).pop(
      SubscriptionDetails(
        displayName: name,
        frequency: _frequency,
        billingDay: _billingDay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final formattedAmount =
        NumberFormat.currency(symbol: '₹', decimalDigits: 2)
            .format(widget.amount);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── Handle ──────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: <Widget>[
                  // Recurring icon badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.repeat_rounded,
                      color: cs.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Set up Subscription',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          '$formattedAmount recurring payment detected',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),
            Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),

            // ── Form fields ──────────────────────────────────────────────────
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                shrinkWrap: true,
                children: <Widget>[
                  // Name
                  _FieldLabel(label: 'Subscription Name', cs: cs),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Netflix, Spotify',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Frequency
                  _FieldLabel(label: 'Billing Frequency', cs: cs),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _frequencies.map((f) {
                      final selected = _frequency == f;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _frequency = f;
                          // Reset billing day when switching to weekly
                          if (f == 'weekly') {
                            _billingDay =
                                widget.transactionDate.weekday.clamp(1, 7);
                          } else {
                            _billingDay =
                                widget.transactionDate.day.clamp(1, 28);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? cs.primary
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _frequencyLabel(f),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : cs.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Billing day
                  _FieldLabel(
                    label: _frequency == 'weekly'
                        ? 'Billing Day of Week'
                        : 'Billing Day of Month',
                    cs: cs,
                  ),
                  const SizedBox(height: 10),
                  _BillingDayPicker(
                    frequency: _frequency,
                    value: _billingDay,
                    onChanged: (v) => setState(() => _billingDay = v),
                    cs: cs,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _billingDayLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Save button ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF6E3EFF), Color(0xFF8B5CFF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF6E3EFF).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: _save,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Confirm & Track Subscription',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Billing day picker ────────────────────────────────────────────────────────

class _BillingDayPicker extends StatelessWidget {
  const _BillingDayPicker({
    required this.frequency,
    required this.value,
    required this.onChanged,
    required this.cs,
  });

  final String frequency;
  final int value;
  final ValueChanged<int> onChanged;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isWeekly = frequency == 'weekly';
    final count = isWeekly ? 7 : 28;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(count, (i) {
        final day = i + 1;
        final selected = day == value;
        final label = isWeekly
            ? <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'][i]
            : '$day';
        return GestureDetector(
          onTap: () => onChanged(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: isWeekly ? 40 : 36,
            height: isWeekly ? 40 : 36,
            decoration: BoxDecoration(
              color: selected
                  ? cs.primary
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(isWeekly ? 20 : 10),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isWeekly ? 13 : 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}
