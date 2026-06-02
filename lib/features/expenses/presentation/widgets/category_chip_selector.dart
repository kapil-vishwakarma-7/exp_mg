import 'package:flutter/material.dart';

class CategoryItem {
  const CategoryItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class CategoryChipSelector extends StatelessWidget {
  const CategoryChipSelector({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<CategoryItem> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.label == selectedCategory;

          return ChoiceChip(
            selected: isSelected,
            onSelected: (selected) => onSelected(category.label),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  category.icon,
                  size: 18,
                  color: isSelected ? Colors.white : cs.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(category.label),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(
              color: isSelected ? Colors.transparent : cs.outlineVariant,
            ),
            backgroundColor: cs.surface,
            selectedColor: const Color(0xFF6E3EFF),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }
}
