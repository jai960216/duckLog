import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../models/tcg_types.dart';
import '../services/tcg_provider_map.dart';
import '../services/catalog_service.dart';
import 'catalog_detail_screen.dart';

/// 범용 TCG 카드 검색 & 도감 만들기/추가 화면
///
/// [catalogId]가 null이면 새 도감 만들기 모드,
/// non-null이면 기존 도감에 카드 추가 모드.
class TcgSearchScreen extends ConsumerStatefulWidget {
  final TcgType tcgType;
  final String? catalogId;

  const TcgSearchScreen({
    super.key,
    required this.tcgType,
    this.catalogId,
  });

  @override
  ConsumerState<TcgSearchScreen> createState() => _TcgSearchScreenState();
}

class _TcgSearchScreenState extends ConsumerState<TcgSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _setSearchController = TextEditingController();
  final _cardSearchController = TextEditingController();
  String _setSearchQuery = '';
  String _cardSearchQuery = '';
  TcgSet? _selectedSet;
  bool _isCreating = false;
  final Set<int> _selectedCardIndices = {};
  final List<TcgCard> _pickedCards = [];

  bool get _isAddMode => widget.catalogId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _setSearchController.dispose();
    _cardSearchController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_selectedSet != null) {
      setState(() {
        _selectedSet = null;
        _selectedCardIndices.clear();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── 도감 생성 ──

  Future<void> _createCatalogFromCards(
      String name, List<TcgCard> cards,
      {String? coverUrl}) async {
    setState(() => _isCreating = true);
    try {
      final service = ref.read(catalogServiceProvider);
      final items = cards
          .map((c) => {
                'name':
                    '${c.localId != null ? "#${c.localId} " : ""}${c.name}',
                'photo_url': c.imageUrl,
              })
          .toList();

      // 커버 이미지가 없으면 첫 번째 카드 이미지를 커버로 사용
      final effectiveCoverUrl = coverUrl ?? cards.firstOrNull?.imageUrl;

      if (_isAddMode) {
        for (final item in items) {
          await service.addItem(
            catalogId: widget.catalogId!,
            name: item['name']!,
            photoUrl: item['photo_url'],
          );
        }
        if (mounted) {
          ref.invalidate(catalogGroupedItemsProvider(widget.catalogId!));
          ref.invalidate(catalogItemsProvider(widget.catalogId!));
          DuckSnackBar.success(context, '${items.length}장 추가 완료!');
          Navigator.of(context).pop(true);
        }
      } else {
        final catalog = await service.createCatalogWithItems(
          name: name,
          description: '${widget.tcgType.label} $name (${cards.length}장)',
          category: 'card',
          coverUrl: effectiveCoverUrl,
          items: items,
        );
        if (mounted) {
          ref.invalidate(myCatalogsProvider);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CatalogDetailScreen(catalogId: catalog.id),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(
            context, _isAddMode ? '카드 추가에 실패했어요: $e' : '도감 생성에 실패했어요: $e');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedSet?.name ??
            (_isAddMode
                ? '${widget.tcgType.label} 추가'
                : widget.tcgType.label)),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: _goBack,
        ),
        bottom: _selectedSet == null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '세트별'),
                  Tab(text: '카드 검색'),
                ],
              )
            : null,
      ),
      body: _selectedSet != null
          ? _buildSetCardList(_selectedSet!)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSetList(),
                _buildCardSearch(),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════
  // Tab 1: 세트별
  // ══════════════════════════════════════════

  Widget _buildSetList() {
    final asyncSets = _setSearchQuery.isEmpty
        ? ref.watch(tcgSetsProvider(widget.tcgType))
        : ref.watch(tcgSetSearchProvider(widget.tcgType)(_setSearchQuery));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _setSearchController,
            decoration: InputDecoration(
              hintText: '세트 이름 검색',
              prefixIcon:
                  const Icon(PhosphorIconsBold.magnifyingGlass, size: 20),
              suffixIcon: _setSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(PhosphorIconsBold.x, size: 18),
                      onPressed: () {
                        _setSearchController.clear();
                        setState(() => _setSearchQuery = '');
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              setState(
                  () => _setSearchQuery = _setSearchController.text.trim());
            },
            onChanged: (v) {
              if (v.isEmpty && _setSearchQuery.isNotEmpty) {
                setState(() => _setSearchQuery = '');
              }
            },
          ),
        ),
        Expanded(
          child: asyncSets.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('세트를 불러올 수 없어요\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DuckColors.textSub)),
            ),
            data: (sets) {
              if (sets.isEmpty) {
                return const Center(
                  child: Text('검색 결과가 없어요',
                      style: TextStyle(color: DuckColors.textSub)),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: sets.length,
                itemBuilder: (context, index) => _buildSetCard(sets[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSetCard(TcgSet set) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedSet = set;
        _selectedCardIndices.clear();
      }),
      child: Container(
        decoration: BoxDecoration(
          color: DuckColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DuckColors.surface, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: set.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: set.imageUrl!,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => _setPlaceholder(),
                        errorWidget: (_, __, ___) => _setPlaceholder(),
                      )
                    : _setPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(set.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${set.totalCards}장',
                      style: const TextStyle(
                          fontSize: 12, color: DuckColors.textSub)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 세트 선택 후: 카드 목록 ──

  Widget _buildSetCardList(TcgSet set) {
    final asyncCards =
        ref.watch(tcgCardsProvider(widget.tcgType)(set.id));

    return asyncCards.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('카드를 불러올 수 없어요\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DuckColors.textSub)),
      ),
      data: (cards) {
        if (cards.isEmpty) {
          return const Center(
            child: Text('이 세트에는 카드 데이터가 없어요',
                style: TextStyle(color: DuckColors.textSub)),
          );
        }
        final isSelecting = _selectedCardIndices.isNotEmpty;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isSelecting
                          ? '${_selectedCardIndices.length}/${cards.length}장 선택'
                          : '${cards.length}장의 카드',
                      style: const TextStyle(
                          fontSize: 14, color: DuckColors.textSub),
                    ),
                  ),
                  if (isSelecting) ...[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedCardIndices.length == cards.length) {
                            _selectedCardIndices.clear();
                          } else {
                            _selectedCardIndices.addAll(
                                List.generate(cards.length, (i) => i));
                          }
                        });
                      },
                      child: Text(
                          _selectedCardIndices.length == cards.length
                              ? '선택 해제'
                              : '전체 선택'),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: _isCreating
                          ? null
                          : () {
                              final selected = _selectedCardIndices.toList()
                                ..sort();
                              final selectedCards =
                                  selected.map((i) => cards[i]).toList();
                              _createCatalogFromCards(set.name, selectedCards,
                                  coverUrl: set.imageUrl);
                            },
                      icon: _buildButtonIcon(),
                      label: Text(
                          '${_isAddMode ? "추가" : "도감 만들기"} (${_selectedCardIndices.length})'),
                    ),
                  ] else
                    ElevatedButton.icon(
                      onPressed: _isCreating
                          ? null
                          : () => _createCatalogFromCards(set.name, cards,
                              coverUrl: set.imageUrl),
                      icon: _buildButtonIcon(),
                      label: Text(
                          _isAddMode ? '전체 추가' : '전체 도감 만들기'),
                    ),
                ],
              ),
            ),
            if (!isSelecting)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('카드를 길게 눌러 선택할 수 있어요',
                    style: TextStyle(
                        fontSize: 12, color: DuckColors.textLight)),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) =>
                    _buildSelectableCardTile(cards[index], index),
              ),
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════
  // Tab 2: 개별 카드 검색
  // ══════════════════════════════════════════

  Widget _buildCardSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _cardSearchController,
            decoration: InputDecoration(
              hintText: '카드 이름 검색 (영문)',
              prefixIcon:
                  const Icon(PhosphorIconsBold.magnifyingGlass, size: 20),
              suffixIcon: _cardSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(PhosphorIconsBold.x, size: 18),
                      onPressed: () {
                        _cardSearchController.clear();
                        setState(() => _cardSearchQuery = '');
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              final q = _cardSearchController.text.trim();
              if (q.isNotEmpty) setState(() => _cardSearchQuery = q);
            },
          ),
        ),

        // 선택된 카드 표시
        if (_pickedCards.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_pickedCards.length}장 선택됨',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: DuckColors.primary),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _pickedCards.clear()),
                  child: const Text('초기화'),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: _isCreating ? null : _confirmCustomCatalog,
                  icon: _buildButtonIcon(),
                  label: Text(_isAddMode
                      ? '${_pickedCards.length}장 추가'
                      : '도감 만들기'),
                ),
              ],
            ),
          ),

        // 검색 결과
        Expanded(
          child: _cardSearchQuery.isEmpty
              ? Center(
                  child: Text(widget.tcgType.searchHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: DuckColors.textSub)),
                )
              : _buildCardSearchResults(),
        ),
      ],
    );
  }

  Widget _buildCardSearchResults() {
    final asyncCards = ref
        .watch(tcgCardSearchProvider(widget.tcgType)(_cardSearchQuery));

    return asyncCards.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('검색에 실패했어요\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DuckColors.textSub)),
      ),
      data: (cards) {
        if (cards.isEmpty) {
          return const Center(
            child: Text('검색 결과가 없어요',
                style: TextStyle(color: DuckColors.textSub)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            final isPicked = _pickedCards.any((c) => c.id == card.id);
            return _buildPickableCardTile(card, isPicked);
          },
        );
      },
    );
  }

  Future<void> _confirmCustomCatalog() async {
    if (_isAddMode) {
      _createCatalogFromCards('', _pickedCards);
      return;
    }

    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('도감 이름'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '나만의 카드 도감'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final n = nameController.text.trim();
              Navigator.pop(ctx, n.isEmpty ? '나만의 카드 도감' : n);
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
    if (name != null) {
      _createCatalogFromCards(name, _pickedCards);
    }
  }

  // ══════════════════════════════════════════
  // 공통 위젯
  // ══════════════════════════════════════════

  Widget _buildButtonIcon() {
    if (_isCreating) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(
        _isAddMode ? PhosphorIconsBold.plus : PhosphorIconsBold.books,
        size: 18);
  }

  Widget _buildSelectableCardTile(TcgCard card, int index) {
    final isSelecting = _selectedCardIndices.isNotEmpty;
    final isSelected = _selectedCardIndices.contains(index);

    return GestureDetector(
      onTap: isSelecting
          ? () => setState(() {
                isSelected
                    ? _selectedCardIndices.remove(index)
                    : _selectedCardIndices.add(index);
              })
          : null,
      onLongPress: () => setState(() {
        isSelected
            ? _selectedCardIndices.remove(index)
            : _selectedCardIndices.add(index);
      }),
      child: _cardTileContent(card, isSelected),
    );
  }

  Widget _buildPickableCardTile(TcgCard card, bool isPicked) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isPicked) {
            _pickedCards.removeWhere((c) => c.id == card.id);
          } else {
            _pickedCards.add(card);
          }
        });
      },
      child: _cardTileContent(card, isPicked),
    );
  }

  Widget _cardTileContent(TcgCard card, bool isHighlighted) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? DuckColors.primary : DuckColors.surface,
          width: isHighlighted ? 2.5 : 1.5,
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                  child: card.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: card.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: DuckColors.surface),
                          errorWidget: (_, __, ___) => _iconPlaceholder(),
                        )
                      : _iconPlaceholder(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  card.name,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isHighlighted)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: DuckColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(PhosphorIconsBold.check,
                    size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// 세트 목록용 플레이스홀더 (TCG 타입 색상 + 아이콘)
  Widget _setPlaceholder() {
    return Container(
      color: widget.tcgType.color.withValues(alpha: 0.08),
      child: Center(
        child: Icon(widget.tcgType.icon,
            size: 36, color: widget.tcgType.color.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _iconPlaceholder() {
    return Container(
      color: DuckColors.surface,
      child: const Center(
        child: Icon(PhosphorIconsBold.cards,
            size: 28, color: DuckColors.textLight),
      ),
    );
  }
}
