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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Duck question mark placeholder
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: DuckColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: DuckColors.outline.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
              child: Icon(
                icon ?? PhosphorIconsBold.question,
                size: 48,
                color: DuckColors.textSub,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: DuckColors.textSub,
                  ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 16),
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
