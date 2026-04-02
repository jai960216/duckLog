import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/colors.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/utils/constants.dart';
import '../../../shared/utils/formatters.dart';
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
  late final PurchaseService _purchaseService;

  @override
  void initState() {
    super.initState();
    _purchaseService = ref.read(purchaseServiceProvider);
    _loadProducts();
    _purchaseService.onVerificationComplete = (success) {
      if (success && mounted) {
        ref.invalidate(photoUsageProvider);
        ref.invalidate(catalogCountProvider);
        DuckSnackBar.info(context, 'Pro 구독이 활성화되었어요!');
      }
    };
  }

  @override
  void dispose() {
    _purchaseService.onVerificationComplete = null;
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await _purchaseService.getProducts();
    if (mounted) setState(() => _products = products);
  }

  @override
  Widget build(BuildContext context) {
    final subAsync = ref.watch(subscriptionProvider);
    final usageAsync = ref.watch(photoUsageProvider);
    final catalogCountAsync = ref.watch(catalogCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('구독 관리')),
      body: subAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: DuckColors.primary),
        ),
        error: (_, _) => const Center(child: Text('정보를 불러올 수 없어요')),
        data: (sub) {
          final isPro = sub.isPro;
          final photoUsage = usageAsync.valueOrNull ?? 0;
          final catalogCount = catalogCountAsync.valueOrNull ?? 0;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              20, 20, 20,
              20 + MediaQuery.of(context).viewPadding.bottom,
            ),
            children: [
              // 현재 플랜 카드
              _buildPlanCard(context, sub, isPro),
              const SizedBox(height: 20),

              // 사용량
              Text('사용량',
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

              if (isPro) ...[
                // Pro 구독자: 관리 옵션
                const SizedBox(height: 24),
                Text('구독 정보',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _buildManageSection(context, sub),
              ] else ...[
                // Free 유저: 업그레이드 유도
                const SizedBox(height: 24),
                Text('Pro 혜택',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                DuckCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _benefitRow(context, '사진 업로드 무제한'),
                      _benefitRow(context, '도감 무제한'),
                      _benefitRow(context, '도감 아이템 무제한'),
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

  Widget _buildPlanCard(BuildContext context, Subscription sub, bool isPro) {
    return DuckCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Icon(
            isPro ? PhosphorIconsFill.crown : PhosphorIconsBold.crown,
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
          if (isPro) ...[
            const SizedBox(height: 4),
            Text(
              sub.planDisplayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DuckColors.textSub,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManageSection(BuildContext context, Subscription sub) {
    final isPlayStore = sub.provider == 'google_play';

    return Column(
      children: [
        // 구독 정보
        DuckCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              if (sub.currentPeriodEnd != null)
                _infoRow(
                  context,
                  icon: PhosphorIconsBold.calendarCheck,
                  label: '다음 갱신일',
                  value: Formatters.date(sub.currentPeriodEnd!),
                ),
              if (sub.currentPeriodStart != null) ...[
                const Divider(height: 24),
                _infoRow(
                  context,
                  icon: PhosphorIconsBold.calendarBlank,
                  label: '구독 시작일',
                  value: Formatters.date(sub.currentPeriodStart!),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 플랜 변경
        if (isPlayStore)
          DuckCard(
            margin: EdgeInsets.zero,
            onTap: _openPlayStoreSubscription,
            child: Row(
              children: [
                Icon(PhosphorIconsBold.arrowsClockwise,
                    size: 20, color: DuckColors.text),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('플랜 변경',
                          style: Theme.of(context).textTheme.bodyMedium),
                      Text(
                        sub.plan == 'pro_monthly' ? '월간 → 연간으로 변경' : '연간 → 월간으로 변경',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DuckColors.textSub,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(PhosphorIconsBold.arrowSquareOut,
                    size: 16, color: DuckColors.textSub),
              ],
            ),
          ),
        if (isPlayStore) const SizedBox(height: 12),

        // 구독 해지
        DuckCard(
          margin: EdgeInsets.zero,
          onTap: () => _confirmCancel(context, isPlayStore),
          child: Row(
            children: [
              Icon(PhosphorIconsBold.xCircle,
                  size: 20, color: DuckColors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('구독 해지',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: DuckColors.error,
                            )),
                    Text(
                      isPlayStore
                          ? '현재 기간이 끝날 때까지 Pro를 이용할 수 있어요'
                          : '즉시 Free 플랜으로 변경돼요',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DuckColors.textSub,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIconsBold.caretRight,
                  size: 16, color: DuckColors.textSub),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context, bool isPlayStore) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구독 해지'),
        content: Text(
          isPlayStore
              ? '해지하더라도 현재 결제 기간이 끝날 때까지 Pro 혜택을 이용할 수 있어요.\n\nGoogle Play에서 구독을 해지합니다.'
              : 'Pro 혜택이 즉시 해제되고 Free 플랜으로 돌아가요.\n\n정말 해지하시겠어요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('해지하기',
                style: TextStyle(color: DuckColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (isPlayStore) {
      _openPlayStoreSubscription();
    } else {
      // 관리자 부여 등 비 Play Store 구독은 앱 내에서 직접 해지
      try {
        await ref.read(subscriptionServiceProvider).cancelSubscription();
        ref.invalidate(subscriptionProvider);
        ref.invalidate(isProProvider);
        if (context.mounted) {
          Navigator.of(context).pop();
          DuckSnackBar.info(context, '구독이 해지되었어요');
        }
      } catch (e) {
        if (context.mounted) {
          DuckSnackBar.error(context, '해지에 실패했어요');
        }
      }
    }
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: DuckColors.text),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
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

  List<Widget> _buildPriceCards(BuildContext context) {
    final monthly =
        _products.where((p) => p.id == PurchaseService.proMonthlyId).firstOrNull;
    final yearly =
        _products.where((p) => p.id == PurchaseService.proYearlyId).firstOrNull;

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
      final success = await _purchaseService.purchase(product);
      if (!success && mounted) {
        DuckSnackBar.error(context, '구매를 시작할 수 없어요');
      }
    } catch (e) {
      if (mounted) DuckSnackBar.error(context, '구매에 실패했어요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    try {
      await _purchaseService.restorePurchases();
      if (mounted) {
        DuckSnackBar.info(context, '구매 복원을 요청했어요. 잠시 기다려주세요.');
      }
    } catch (e) {
      if (mounted) DuckSnackBar.error(context, '복원에 실패했어요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPlayStoreSubscription() async {
    final uri = Uri.parse(
        'https://play.google.com/store/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
