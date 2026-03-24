import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../models/tcg_types.dart';
import 'tcg_search_screen.dart';

/// 카드 도감 만들기 시 카드 종류를 선택하는 화면
class CardTypeSelectScreen extends StatelessWidget {
  final String? catalogId;

  const CardTypeSelectScreen({super.key, this.catalogId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(catalogId != null ? '카드 추가' : '카드 도감 만들기'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: TcgType.values.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final type = TcgType.values[index];
          return _CardTypeCard(
            type: type,
            onTap: () async {
              final result = await Navigator.of(context).push<dynamic>(
                MaterialPageRoute(
                  builder: (_) => TcgSearchScreen(
                    tcgType: type,
                    catalogId: catalogId,
                  ),
                ),
              );
              // 도감 생성/추가 후 결과 전달
              if (result != null && context.mounted) {
                Navigator.of(context).pop(result);
              }
            },
          );
        },
      ),
    );
  }
}

class _CardTypeCard extends StatelessWidget {
  final TcgType type;
  final VoidCallback onTap;

  const _CardTypeCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DuckColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DuckColors.surface, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: type.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(type.icon, size: 24, color: type.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: DuckColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(PhosphorIconsBold.caretRight,
                size: 18, color: DuckColors.textLight),
          ],
        ),
      ),
    );
  }
}
