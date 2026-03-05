import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/catalog.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/widgets/duck_card.dart';

class CatalogCard extends StatelessWidget {
  final Catalog catalog;
  final VoidCallback? onTap;

  const CatalogCard({
    super.key,
    required this.catalog,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (catalog.completionRate * 100).toInt();

    return DuckCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            child: catalog.coverUrl != null
                ? Image.network(
                    catalog.coverUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  catalog.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: DuckColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Category + work tag chips
                if (catalog.category != null || catalog.workTag != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        if (catalog.category != null)
                          _chip(Goods.categoryLabel(catalog.category!)),
                        if (catalog.workTag != null) _chip(catalog.workTag!),
                      ],
                    ),
                  ),

                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: catalog.completionRate,
                          backgroundColor: DuckColors.surface,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              DuckColors.primary),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${catalog.collectedItems}/${catalog.totalItems} ($pct%)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DuckColors.textSub,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 120,
      width: double.infinity,
      color: DuckColors.surface,
      child: const Icon(
        PhosphorIconsBold.books,
        size: 40,
        color: DuckColors.textLight,
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: DuckColors.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: DuckColors.text,
        ),
      ),
    );
  }
}
