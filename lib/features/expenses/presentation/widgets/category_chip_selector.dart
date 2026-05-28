import 'package:flutter/material.dart';

class CategoryItem {
  const CategoryItem({
    required this.label,
    required this.icon,
  });

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
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                ),
                const SizedBox(width: 6),
                Text(category.label),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(
              color:
                  isSelected ? Colors.transparent : const Color(0xFFE5E7EB),
            ),
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFF6E3EFF),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }
}
