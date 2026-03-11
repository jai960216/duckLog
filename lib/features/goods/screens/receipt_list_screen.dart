import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/models/receipt.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/receipt_service.dart';
import 'receipt_scan_screen.dart';

class ReceiptListScreen extends ConsumerStatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  ConsumerState<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends ConsumerState<ReceiptListScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        final current = ref.read(receiptFilterProvider);
        if (current.searchQuery != null) {
          ref.read(receiptFilterProvider.notifier).state =
              current.copyWith(clearSearchQuery: true);
        }
      }
    });
  }

  void _onSearchChanged(String query) {
    final current = ref.read(receiptFilterProvider);
    if (query.isEmpty) {
      ref.read(receiptFilterProvider.notifier).state =
          current.copyWith(clearSearchQuery: true);
    } else {
      ref.read(receiptFilterProvider.notifier).state =
          current.copyWith(searchQuery: query);
    }
  }

  void _setChannelFilter(String? channel) {
    final current = ref.read(receiptFilterProvider);
    ref.read(receiptFilterProvider.notifier).state = channel == null
        ? current.copyWith(clearPurchaseChannel: true)
        : current.copyWith(purchaseChannel: channel);
  }

  void _setExpenseFilter(String? type) {
    final current = ref.read(receiptFilterProvider);
    ref.read(receiptFilterProvider.notifier).state = type == null
        ? current.copyWith(clearExpenseType: true)
        : current.copyWith(expenseType: type);
  }

  void _setCategoryFilter(String? cat) {
    final current = ref.read(receiptFilterProvider);
    ref.read(receiptFilterProvider.notifier).state = cat == null
        ? current.copyWith(clearCategory: true)
        : current.copyWith(category: cat);
  }

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(receiptListProvider);
    final filter = ref.watch(receiptFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '매장명, 메모 검색...',
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text('영수증 관리'),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching
                  ? PhosphorIconsBold.x
                  : PhosphorIconsBold.magnifyingGlass,
              size: 22,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(filter),
          // Receipt list
          Expanded(
            child: receiptsAsync.when(
              data: (receipts) {
                if (receipts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: DuckColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: DuckColors.outline, width: 3),
                          ),
                          child: const Center(
                            child: Text('🧾🐥',
                                style: TextStyle(fontSize: 42)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          filter.hasActiveFilters
                              ? '조건에 맞는 영수증이 없어요'
                              : '아직 영수증이 없어요!\n영수증을 촬영해서 보관해보세요.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: DuckColors.textSub,
                                  ),
                        ),
                        if (!filter.hasActiveFilters) ...[
                          const SizedBox(height: 24),
                          DuckButton(
                            text: '영수증 추가',
                            icon: PhosphorIconsBold.camera,
                            onPressed: () => _addReceipt(context),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: receipts.length,
                  itemBuilder: (context, index) {
                    final receipt = receipts[index];
                    return _buildReceiptCard(context, receipt);
                  },
                );
              },
              loading: () => const Center(
                child:
                    CircularProgressIndicator(color: DuckColors.primary),
              ),
              error: (_, __) => const DuckEmptyState(
                message: '영수증을 불러올 수 없어요.',
                icon: PhosphorIconsBold.warning,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addReceipt(context),
        child: const Icon(PhosphorIconsBold.camera, size: 24),
      ),
    );
  }

  Widget _buildFilterChips(ReceiptFilter filter) {
    return Column(
      children: [
        // 구매 채널 필터
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              DuckChip(
                label: '전체',
                selected: filter.purchaseChannel == null,
                onTap: () => _setChannelFilter(null),
              ),
              const SizedBox(width: 8),
              ...Receipt.purchaseChannels.map((ch) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DuckChip(
                      label: Receipt.purchaseChannelLabel(ch),
                      selected: filter.purchaseChannel == ch,
                      onTap: () => _setChannelFilter(
                          filter.purchaseChannel == ch ? null : ch),
                    ),
                  )),
            ],
          ),
        ),
        // 지출 유형 필터
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              DuckChip(
                label: '전체',
                selected: filter.expenseType == null,
                onTap: () => _setExpenseFilter(null),
              ),
              const SizedBox(width: 8),
              ...Receipt.expenseTypes.map((t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DuckChip(
                      label: Receipt.expenseTypeLabel(t),
                      selected: filter.expenseType == t,
                      onTap: () => _setExpenseFilter(
                          filter.expenseType == t ? null : t),
                    ),
                  )),
            ],
          ),
        ),
        // 굿즈 카테고리 필터
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              DuckChip(
                label: '전체',
                selected: filter.category == null,
                onTap: () => _setCategoryFilter(null),
              ),
              const SizedBox(width: 8),
              ...Goods.categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DuckChip(
                      label: Goods.categoryLabel(cat),
                      selected: filter.category == cat,
                      onTap: () => _setCategoryFilter(
                          filter.category == cat ? null : cat),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard(BuildContext context, Receipt receipt) {
    return DuckCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _showReceiptDetail(context, receipt),
      child: Row(
        children: [
          // Receipt thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Image.network(
                receipt.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: DuckColors.surface,
                  child: const Icon(
                    PhosphorIconsBold.receipt,
                    size: 24,
                    color: DuckColors.textSub,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.storeName ?? '영수증',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (receipt.totalAmount != null) ...[
                      Text(
                        Formatters.price(receipt.totalAmount),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: DuckColors.primary),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      Formatters.date(
                          receipt.purchasedAt ?? receipt.createdAt),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: DuckColors.textSub),
                    ),
                  ],
                ),
                // Tags row
                if (receipt.expenseType != null ||
                    receipt.purchaseChannel != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (receipt.expenseType != null)
                        _tagChip(Receipt.expenseTypeLabel(
                            receipt.expenseType!)),
                      if (receipt.purchaseChannel != null) ...[
                        if (receipt.expenseType != null)
                          const SizedBox(width: 4),
                        _tagChip(Receipt.purchaseChannelLabel(
                            receipt.purchaseChannel!)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(PhosphorIconsBold.caretRight,
              size: 16, color: DuckColors.textSub),
        ],
      ),
    );
  }

  Widget _tagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: DuckColors.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: DuckColors.textSub),
      ),
    );
  }

  void _addReceipt(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ReceiptScanScreen()),
    );
    if (result == true) {
      ref.invalidate(receiptListProvider);
    }
  }

  void _showReceiptDetail(BuildContext context, Receipt receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: DuckColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      receipt.storeName ?? '영수증',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(PhosphorIconsBold.trash,
                        size: 20, color: DuckColors.error),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('영수증 삭제'),
                          content: const Text('이 영수증을 삭제하시겠어요?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('삭제',
                                  style:
                                      TextStyle(color: DuckColors.error)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        try {
                          await ref
                              .read(receiptServiceProvider)
                              .deleteReceipt(receipt.id);
                          ref.invalidate(receiptListProvider);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          debugPrint('삭제 실패: $e');
                          if (context.mounted) {
                            DuckSnackBar.error(context, '삭제 실패');
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            // Receipt image + details
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        receipt.photoUrl,
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: DuckColors.surface,
                          child: const Center(
                            child: Icon(PhosphorIconsBold.imageSquare,
                                size: 48, color: DuckColors.textSub),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (receipt.totalAmount != null) ...[
                      _detailRow(context, '총 금액',
                          Formatters.price(receipt.totalAmount)),
                      const SizedBox(height: 8),
                    ],
                    _detailRow(
                        context,
                        '날짜',
                        Formatters.date(
                            receipt.purchasedAt ?? receipt.createdAt)),
                    const SizedBox(height: 8),
                    if (receipt.purchaseChannel != null) ...[
                      _detailRow(
                          context,
                          '구매 채널',
                          Receipt.purchaseChannelLabel(
                              receipt.purchaseChannel!)),
                      const SizedBox(height: 8),
                    ],
                    if (receipt.expenseType != null) ...[
                      _detailRow(
                          context,
                          '지출 유형',
                          Receipt.expenseTypeLabel(
                              receipt.expenseType!)),
                      const SizedBox(height: 8),
                    ],
                    if (receipt.category != null) ...[
                      _detailRow(context, '카테고리',
                          Goods.categoryLabel(receipt.category!)),
                      const SizedBox(height: 8),
                    ],
                    _detailRow(context, '등록일',
                        Formatters.date(receipt.createdAt)),
                    if (receipt.memo != null &&
                        receipt.memo!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('메모',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: DuckColors.textSub)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: DuckColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(receipt.memo!,
                            style:
                                Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: DuckColors.textSub),
          ),
        ),
        Expanded(
          child:
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
