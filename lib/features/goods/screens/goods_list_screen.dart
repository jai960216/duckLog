import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/goods_service.dart';
import '../widgets/goods_card.dart';
import 'goods_input_screen.dart';
import 'goods_detail_screen.dart';

class GoodsListScreen extends ConsumerStatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String? initialCategory;
  final String? initialWorkTag;
  final String? title;

  /// true이면 기간 필터 UI 표시
  final bool showDateFilter;

  const GoodsListScreen({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.initialCategory,
    this.initialWorkTag,
    this.title,
    this.showDateFilter = false,
  });

  @override
  ConsumerState<GoodsListScreen> createState() => _GoodsListScreenState();
}

class _GoodsListScreenState extends ConsumerState<GoodsListScreen> {
  String? _selectedCategory;
  String? _selectedWorkTag;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _selectedWorkTag = widget.initialWorkTag;

    if (widget.showDateFilter) {
      // 전체 기록 모드: 기간 없이 전체
      _startDate = null;
      _endDate = null;
    } else {
      _startDate = widget.initialStartDate;
      _endDate = widget.initialEndDate;
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: DuckColors.primary,
                  onPrimary: Colors.white,
                  surface: DuckColors.background,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  String get _dateLabel {
    if (_startDate == null || _endDate == null) return '전체 기간';
    final fmt = DateFormat('yy.M.d');
    return '${fmt.format(_startDate!)} ~ ${fmt.format(_endDate!)}';
  }

  bool get _hasDateRange => _startDate != null && _endDate != null;

  GoodsFilter get _filter => GoodsFilter(
        category: _selectedCategory,
        workTag: _selectedWorkTag,
        startDate: _startDate,
        endDate: _endDate,
      );

  bool get _isStandalone => widget.title != null;

  @override
  Widget build(BuildContext context) {
    final goodsAsync = ref.watch(goodsListProvider(_filter));

    final body = Column(
      children: [
        // Date range filter (전체 기록 모드에서만)
        if (widget.showDateFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: DuckColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: _hasDateRange
                            ? Border.all(
                                color: DuckColors.primary, width: 1.5)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIconsBold.calendarBlank,
                            size: 16,
                            color: _hasDateRange
                                ? DuckColors.primary
                                : DuckColors.textSub,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _dateLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _hasDateRange
                                  ? DuckColors.primary
                                  : DuckColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_hasDateRange) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _clearDateRange,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DuckColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(PhosphorIconsBold.x,
                          size: 16, color: DuckColors.textSub),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Category filter chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              DuckChip(
                label: '전체',
                selected: _selectedCategory == null,
                onTap: () => setState(() => _selectedCategory = null),
              ),
              const SizedBox(width: 8),
              ...Goods.categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DuckChip(
                      label: Goods.categoryLabel(cat),
                      selected: _selectedCategory == cat,
                      onTap: () => setState(() {
                        _selectedCategory =
                            _selectedCategory == cat ? null : cat;
                      }),
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // List
        Expanded(
          child: goodsAsync.when(
            data: (goods) {
              if (goods.isEmpty) {
                return DuckEmptyState(
                  message: _hasDateRange
                      ? '해당 기간에 기록이 없어요.'
                      : '아직 기록이 없어요!\n첫 덕질을 등록해볼까요?',
                  actionText: _hasDateRange ? null : '굿즈 등록하기',
                  icon: PhosphorIconsBold.sparkle,
                  onAction: _hasDateRange
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GoodsInputScreen(),
                            ),
                          );
                        },
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(goodsListProvider(_filter));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: goods.length,
                  itemBuilder: (context, index) {
                    return GoodsCard(
                      goods: goods[index],
                      onTap: () async {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                GoodsDetailScreen(goodsId: goods[index].id),
                          ),
                        );
                        if (result == true) {
                          ref.invalidate(goodsListProvider(_filter));
                        }
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const DuckListSkeleton(
              itemSkeleton: GoodsCardSkeleton(),
            ),
            error: (error, _) => DuckEmptyState(
              message: '데이터를 불러올 수 없어요.\n다시 시도해주세요.',
              actionText: '새로고침',
              icon: PhosphorIconsBold.warning,
              onAction: () => ref.invalidate(goodsListProvider(_filter)),
            ),
          ),
        ),
      ],
    );

    if (_isStandalone) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title!)),
        body: body,
      );
    }

    return body;
  }
}
