import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../../goods/services/goods_service.dart';
import '../../goods/widgets/goods_card.dart';
import '../../goods/screens/goods_detail_screen.dart';
import '../../goods/screens/goods_list_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToMyPage;

  const HomeScreen({super.key, this.onNavigateToMyPage});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  String get _monthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  DateTime get _startOfMonth =>
      DateTime(_selectedMonth.year, _selectedMonth.month, 1);

  DateTime get _endOfMonth =>
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthlySpending = ref.watch(monthlySpendingProvider(_monthKey));
    final monthlyStats = ref.watch(monthlyStatsProvider(_monthKey));
    final recentGoods = ref.watch(goodsListProvider(GoodsFilter(
      startDate: _startOfMonth,
      endDate: _endOfMonth,
      pageSize: 5,
    )));

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        const SizedBox(height: 16),

        // Greeting + month selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month selector
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _prevMonth,
                          child: const Icon(
                            PhosphorIconsBold.caretLeft,
                            size: 18,
                            color: DuckColors.textSub,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          Formatters.yearMonth(_selectedMonth),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _nextMonth,
                          child: const Icon(
                            PhosphorIconsBold.caretRight,
                            size: 18,
                            color: DuckColors.textSub,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '덕질 기록',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              // Duck avatar → my page
              GestureDetector(
                onTap: widget.onNavigateToMyPage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: DuckColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset('assets/images/duck_avatar.png', width: 28, height: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Monthly summary card → tap to goods list
        DuckCard(
          color: DuckColors.primarySurface,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GoodsListScreen(
                title: '${Formatters.yearMonth(_selectedMonth)} 지출 내역',
                initialStartDate: _startOfMonth,
                initialEndDate: _endOfMonth,
              ),
            ));
          },
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: DuckColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIconsBold.wallet,
                      size: 20,
                      color: DuckColors.outline,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${Formatters.yearMonth(_selectedMonth)} 지출',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        monthlySpending.when(
                          data: (amount) => Text(
                            Formatters.price(amount),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          loading: () => const SizedBox(
                            width: 80,
                            height: 24,
                            child: LinearProgressIndicator(
                              color: DuckColors.primary,
                              backgroundColor: DuckColors.surface,
                            ),
                          ),
                          error: (_, __) => const Text('-'),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    PhosphorIconsBold.caretRight,
                    size: 18,
                    color: DuckColors.textSub,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Quick stats row from monthly stats provider
              monthlyStats.when(
                data: (stats) => Row(
                  children: [
                    _quickStat(
                      context,
                      '등록 굿즈',
                      '${stats.goodsCount}개',
                      PhosphorIconsBold.package,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => GoodsListScreen(
                            title: '${Formatters.yearMonth(_selectedMonth)} 굿즈',
                            initialStartDate: _startOfMonth,
                            initialEndDate: _endOfMonth,
                          ),
                        ));
                      },
                    ),
                    const SizedBox(width: 12),
                    _quickStat(
                      context,
                      '카테고리',
                      '${stats.categoryCount}종',
                      PhosphorIconsBold.tag,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const StatsScreen(),
                        ));
                      },
                    ),
                    const SizedBox(width: 12),
                    _quickStat(
                      context,
                      '작품',
                      '${stats.workTagCount}개',
                      PhosphorIconsBold.filmStrip,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => GoodsListScreen(
                            title: '${Formatters.yearMonth(_selectedMonth)} 작품별',
                            initialStartDate: _startOfMonth,
                            initialEndDate: _endOfMonth,
                          ),
                        ));
                      },
                    ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Recent goods
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '최근 기록',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GoodsListScreen(
                      title: '${Formatters.yearMonth(_selectedMonth)} 전체 기록',
                      initialStartDate: _startOfMonth,
                      initialEndDate: _endOfMonth,
                    ),
                  ));
                },
                child: Text(
                  '전체보기',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DuckColors.primary,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        recentGoods.when(
          data: (goods) {
            if (goods.isEmpty) {
              return const DuckEmptyState(
                message: '아직 기록이 없어요!\n첫 덕질을 등록해볼까요?',
                icon: PhosphorIconsBold.sparkle,
              );
            }
            return Column(
              children: goods
                  .map((g) => GoodsCard(
                        goods: g,
                        onTap: () async {
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  GoodsDetailScreen(goodsId: g.id),
                            ),
                          );
                          if (result == true) {
                            ref.invalidate(goodsListProvider);
                            ref.invalidate(monthlySpendingProvider);
                            ref.invalidate(monthlyStatsProvider);
                          }
                        },
                      ))
                  .toList(),
            );
          },
          loading: () => DuckSkeleton(
            child: Column(
              children: List.generate(3, (_) => const GoodsCardSkeleton()),
            ),
          ),
          error: (_, __) => const DuckEmptyState(
            message: '데이터를 불러올 수 없어요.',
            icon: PhosphorIconsBold.warning,
          ),
        ),
      ],
    );
  }

  Widget _quickStat(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DuckColors.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: DuckColors.textSub),
              const SizedBox(height: 6),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
