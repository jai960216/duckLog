import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/pokemon_tcg_service.dart';
import '../services/catalog_service.dart';
import 'catalog_detail_screen.dart';

class PokemonTcgSearchScreen extends ConsumerStatefulWidget {
  const PokemonTcgSearchScreen({super.key});

  @override
  ConsumerState<PokemonTcgSearchScreen> createState() =>
      _PokemonTcgSearchScreenState();
}

class _PokemonTcgSearchScreenState
    extends ConsumerState<PokemonTcgSearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  PokemonSet? _selectedSet;
  bool _isCreating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.trim();
    if (q != _searchQuery) {
      setState(() => _searchQuery = q);
    }
  }

  void _selectSet(PokemonSet set) {
    setState(() => _selectedSet = set);
  }

  void _goBack() {
    if (_selectedSet != null) {
      setState(() => _selectedSet = null);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _createCatalogFromSet(
      PokemonSet set, List<PokemonCard> cards) async {
    setState(() => _isCreating = true);
    try {
      final service = ref.read(catalogServiceProvider);
      final items = cards
          .map((c) => {
                'name': '${c.localId != null ? "#${c.localId} " : ""}${c.name}',
                'photo_url': c.imageUrl,
              })
          .toList();

      final catalog = await service.createCatalogWithItems(
        name: set.name,
        description:
            '포켓몬 카드 ${set.name} (${set.totalCards}장)',
        category: 'photocard',
        coverUrl: set.imageUrl,
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
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '도감 생성에 실패했어요: $e');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedSet?.name ?? '포켓몬 카드'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: _goBack,
        ),
      ),
      body: _selectedSet != null
          ? _buildCardList(_selectedSet!)
          : _buildSetList(),
    );
  }

  // ── Step 1: Set list ──

  Widget _buildSetList() {
    final asyncSets = _searchQuery.isEmpty
        ? ref.watch(pokemonSetsProvider)
        : ref.watch(pokemonSetSearchProvider(_searchQuery));

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '세트 이름 검색',
              prefixIcon: const Icon(PhosphorIconsBold.magnifyingGlass,
                  size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(PhosphorIconsBold.x, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _onSearch(),
            onChanged: (v) {
              if (v.isEmpty && _searchQuery.isNotEmpty) {
                setState(() => _searchQuery = '');
              }
            },
          ),
        ),

        // Sets grid
        Expanded(
          child: asyncSets.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '세트를 불러올 수 없어요\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DuckColors.textSub),
                ),
              ),
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
                itemBuilder: (context, index) =>
                    _buildSetCard(sets[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSetCard(PokemonSet set) {
    return GestureDetector(
      onTap: () => _selectSet(set),
      child: Container(
        decoration: BoxDecoration(
          color: DuckColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DuckColors.surface, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Set image
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: set.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: set.imageUrl!,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => Container(
                          color: DuckColors.surface,
                          child: const Center(
                            child: Icon(PhosphorIconsBold.cards,
                                size: 32, color: DuckColors.textLight),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: DuckColors.surface,
                          child: const Center(
                            child: Icon(PhosphorIconsBold.cards,
                                size: 32, color: DuckColors.textLight),
                          ),
                        ),
                      )
                    : Container(
                        color: DuckColors.surface,
                        child: const Center(
                          child: Icon(PhosphorIconsBold.cards,
                              size: 32, color: DuckColors.textLight),
                        ),
                      ),
              ),
            ),

            // Set info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    set.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${set.totalCards}장',
                    style: const TextStyle(
                      fontSize: 12,
                      color: DuckColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Card list for selected set ──

  Widget _buildCardList(PokemonSet set) {
    final asyncCards = ref.watch(pokemonCardsProvider(set.id));

    return asyncCards.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '카드를 불러올 수 없어요\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DuckColors.textSub),
          ),
        ),
      ),
      data: (cards) {
        if (cards.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                '이 세트에는 카드 데이터가 없어요',
                textAlign: TextAlign.center,
                style: TextStyle(color: DuckColors.textSub),
              ),
            ),
          );
        }
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${cards.length}장의 카드',
                      style: const TextStyle(
                        fontSize: 14,
                        color: DuckColors.textSub,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isCreating
                        ? null
                        : () => _createCatalogFromSet(set, cards),
                    icon: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(PhosphorIconsBold.books, size: 18),
                    label: const Text('전체 도감 만들기'),
                  ),
                ],
              ),
            ),

            // Card grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) =>
                    _buildCardTile(cards[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCardTile(PokemonCard card) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DuckColors.surface, width: 1.5),
      ),
      child: Column(
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
                      placeholder: (_, __) => Container(
                        color: DuckColors.surface,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: DuckColors.surface,
                        child: const Center(
                          child: Icon(PhosphorIconsBold.image,
                              size: 20, color: DuckColors.textLight),
                        ),
                      ),
                    )
                  : Container(
                      color: DuckColors.surface,
                      child: const Center(
                        child: Icon(PhosphorIconsBold.image,
                            size: 20, color: DuckColors.textLight),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              card.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
