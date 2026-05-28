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
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: '₹0',
        hintStyle: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: Color(0xFFB8C0CF),
        ),
      ),
    );
  }
}
