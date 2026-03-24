import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../../goods/services/goods_service.dart';

final categorySpendingProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>(
  (ref, monthKey) async {
    try {
      final parts = monthKey.split('-');
      final month = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return ref.read(goodsServiceProvider).getCategorySpending(month);
    } catch (e) {
      return {};
    }
  },
);

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  String get _monthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categorySpendingProvider(_monthKey));
    final monthlyAsync = ref.watch(monthlySpendingProvider(_monthKey));
    final historyAsync = ref.watch(spendingHistoryProvider(6));
    final workTagAsync = ref.watch(workTagSpendingProvider(_monthKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('지출 통계'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Month selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                    );
                  });
                },
                icon: const Icon(PhosphorIconsBold.caretLeft, size: 20),
              ),
              Text(
                Formatters.yearMonth(_selectedMonth),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    );
                  });
                },
                icon: const Icon(PhosphorIconsBold.caretRight, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Total spending
          DuckCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('총 지출',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                monthlyAsync.when(
                  data: (amount) => Text(
                    Formatters.price(amount),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  loading: () => const SizedBox(
                    height: 32,
                    child: LinearProgressIndicator(
                      color: DuckColors.primary,
                    ),
                  ),
                  error: (_, _) => const Text('-'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Pie chart
          Text('카테고리별 지출',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          categoryAsync.when(
            data: (data) {
              if (data.isEmpty) {
                return const DuckEmptyState(
                  message: '이번 달 지출 기록이 없어요.',
                  icon: PhosphorIconsBold.chartPie,
                );
              }

              final total = data.values.fold<int>(0, (a, b) => a + b);
              final colors = [
                DuckColors.primary,
                DuckColors.accent,
                DuckColors.sub,
                const Color(0xFF6B9FFF),
                DuckColors.tagFigure,
                DuckColors.tagPhotocard,
                DuckColors.tagAlbum,
                DuckColors.tagAcrylic,
                DuckColors.tagOther,
              ];

              final sortedEntries = data.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: sortedEntries
                            .asMap()
                            .entries
                            .map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return PieChartSectionData(
                            value: item.value.toDouble(),
                            title:
                                '${(item.value / total * 100).round()}%',
                            color: colors[index % colors.length],
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: DuckColors.outline,
                            ),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Legend
                  ...sortedEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[index % colors.length],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Goods.categoryLabel(item.key),
                            style:
                                Theme.of(context).textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          Text(
                            Formatters.price(item.value),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: DuckColors.primary),
              ),
            ),
            error: (_, _) => const DuckEmptyState(
              message: '데이터를 불러올 수 없어요.',
              icon: PhosphorIconsBold.warning,
            ),
          ),

          const SizedBox(height: 32),

          // Section 2: Monthly spending trend BarChart
          Text('월별 지출 추이',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          historyAsync.when(
            data: (entries) {
              if (entries.isEmpty || entries.every((e) => e.amount == 0)) {
                return const DuckEmptyState(
                  message: '지출 기록이 없어요.',
                  icon: PhosphorIconsBold.chartBar,
                );
              }

              final maxAmount = entries
                  .map((e) => e.amount)
                  .reduce((a, b) => math.max(a, b));
              final maxY = maxAmount == 0 ? 10000.0 : maxAmount * 1.3;

              return SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= entries.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('M월').format(entries[idx].month),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontSize: 11),
                              ),
                            );
                          },
                          reservedSize: 28,
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: entries.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final isCurrentMonth =
                          item.month.year == _selectedMonth.year &&
                              item.month.month == _selectedMonth.month;
                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: item.amount.toDouble(),
                            color: isCurrentMonth
                                ? DuckColors.primary
                                : DuckColors.surface,
                            width: 28,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ],
                        showingTooltipIndicators:
                            item.amount > 0 ? [0] : [],
                      );
                    }).toList(),
                    barTouchData: BarTouchData(
                      enabled: false,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        tooltipMargin: 4,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final amount = rod.toY.round();
                          if (amount == 0) return null;
                          return BarTooltipItem(
                            Formatters.priceShort(amount),
                            TextStyle(
                              color: DuckColors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(color: DuckColors.primary),
              ),
            ),
            error: (_, _) => const DuckEmptyState(
              message: '데이터를 불러올 수 없어요.',
              icon: PhosphorIconsBold.warning,
            ),
          ),

          const SizedBox(height: 32),

          // Section 3: Work tag Top 5
          Text('작품별 지출 TOP 5',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          workTagAsync.when(
            data: (data) {
              if (data.isEmpty) {
                return const DuckEmptyState(
                  message: '작품 태그를 등록하면 통계를 볼 수 있어요.',
                  icon: PhosphorIconsBold.tag,
                );
              }

              final sortedEntries = data.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final top5 = sortedEntries.take(5).toList();
              final maxValue = top5.first.value;

              return Column(
                children: top5.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final ratio = maxValue > 0 ? item.value / maxValue : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${idx + 1}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: DuckColors.primary,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.key,
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              Formatters.price(item.value),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor: DuckColors.surface,
                            color: DuckColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(color: DuckColors.primary),
              ),
            ),
            error: (_, _) => const DuckEmptyState(
              message: '데이터를 불러올 수 없어요.',
              icon: PhosphorIconsBold.warning,
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
