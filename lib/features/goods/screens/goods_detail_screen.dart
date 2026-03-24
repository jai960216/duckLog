import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../services/report_service.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/utils/throttle.dart';
import '../../../shared/widgets/report_dialog.dart';
import '../../../shared/widgets/widgets.dart';
import '../../catalog/screens/catalog_detail_screen.dart';
import '../../catalog/services/catalog_service.dart';
import '../../social/services/feed_service.dart';
import '../services/goods_service.dart';
import 'goods_input_screen.dart';

final goodsDetailProvider =
    FutureProvider.autoDispose.family<Goods, String>((ref, id) async {
  return ref.read(goodsServiceProvider).getGoodsById(id);
});

class GoodsDetailScreen extends ConsumerStatefulWidget {
  final String goodsId;
  final bool readOnly;

  const GoodsDetailScreen(
      {super.key, required this.goodsId, this.readOnly = false});

  @override
  ConsumerState<GoodsDetailScreen> createState() => _GoodsDetailScreenState();
}

class _GoodsDetailScreenState extends ConsumerState<GoodsDetailScreen> {
  bool? _isLiked;
  int? _likeCount;
  bool _likeChanged = false;

  @override
  Widget build(BuildContext context) {
    final goodsAsync = ref.watch(goodsDetailProvider(widget.goodsId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('굿즈 상세'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: () => Navigator.of(context).pop(_likeChanged ? true : null),
        ),
        actions: [
          if (widget.readOnly)
            goodsAsync.whenOrNull(
                  data: (goods) => IconButton(
                    icon: const Icon(PhosphorIconsBold.warningCircle),
                    onPressed: () => _handleReportGoods(goods),
                    tooltip: '신고',
                  ),
                ) ??
                const SizedBox.shrink(),
          if (!widget.readOnly)
            goodsAsync.whenOrNull(
                  data: (goods) => PopupMenuButton<String>(
                    icon: const Icon(PhosphorIconsBold.dotsThree),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final result =
                            await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                GoodsInputScreen(existingGoods: goods),
                          ),
                        );
                        if (result == true) {
                          ref.invalidate(
                              goodsDetailProvider(widget.goodsId));
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
                            Icon(PhosphorIconsBold.trash,
                                size: 18, color: DuckColors.error),
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
        data: (goods) => _buildDetail(context, ref, goods),
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

  Widget _buildDetail(BuildContext context, WidgetRef ref, Goods goods) {
    final isLiked = _isLiked ?? goods.isLikedByMe;
    final likeCount = _likeCount ?? goods.likeCount;

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
                return GestureDetector(
                  onTap: () =>
                      _showPhotoPreview(context, goods.photoUrls, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: goods.photoUrls[index],
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: DuckColors.surface,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: DuckColors.primary,
                          ),
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

        // Like button row
        GestureDetector(
          onTap: () => _handleLike(goods.id, isLiked, likeCount),
          child: Row(
            children: [
              DuckHeartButton(
                isLiked: isLiked,
                likeCount: likeCount,
                size: 22,
              ),
              if (likeCount == 0) ...[
                const SizedBox(width: 4),
                Text(
                  '좋아요',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Info rows
        _infoRow(context, PhosphorIconsBold.calendar, '구매일',
            goods.purchasedAt != null ? Formatters.date(goods.purchasedAt) : '-'),
        if (goods.purchasePlace != null && goods.purchasePlace!.isNotEmpty)
          _infoRow(context, PhosphorIconsBold.mapPin, '구매 장소',
              goods.purchasePlace!),
        _infoRow(context, PhosphorIconsBold.eye, '공개 범위',
            _visibilityLabel(goods.visibility)),

        // Catalog link
        if (goods.catalogItemId != null)
          _buildCatalogLink(context, ref, goods),

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

  Future<void> _handleLike(
      String goodsId, bool currentlyLiked, int currentCount) async {
    // Optimistic update
    setState(() {
      _isLiked = !currentlyLiked;
      _likeCount = currentlyLiked ? currentCount - 1 : currentCount + 1;
    });
    _likeChanged = true;

    try {
      await ref.read(feedServiceProvider).toggleLike(goodsId);
    } catch (_) {
      // Revert on error
      setState(() {
        _isLiked = currentlyLiked;
        _likeCount = currentCount;
      });
    }
  }

  Widget _buildCatalogLink(BuildContext context, WidgetRef ref, Goods goods) {
    final catalogFuture = ref.watch(
      catalogForItemProvider(goods.catalogItemId!),
    );

    return catalogFuture.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final (catalog, item, _) = data;
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
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DuckColors.textSub,
                  )),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  void _showPhotoPreview(
      BuildContext context, List<String> photoUrls, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7,
              ),
              child: PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: photoUrls.length,
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: photoUrls[index],
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(
                          color: DuckColors.primary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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

  Future<void> _handleReportGoods(Goods goods) async {
    // 중복 신고 사전 확인
    try {
      final alreadyReported =
          await ref.read(reportServiceProvider).hasAlreadyReported(goods.userId);
      if (alreadyReported) {
        if (mounted) DuckSnackBar.info(context, '이미 신고한 유저입니다');
        return;
      }
    } catch (_) {}

    if (!mounted) return;

    final result = await ReportDialog.show(
      context,
      title: '굿즈 신고',
      reportedGoodsId: goods.id,
    );

    if (result == null || !mounted) return;

    if (!ActionThrottle.allowReport()) {
      if (mounted) DuckSnackBar.error(context, '잠시 후 다시 시도해주세요');
      return;
    }

    try {
      final reportResult = await ref.read(reportServiceProvider).reportAndBlock(
            reportedUserId: goods.userId,
            reportedGoodsId: goods.id,
            reason: result['reason']!,
            description: result['description'],
          );

      if (reportResult.alreadyReported) {
        if (mounted) DuckSnackBar.info(context, '이미 신고한 유저입니다');
        return;
      }

      if (mounted) {
        DuckSnackBar.show(context, '신고가 접수되고 해당 유저가 차단되었습니다');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) DuckSnackBar.error(context, '신고에 실패했어요');
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Goods goods) {
    final outerNavigator = Navigator.of(context);
    final outerMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('삭제하시겠어요?'),
        content: Text('\'${goods.name}\'을(를) 삭제하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                await ref.read(goodsServiceProvider).deleteGoods(goods.id);
                ref.invalidate(goodsListProvider);
                ref.invalidate(monthlySpendingProvider);
                ref.invalidate(monthlyStatsProvider);
                ref.invalidate(goodsDetailProvider(widget.goodsId));
                outerNavigator.pop(true);
              } catch (e) {
                outerMessenger.showSnackBar(
                  SnackBar(content: Text('삭제에 실패했어요: $e')),
                );
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
