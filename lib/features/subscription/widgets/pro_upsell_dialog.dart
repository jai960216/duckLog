import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../screens/pro_screen.dart';

class ProUpsellDialog extends StatelessWidget {
  final String feature;

  const ProUpsellDialog({super.key, required this.feature});

  static Future<void> show(BuildContext context, {required String feature}) {
    return showDialog(
      context: context,
      builder: (_) => ProUpsellDialog(feature: feature),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(PhosphorIconsFill.crown,
              size: 24, color: Color(0xFFFFAA00)),
          const SizedBox(width: 8),
          const Text('Pro로 업그레이드'),
        ],
      ),
      content: Text(
        '$feature\n\nDuckLog Pro로 업그레이드하면 제한 없이 사용할 수 있어요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('다음에'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProScreen()),
            );
          },
          child: Text(
            'Pro 보기',
            style: TextStyle(
              color: DuckColors.primaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
