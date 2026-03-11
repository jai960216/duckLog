import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../config/colors.dart';

class DuckEmptyState extends StatelessWidget {
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? icon;

  const DuckEmptyState({
    super.key,
    required this.message,
    this.actionText,
    this.onAction,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? PhosphorIconsBold.question,
              size: 48,
              color: DuckColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DuckColors.textSub,
                    height: 1.5,
                  ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
