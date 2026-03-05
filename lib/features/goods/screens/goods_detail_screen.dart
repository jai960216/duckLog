import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../../catalog/screens/catalog_detail_screen.dart';
import '../../catalog/services/catalog_service.dart';
import '../services/goods_service.dart';
import 'goods_input_screen.dart';

final goodsDetailProvider =
    FutureProvider.autoDispose.family<Goods, String>((ref, id) async {
  return ref.read(goodsServiceProvider).getGoodsById(id);
});

class GoodsDetailScreen extends ConsumerWidget {
  final String goodsId;

  const GoodsDetailScreen({super.key, required this.goodsId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goodsAsync = ref.watch(goodsDetailProvider(goodsId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('굿즈 상세'),
        actions: [
          goodsAsync.whenOrNull(
                data: (goods) => PopupMenuButton<String>(
                  icon: const Icon(PhosphorIconsBold.dotsThree),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) =>
                              GoodsInputScreen(existingGoods: goods),
                        ),
                      );
                      if (result == true) {
                        ref.invalidate(goodsDetailProvider(goodsId));
                      }
                    } else if (value == 'delete') {
                      _confirmDelete(context, ref, goods);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(PhosphorIconsBold.pencil, size: 18),
                          SizedBox(width: 8),
                          Text('수정'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(PhosphorIconsBold.trash, size: 18,
                              color: DuckColors.error),
                          SizedBox(width: 8),
                          Text('삭제',
                              style: TextStyle(color: DuckColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: goodsAsync.when(
        data: (goods) => _buildDetail(context, goods),
        loading: () => const Center(
          child: CircularProgressIndicator(color: DuckColors.primary),
        ),
        error: (e, _) => DuckEmptyState(
          message: '데이터를 불러올 수 없어요.',
          icon: PhosphorIconsBold.warning,
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, Goods goods) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Photos
        if (goods.photoUrls.isNotEmpty) ...[
          SizedBox(
            height: 280,
            child: PageView.builder(
              itemCount: goods.photoUrls.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: goods.photoUrls[index],
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: DuckColors.surface,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: DuckColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Name & Price
        Text(
          goods.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (goods.price != null) ...[
          const SizedBox(height: 8),
          Text(
            Formatters.price(goods.price),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: DuckColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
        const SizedBox(height: 16),

        // Tags
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (goods.category != null)
              DuckChip(
                label: Goods.categoryLabel(goods.category!),
                icon: PhosphorIconsBold.tag,
              ),
            if (goods.workTag != null)
              DuckChip(
                label: goods.workTag!,
                backgroundColor: DuckColors.subLight,
                icon: PhosphorIconsBold.filmStrip,
              ),
            if (goods.artistTag != null)
              DuckChip(
                label: goods.artistTag!,
                backgroundColor: DuckColors.accentLight,
                icon: PhosphorIconsBold.star,
              ),
          ],
        ),
        const SizedBox(height: 20),

        // Info rows
        _infoRow(context, PhosphorIconsBold.calendar, '구매일',
            goods.purchasedAt != null ? Formatters.date(goods.purchasedAt) : '-'),
        _infoRow(context, PhosphorIconsBold.eye, '공개 범위',
            _visibilityLabel(goods.visibility)),

        // Catalog link
        if (goods.catalogItemId != null) _buildCatalogLink(context, goods),

        // Memo
        if (goods.memo != null && goods.memo!.isNotEmpty) ...[
          const SizedBox(height: 16),
          DuckCard(
            margin: EdgeInsets.zero,
            color: DuckColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(PhosphorIconsBold.notepad,
                        size: 16, color: DuckColors.textSub),
                    const SizedBox(width: 8),
                    Text('메모',
                        style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  goods.memo!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCatalogLink(BuildContext context, Goods goods) {
    return FutureBuilder(
      future: CatalogService(Supabase.instance.client)
          .getCatalogForItem(goods.catalogItemId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final (catalog, item, _) = snapshot.data!;
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    CatalogDetailScreen(catalogId: catalog.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(PhosphorIconsBold.books,
                    size: 18, color: DuckColors.primaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${catalog.name} > ${item.name}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DuckColors.primaryDark,
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(PhosphorIconsBold.caretRight,
                    size: 14, color: DuckColors.textSub),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DuckColors.textSub),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DuckColors.textSub,
              )),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _visibilityLabel(String visibility) {
    switch (visibility) {
      case 'public':
        return '전체 공개';
      case 'friends':
        return '친구 공개';
      case 'private':
        return '비공개';
      default:
        return visibility;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Goods goods) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제하시겠어요?'),
        content: Text('\'${goods.name}\'을(를) 삭제하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // close dialog
              try {
                await ref.read(goodsServiceProvider).deleteGoods(goods.id);
                // Invalidate all goods-related providers
                ref.invalidate(goodsListProvider);
                ref.invalidate(monthlySpendingProvider);
                ref.invalidate(goodsDetailProvider(goodsId));
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제에 실패했어요: $e')),
                  );
                }
              }
            },
            child: const Text('삭제',
                style: TextStyle(color: DuckColors.error)),
          ),
        ],
      ),
    );
  }
}
