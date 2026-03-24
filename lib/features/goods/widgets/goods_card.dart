import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/duck_card.dart';
import '../../../shared/widgets/duck_chip.dart';

class GoodsCard extends StatelessWidget {
  final Goods goods;
  final VoidCallback? onTap;

  const GoodsCard({
    super.key,
    required this.goods,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DuckCard(
      onTap: onTap,
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: goods.photoUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: goods.photoUrls.first,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: DuckColors.surface,
                        child: const Icon(
                          PhosphorIconsBold.image,
                          color: DuckColors.textSub,
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: DuckColors.surface,
                        child: const Icon(
                          PhosphorIconsBold.imageBroken,
                          color: DuckColors.textSub,
                        ),
                      ),
                    )
                  : Container(
                      color: DuckColors.surface,
                      child: const Icon(
                        PhosphorIconsBold.package,
                        color: DuckColors.textSub,
                        size: 28,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goods.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (goods.price != null)
                  Text(
                    Formatters.price(goods.price),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: DuckColors.primary,
                        ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (goods.category != null)
                      Flexible(
                        flex: 0,
                        child: DuckChip(
                          label: Goods.categoryLabel(goods.category!),
                          backgroundColor: _categoryColor(goods.category!),
                        ),
                      ),
                    if (goods.workTag != null) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: DuckChip(
                          label: goods.workTag!,
                          backgroundColor: DuckColors.subLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Date & Likes
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                goods.purchasedAt != null
                    ? Formatters.dateShort(goods.purchasedAt!)
                    : '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (goods.likeCount > 0 || goods.isLikedByMe) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      goods.isLikedByMe
                          ? PhosphorIconsFill.heart
                          : PhosphorIconsBold.heart,
                      size: 14,
                      color: DuckColors.error,
                    ),
                    if (goods.likeCount > 0) ...[
                      const SizedBox(width: 3),
                      Text(
                        '${goods.likeCount}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DuckColors.error,
                            ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'figure':
        return DuckColors.tagFigure;
      case 'photocard':
        return DuckColors.tagPhotocard;
      case 'card':
        return DuckColors.tagCard;
      case 'album':
        return DuckColors.tagAlbum;
      case 'acrylic':
        return DuckColors.tagAcrylic;
      default:
        return DuckColors.tagOther;
    }
  }
}
