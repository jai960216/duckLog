import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../config/colors.dart';
import '../../services/report_service.dart';

class ReportDialog extends StatefulWidget {
  final String? reportedUserId;
  final String? reportedGoodsId;
  final String title;

  const ReportDialog({
    super.key,
    this.reportedUserId,
    this.reportedGoodsId,
    required this.title,
  });

  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String title,
    String? reportedUserId,
    String? reportedGoodsId,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => ReportDialog(
        title: title,
        reportedUserId: reportedUserId,
        reportedGoodsId: reportedGoodsId,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedReason;
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(PhosphorIconsBold.warningCircle, color: DuckColors.error, size: 22),
          const SizedBox(width: 8),
          Text(widget.title, style: const TextStyle(fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('신고 사유를 선택해주세요', style: TextStyle(fontSize: 14, color: DuckColors.textSub)),
            const SizedBox(height: 12),
            ...ReportReasons.labels.entries.map((entry) {
              return RadioListTile<String>(
                title: Text(entry.value, style: const TextStyle(fontSize: 14)),
                value: entry.key,
                groupValue: _selectedReason,
                onChanged: (v) => setState(() => _selectedReason = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: DuckColors.primary,
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: '상세 설명 (선택)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 3,
              maxLength: 200,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _selectedReason == null
              ? null
              : () {
                  Navigator.pop(context, {
                    'reason': _selectedReason!,
                    'description': _descriptionController.text.trim(),
                  });
                },
          child: Text(
            '신고하기',
            style: TextStyle(
              color: _selectedReason == null ? DuckColors.textLight : DuckColors.error,
            ),
          ),
        ),
      ],
    );
  }
}
