import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../config/colors.dart';

enum DuckSnackBarType { success, error, info }

class DuckSnackBar {
  DuckSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    DuckSnackBarType type = DuckSnackBarType.info,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(_build(message, type: type));
  }

  static void success(BuildContext context, String message) {
    show(context, message, type: DuckSnackBarType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message, type: DuckSnackBarType.error);
  }

  static void info(BuildContext context, String message) {
    show(context, message, type: DuckSnackBarType.info);
  }

  static SnackBar _build(String message, {required DuckSnackBarType type}) {
    final (icon, iconColor, bgColor) = switch (type) {
      DuckSnackBarType.success => (
          PhosphorIconsBold.checkCircle,
          DuckColors.success,
          const Color(0xFFF0FAF3),
        ),
      DuckSnackBarType.error => (
          PhosphorIconsBold.warningCircle,
          DuckColors.error,
          const Color(0xFFFFF0F0),
        ),
      DuckSnackBarType.info => (
          PhosphorIconsBold.info,
          DuckColors.primaryDark,
          DuckColors.primarySurface,
        ),
    };

    return SnackBar(
      content: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: DuckColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      duration: const Duration(seconds: 3),
      dismissDirection: DismissDirection.horizontal,
    );
  }
}
