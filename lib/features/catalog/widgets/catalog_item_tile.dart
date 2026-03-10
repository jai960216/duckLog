import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/catalog_item.dart';

class CatalogItemTile extends StatelessWidget {
  final CatalogItem item;
  final VoidCallback? onTap;

  const CatalogItemTile({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DuckColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isCollected ? DuckColors.primary : DuckColors.surface,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: DuckColors.shadow,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Photo or placeholder
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: item.photoUrl != null
                        ? Image.network(
                            item.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
                // Name
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: item.isCollected
                          ? DuckColors.text
                          : DuckColors.textSub,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            // Check overlay for collected items
            if (item.isCollected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: DuckColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsBold.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: DuckColors.surface,
      child: Center(
        child: Icon(
          PhosphorIconsBold.image,
          size: 28,
          color: item.isCollected ? DuckColors.textSub : DuckColors.textLight,
        ),
      ),
    );
  }
}
