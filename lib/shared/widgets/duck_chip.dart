import 'package:flutter/material.dart';
import '../../config/colors.dart';

class DuckChip extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;

  const DuckChip({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? DuckColors.primaryLight
        : backgroundColor ?? DuckColors.surface;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? Border.all(color: DuckColors.primary, width: 2)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor ?? DuckColors.text),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: textColor ?? DuckColors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
