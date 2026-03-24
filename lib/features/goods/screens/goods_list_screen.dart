import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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

  const GoodsListScreen({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.initialCategory,
    this.initialWorkTag,
    this.title,
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
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

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
        // Filter chips
        SizedBox(
          height: 48,
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
                  message: '아직 기록이 없어요!\n첫 덕질을 등록해볼까요?',
                  actionText: '굿즈 등록하기',
                  icon: PhosphorIconsBold.sparkle,
                  onAction: () {
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
