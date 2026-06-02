import 'package:flutter/material.dart';

class AddAmountInput extends StatelessWidget {
  const AddAmountInput({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: '₹0',
        hintStyle: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
