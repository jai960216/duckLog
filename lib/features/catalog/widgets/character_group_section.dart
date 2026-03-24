import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../../../shared/models/catalog_character.dart';
import '../../../shared/models/catalog_item.dart';
import 'catalog_item_tile.dart';

/// 확장/축소 가능한 캐릭터 섹션 위젯
class CharacterGroupSection extends StatefulWidget {
  final CatalogCharacter character;
  final bool isOwner;
  final bool initiallyExpanded;
  final void Function(CatalogItem item) onItemTap;
  final VoidCallback? onAddItem;
  final VoidCallback? onLongPress;

  const CharacterGroupSection({
    super.key,
    required this.character,
    this.isOwner = false,
    this.initiallyExpanded = false,
    required this.onItemTap,
    this.onAddItem,
    this.onLongPress,
  });

  @override
  State<CharacterGroupSection> createState() => _CharacterGroupSectionState();
}

class _CharacterGroupSectionState extends State<CharacterGroupSection>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animController;
  late Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: _isExpanded ? 1.0 : 0.0,
    );
    _rotationAnim = Tween<double>(begin: 0, end: 0.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.character;
    final total = ch.totalItems;
    final collected = ch.collectedItems;

    return Column(
      children: [
        // Header
        GestureDetector(
          onTap: _toggle,
          onLongPress: widget.onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DuckColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // Expand arrow
                RotationTransition(
                  turns: _rotationAnim,
                  child: const Icon(PhosphorIconsBold.caretRight,
                      size: 16, color: DuckColors.textSub),
                ),
                const SizedBox(width: 8),

                // Character avatar
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: ch.photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: ch.photoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                Container(color: DuckColors.textLight),
                            errorWidget: (_, _, _) => Container(
                              color: DuckColors.textLight,
                              child: const Icon(PhosphorIconsBold.user,
                                  size: 18, color: DuckColors.textSub),
                            ),
                          )
                        : Container(
                            color: DuckColors.textLight,
                            child: const Icon(PhosphorIconsBold.user,
                                size: 18, color: DuckColors.textSub),
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name
                Expanded(
                  child: Text(
                    ch.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Progress
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: collected == total && total > 0
                        ? DuckColors.primary.withValues(alpha: 0.15)
                        : DuckColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$collected/$total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: collected == total && total > 0
                          ? DuckColors.primaryDark
                          : DuckColors.textSub,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded items
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildItemsGrid(ch.items),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildItemsGrid(List<CatalogItem> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return CatalogItemTile(
                item: item,
                onTap: () => widget.onItemTap(item),
              );
            },
          ),
          // Add item button for owner
          if (widget.isOwner && widget.onAddItem != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: widget.onAddItem,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: DuckColors.textLight, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIconsBold.plus,
                          size: 14, color: DuckColors.textSub),
                      SizedBox(width: 6),
                      Text(
                        '아이템 추가',
                        style: TextStyle(
                          fontSize: 12,
                          color: DuckColors.textSub,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
