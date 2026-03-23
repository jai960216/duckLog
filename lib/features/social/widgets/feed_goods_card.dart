import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/duck_card.dart';
import '../../../shared/widgets/duck_chip.dart';
import '../../../shared/widgets/duck_heart_button.dart';

class FeedGoodsCard extends StatelessWidget {
  final Goods goods;
  final Profile owner;
  final VoidCallback? onTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLikeTap;
  final bool isLiked;
  final int likeCount;

  const FeedGoodsCard({
    super.key,
    required this.goods,
    required this.owner,
    this.onTap,
    this.onProfileTap,
    this.onLikeTap,
    this.isLiked = false,
    this.likeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DuckCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Owner header
          GestureDetector(
            onTap: onProfileTap,
            child: Row(
              children: [
                _avatar(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            owner.nickname,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (owner.isVerified) ...[
                            const SizedBox(width: 3),
                            const Icon(PhosphorIconsFill.sealCheck, size: 14, color: Color(0xFF4A9EFF)),
                          ],
                          if (owner.isSupporter) ...[
                            const SizedBox(width: 3),
                            const Icon(PhosphorIconsFill.crown, size: 13, color: Color(0xFFFFAA00)),
                          ],
                        ],
                      ),
                      if (goods.purchasedAt != null)
                        Text(
                          Formatters.timeAgo(goods.createdAt),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: DuckColors.textSub,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Goods photo (if available)
          if (goods.photoUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: goods.photoUrls.first,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: DuckColors.surface,
                      child: const Center(
                        child: Icon(PhosphorIconsBold.image,
                            size: 32, color: DuckColors.textSub),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: DuckColors.surface,
                      child: const Center(
                        child: Icon(PhosphorIconsBold.imageBroken,
                            size: 32, color: DuckColors.textSub),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Goods info
          Text(
            goods.name,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 2,
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
          const SizedBox(height: 8),

          // Tags + like
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
              const Spacer(),
              // Like button
              DuckHeartButton(
                isLiked: isLiked,
                likeCount: likeCount,
                onTap: onLikeTap,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: DuckColors.surface,
        shape: BoxShape.circle,
      ),
      child: owner.avatarUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: owner.avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const Center(child: Text('🐥', style: TextStyle(fontSize: 16))),
                errorWidget: (_, __, ___) =>
                    const Center(child: Text('🐥', style: TextStyle(fontSize: 16))),
              ),
            )
          : const Center(child: Text('🐥', style: TextStyle(fontSize: 16))),
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
