import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/utils/constants.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/purchase_service.dart';
import '../services/subscription_service.dart';

class ProScreen extends ConsumerStatefulWidget {
  const ProScreen({super.key});

  @override
  ConsumerState<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends ConsumerState<ProScreen> {
  bool _isLoading = false;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    ref.read(purchaseServiceProvider).startListening();
  }

  @override
  void dispose() {
    ref.read(purchaseServiceProvider).dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await ref.read(purchaseServiceProvider).getProducts();
    if (mounted) setState(() => _products = products);
  }

  @override
  Widget build(BuildContext context) {
    final subAsync = ref.watch(subscriptionProvider);
    final usageAsync = ref.watch(photoUsageProvider);
    final catalogCountAsync = ref.watch(catalogCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('DuckLog Pro')),
      body: subAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: DuckColors.primary),
        ),
        error: (_, __) => const Center(child: Text('정보를 불러올 수 없어요')),
        data: (sub) {
          final isPro = sub.isPro;
          final photoUsage = usageAsync.valueOrNull ?? 0;
          final catalogCount = catalogCountAsync.valueOrNull ?? 0;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 현재 플랜 카드
              DuckCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    Icon(
                      isPro
                          ? PhosphorIconsFill.crown
                          : PhosphorIconsBold.crown,
                      size: 48,
                      color: isPro ? const Color(0xFFFFAA00) : DuckColors.textSub,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPro ? 'Pro 구독 중' : 'Free 플랜',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (isPro && sub.currentPeriodEnd != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${sub.currentPeriodEnd!.year}.${sub.currentPeriodEnd!.month}.${sub.currentPeriodEnd!.day}까지',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 사용량
              Text('이번 달 사용량',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              DuckCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _usageRow(
                      context,
                      icon: PhosphorIconsBold.image,
                      label: '사진 업로드',
                      current: photoUsage,
                      limit: isPro ? null : AppConstants.freePhotoLimit,
                    ),
                    const Divider(height: 24),
                    _usageRow(
                      context,
                      icon: PhosphorIconsBold.book,
                      label: '도감',
                      current: catalogCount,
                      limit: isPro ? null : AppConstants.freeCatalogLimit,
                    ),
                  ],
                ),
              ),

              if (!isPro) ...[
                const SizedBox(height: 24),

                // Pro 혜택
                Text('Pro 혜택',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                DuckCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _benefitRow(context, '사진 업로드 무제한'),
                      _benefitRow(context, '도감 무제한'),
                      _benefitRow(context, '서포터 배지'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 가격
                ..._buildPriceCards(context),
                const SizedBox(height: 16),

                // 복원
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : _restore,
                    child: Text(
                      '구매 복원',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DuckColors.textSub,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPriceCards(BuildContext context) {
    final monthly = _products.where((p) => p.id == PurchaseService.proMonthlyId).firstOrNull;
    final yearly = _products.where((p) => p.id == PurchaseService.proYearlyId).firstOrNull;

    return [
      _priceCard(
        context,
        title: '월간 구독',
        price: monthly?.price ?? '₩2,900/월',
        onTap: monthly != null ? () => _doPurchase(monthly) : null,
      ),
      const SizedBox(height: 12),
      _priceCard(
        context,
        title: '연간 구독',
        price: yearly?.price ?? '₩24,900/년',
        subtitle: '28% 할인',
        onTap: yearly != null ? () => _doPurchase(yearly) : null,
        highlight: true,
      ),
    ];
  }

  Widget _usageRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int current,
    int? limit,
  }) {
    final isOverLimit = limit != null && current >= limit;
    return Row(
      children: [
        Icon(icon, size: 20, color: DuckColors.text),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          limit != null ? '$current / $limit' : '$current (무제한)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isOverLimit ? DuckColors.error : DuckColors.text,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _benefitRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(PhosphorIconsFill.checkCircle,
              size: 18, color: Color(0xFF22C55E)),
          const SizedBox(width: 10),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _priceCard(
    BuildContext context, {
    required String title,
    required String price,
    String? subtitle,
    VoidCallback? onTap,
    bool highlight = false,
  }) {
    return DuckCard(
      margin: EdgeInsets.zero,
      onTap: _isLoading ? null : onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF22C55E),
                          )),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: highlight ? DuckColors.primary : DuckColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    price,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _doPurchase(ProductDetails product) async {
    setState(() => _isLoading = true);
    try {
      final purchaseService = ref.read(purchaseServiceProvider);
      final success = await purchaseService.purchase(product);
      if (!success && mounted) {
        DuckSnackBar.error(context, '구매를 시작할 수 없어요');
      }
      // 실제 구매 완료는 purchaseStream 리스너에서 처리됨
    } catch (e) {
      if (mounted) DuckSnackBar.error(context, '구매에 실패했어요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(purchaseServiceProvider).restorePurchases();
      if (mounted) {
        ref.invalidate(subscriptionProvider);
        DuckSnackBar.info(context, '구매 복원을 요청했어요');
      }
    } catch (e) {
      if (mounted) DuckSnackBar.error(context, '복원에 실패했어요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
