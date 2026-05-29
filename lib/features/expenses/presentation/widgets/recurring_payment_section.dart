import 'package:flutter/material.dart';
import '../../models/recurring_data.dart';
import 'expense_date_picker.dart';

class RecurringPaymentSection extends StatelessWidget {
  const RecurringPaymentSection({
    super.key,
    required this.data,
    required this.onChanged,
  });

  final RecurringData data;
  final ValueChanged<RecurringData> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
            title: const Text(
              'Recurring Payment',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            value: data.isRecurring,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF6E3EFF),
            onChanged: (value) {
              onChanged(data.copyWith(isRecurring: value));
            },
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _RecurringFields(
            data: data,
            onChanged: onChanged,
          ),
          crossFadeState: data.isRecurring
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

class _RecurringFields extends StatelessWidget {
  const _RecurringFields({
    required this.data,
    required this.onChanged,
  });

  final RecurringData data;
  final ValueChanged<RecurringData> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'This expense will repeat automatically',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Frequency',
            child: DropdownButtonFormField<String>(
              initialValue: data.frequency,
              decoration: _fieldDecoration(),
              items: RecurringData.frequencies
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onChanged(data.copyWith(frequency: value));
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Interval',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  _StepperButton(
                    icon: Icons.remove_rounded,
                    onTap: data.interval > 1
                        ? () => onChanged(
                              data.copyWith(interval: data.interval - 1),
                            )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      data.intervalLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  _StepperButton(
                    icon: Icons.add_rounded,
                    onTap: () => onChanged(
                      data.copyWith(interval: data.interval + 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Start Date',
            child: ExpenseDatePicker(
              date: data.startDate,
              onTap: () => _pickDate(
                context,
                initial: data.startDate,
                onPicked: (date) => onChanged(data.copyWith(startDate: date)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'End Date (optional)',
            child: Column(
              children: <Widget>[
                if (data.endDate == null)
                  InkWell(
                    onTap: () => _pickDate(
                      context,
                      initial: data.startDate,
                      onPicked: (date) =>
                          onChanged(data.copyWith(endDate: date)),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: <Widget>[
                          Icon(
                            Icons.event_outlined,
                            size: 18,
                            color: Color(0xFF4B5563),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Not set (tap to add)',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ExpenseDatePicker(
                    date: data.endDate!,
                    onTap: () => _pickDate(
                      context,
                      initial: data.endDate!,
                      onPicked: (date) =>
                          onChanged(data.copyWith(endDate: date)),
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        onChanged(data.copyWith(clearEndDate: true)),
                    child: Text(
                      data.endDate == null ? 'Skip end date' : 'Clear end date',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              value: data.autoAdd,
              activeColor: const Color(0xFF6E3EFF),
              title: const Text(
                'Auto Add Expense',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              onChanged: (value) {
                if (value != null) {
                  onChanged(data.copyWith(autoAdd: value));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context, {
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) onPicked(picked);
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? const Color(0xFFD1D5DB)
                : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}
