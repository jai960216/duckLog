import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../services/anilist_figure_service.dart';
import '../../calendar/services/igdb_service.dart';
import '../../calendar/services/webtoon_service.dart';
import '../services/catalog_service.dart';
import '../widgets/catalog_setup_form.dart';
import 'catalog_detail_screen.dart';

class AnilistCharacterScreen extends ConsumerStatefulWidget {
  const AnilistCharacterScreen({super.key});

  @override
  ConsumerState<AnilistCharacterScreen> createState() =>
      _AnilistCharacterScreenState();
}

class _AnilistCharacterScreenState
    extends ConsumerState<AnilistCharacterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  // 'ANIME', 'MANGA', 'WEBTOON', 'GAME'
  String _sourceType = 'ANIME';

  // Step 0: search, Step 1: character select, Step 2: setup
  int _step = 0;
  AnilistWork? _selectedWork;
  IgdbGame? _selectedGame;
  WebtoonData? _selectedWebtoon;
  final Set<int> _selectedIds = {};
  List<CharacterSetupData> _selectedSetupChars = [];

  // For setup form context
  String? _workTitle;
  String? _coverUrl;

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

  void _selectWork(AnilistWork work) {
    setState(() {
      _selectedWork = work;
      _selectedGame = null;
      _selectedIds.clear();
      _step = 1;
    });
  }

  void _selectGame(IgdbGame game) {
    setState(() {
      _selectedGame = game;
      _selectedWork = null;
      _selectedWebtoon = null;
      _selectedIds.clear();
      _step = 1;
    });
  }

  void _selectWebtoon(WebtoonData webtoon) {
    // 웹툰은 캐릭터 API가 없으므로 바로 설정 단계로 이동
    setState(() {
      _selectedWebtoon = webtoon;
      _selectedWork = null;
      _selectedGame = null;
      _selectedIds.clear();
      _selectedSetupChars = [
        CharacterSetupData(name: '캐릭터', items: [ItemSetupData(name: '아이템')]),
      ];
      _workTitle = webtoon.displayTitle;
      _coverUrl = webtoon.thumbnailUrl;
      _step = 2;
    });
  }

  void _goBack() {
    if (_step == 2) {
      // 웹툰은 캐릭터 단계가 없으므로 검색 화면으로
      if (_selectedWebtoon != null) {
        setState(() {
          _selectedWebtoon = null;
          _step = 0;
        });
      } else {
        setState(() => _step = 1);
      }
    } else if (_step == 1) {
      setState(() {
        _selectedWork = null;
        _selectedGame = null;
        _selectedWebtoon = null;
        _selectedIds.clear();
        _step = 0;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAllGeneric(int totalCount, Iterable<int> allIds) {
    setState(() {
      if (_selectedIds.length == totalCount) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  void _goToSetupAnilist(List<AnilistCharacter> allChars) {
    final selected =
        allChars.where((c) => _selectedIds.contains(c.id)).toList();
    if (selected.isEmpty) return;
    setState(() {
      _selectedSetupChars = selected
          .map((ch) => CharacterSetupData(
                name: ch.displayName,
                photoUrl: ch.imageUrl,
                externalId: ch.id.toString(),
                items: [ItemSetupData(name: '아이템')],
              ))
          .toList();
      _workTitle = _selectedWork!.displayTitle;
      _coverUrl = _selectedWork!.coverImageUrl;
      _step = 2;
    });
  }

  void _goToSetupIgdb(List<IgdbCharacter> allChars) {
    final selected =
        allChars.where((c) => _selectedIds.contains(c.id)).toList();
    if (selected.isEmpty) return;
    setState(() {
      _selectedSetupChars = selected
          .map((ch) => CharacterSetupData(
                name: ch.name,
                photoUrl: ch.imageUrl,
                externalId: 'igdb_${ch.id}',
                items: [ItemSetupData(name: '아이템')],
              ))
          .toList();
      _workTitle = _selectedGame!.name;
      _coverUrl = _selectedGame!.coverUrl;
      _step = 2;
    });
  }

  Future<void> _createCatalog({
    required String name,
    required String? category,
    required String? workTag,
    required String visibility,
    required List<CharacterSetupData> characters,
    required String? coverUrl,
    required XFile? newCoverPhoto,
    required double coverFitY,
  }) async {
    final service = ref.read(catalogServiceProvider);

    String? finalCoverUrl = coverUrl;
    if (newCoverPhoto != null) {
      final bytes = await newCoverPhoto.readAsBytes();
      finalCoverUrl =
          await service.uploadPhoto(bytes, newCoverPhoto.name);
    }

    // Upload character photos if picked from gallery
    final charData = <Map<String, dynamic>>[];
    for (final c in characters) {
      String? photoUrl = c.photoUrl;
      if (c.newPhotoFile != null) {
        final bytes = await c.newPhotoFile!.readAsBytes();
        photoUrl = await service.uploadPhoto(bytes, c.newPhotoFile!.name);
      }
      charData.add({
        'name': c.name,
        'photo_url': photoUrl,
        'external_id': c.externalId,
        'items': c.items
            .where((i) => i.name.trim().isNotEmpty)
            .map((i) => {'name': i.name})
            .toList(),
      });
    }

    final catalog = await service.createCatalogWithCharacters(
      name: name,
      category: category,
      workTag: workTag ?? _workTitle,
      coverUrl: finalCoverUrl,
      coverFitY: coverFitY,
      visibility: visibility,
      characters: charData,
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

  String get _appBarTitle {
    switch (_step) {
      case 0:
        return '작품 선택';
      case 1:
        if (_selectedWork != null) return _selectedWork!.displayTitle;
        if (_selectedGame != null) return _selectedGame!.name;
        return '캐릭터 선택';
      case 2:
        return '도감 설정';
      default:
        return '작품 선택';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: _goBack,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 0:
        return _buildSearch();
      case 1:
        if (_selectedGame != null) return _buildIgdbCharacterList();
        return _buildAnilistCharacterList();
      case 2:
        return _buildSetupForm();
      default:
        return _buildSearch();
    }
  }

  // ── Step 0: Search ──

  Widget _buildSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: _sourceType == 'WEBTOON'
                  ? '웹툰 제목 검색...'
                  : _sourceType == 'GAME'
                  ? '게임 검색 (예: 원신, 젤다)'
                  : '작품 검색 (예: 귀멸의 칼날)',
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _typeChip('ANIME', '애니메이션'),
              const SizedBox(width: 8),
              _typeChip('MANGA', '만화/소설'),
              const SizedBox(width: 8),
              _typeChip('WEBTOON', '웹툰'),
              const SizedBox(width: 8),
              _typeChip('GAME', '게임'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_searchQuery.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(PhosphorIconsBold.trendUp,
                    size: 14, color: DuckColors.textSub),
                const SizedBox(width: 6),
                Text(
                  _sourceType == 'GAME'
                      ? '인기 게임'
                      : _sourceType == 'WEBTOON'
                          ? '인기 웹툰'
                          : '인기 작품',
                  style: const TextStyle(
                      fontSize: 13, color: DuckColors.textSub),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: _sourceType == 'GAME'
              ? _buildGameResults()
              : _sourceType == 'WEBTOON'
                  ? _buildWebtoonResults()
                  : _buildAnilistResults(),
        ),
      ],
    );
  }

  Widget _buildAnilistResults() {
    final params = (query: _searchQuery, type: _sourceType);
    final asyncWorks = ref.watch(anilistWorkSearchProvider(params));

    return asyncWorks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('작품을 불러올 수 없어요\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DuckColors.textSub)),
        ),
      ),
      data: (works) {
        if (works.isEmpty) {
          return const Center(
            child: Text('검색 결과가 없어요',
                style: TextStyle(color: DuckColors.textSub)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.58,
          ),
          itemCount: works.length,
          itemBuilder: (context, index) =>
              _buildWorkCard(works[index]),
        );
      },
    );
  }

  Widget _buildGameResults() {
    final asyncGames = ref.watch(igdbGameSearchProvider(_searchQuery));

    return asyncGames.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('게임을 불러올 수 없어요\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DuckColors.textSub)),
        ),
      ),
      data: (games) {
        if (games.isEmpty) {
          return const Center(
            child: Text('검색 결과가 없어요',
                style: TextStyle(color: DuckColors.textSub)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.58,
          ),
          itemCount: games.length,
          itemBuilder: (context, index) =>
              _buildGameCard(games[index]),
        );
      },
    );
  }

  Widget _buildWebtoonResults() {
    final asyncWebtoons = _searchQuery.isEmpty
        ? ref.watch(trendingWebtoonProvider)
        : ref.watch(webtoonSearchProvider(_searchQuery));

    return asyncWebtoons.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('웹툰을 불러올 수 없어요\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DuckColors.textSub)),
        ),
      ),
      data: (webtoons) {
        if (webtoons.isEmpty) {
          return const Center(
            child: Text('검색 결과가 없어요',
                style: TextStyle(color: DuckColors.textSub)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.58,
          ),
          itemCount: webtoons.length,
          itemBuilder: (context, index) =>
              _buildWebtoonCard(webtoons[index]),
        );
      },
    );
  }

  Widget _buildWebtoonCard(WebtoonData webtoon) {
    return GestureDetector(
      onTap: () => _selectWebtoon(webtoon),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: webtoon.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: webtoon.thumbnailUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: DuckColors.surface),
                      errorWidget: (_, e, s) =>
                          _cardPlaceholder(PhosphorIconsBold.bookOpen),
                    )
                  : _cardPlaceholder(PhosphorIconsBold.bookOpen),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            webtoon.displayTitle,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkCard(AnilistWork work) {
    return GestureDetector(
      onTap: () => _selectWork(work),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: work.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: work.coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: DuckColors.surface),
                      errorWidget: (_, e, s) => _cardPlaceholder(
                          PhosphorIconsBold.filmSlate),
                    )
                  : _cardPlaceholder(PhosphorIconsBold.filmSlate),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            work.displayTitle,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(IgdbGame game) {
    return GestureDetector(
      onTap: () => _selectGame(game),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: game.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: game.coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: DuckColors.surface),
                      errorWidget: (_, e, s) => _cardPlaceholder(
                          PhosphorIconsBold.gameController),
                    )
                  : _cardPlaceholder(PhosphorIconsBold.gameController),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            game.name,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _cardPlaceholder(IconData icon) {
    return Container(
      color: DuckColors.surface,
      child: Center(child: Icon(icon, size: 24, color: DuckColors.textLight)),
    );
  }

  Widget _typeChip(String type, String label) {
    final selected = _sourceType == type;
    return GestureDetector(
      onTap: () {
        if (_sourceType != type) {
          setState(() {
            _sourceType = type;
            _searchController.clear();
            _searchQuery = '';
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? DuckColors.primary : DuckColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : DuckColors.textSub,
          ),
        ),
      ),
    );
  }

  // ── Step 1: AniList Character list ──

  Widget _buildAnilistCharacterList() {
    final asyncChars =
        ref.watch(anilistCharactersProvider(_selectedWork!.id));

    return asyncChars.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _charErrorWidget(e),
      data: (chars) {
        if (chars.isEmpty) return _charEmptyWidget(_skipToSetupAnilist);
        return _buildSelectionList(
          count: chars.length,
          onSelectAll: () => _selectAllGeneric(
              chars.length, chars.map((c) => c.id)),
          itemBuilder: (index) {
            final ch = chars[index];
            return _buildGenericTile(
              id: ch.id,
              name: ch.displayName,
              imageUrl: ch.imageUrl,
              subtitle: ch.nativeName != null && ch.nativeName != ch.name
                  ? ch.name
                  : null,
              badge: ch.roleLabel,
              isBadgeHighlighted: ch.role == 'MAIN',
            );
          },
          onConfirm: () => _goToSetupAnilist(chars),
          buttonLabel: '명 선택 — 다음',
        );
      },
    );
  }

  // ── Step 1: IGDB Character list ──

  Widget _buildIgdbCharacterList() {
    final asyncChars =
        ref.watch(igdbCharactersProvider(_selectedGame!.id));

    return asyncChars.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _charErrorWidget(e),
      data: (chars) {
        if (chars.isEmpty) return _charEmptyWidget(_skipToSetupIgdb);
        return _buildSelectionList(
          count: chars.length,
          onSelectAll: () => _selectAllGeneric(
              chars.length, chars.map((c) => c.id)),
          itemBuilder: (index) {
            final ch = chars[index];
            return _buildGenericTile(
              id: ch.id,
              name: ch.name,
              imageUrl: ch.imageUrl,
            );
          },
          onConfirm: () => _goToSetupIgdb(chars),
          buttonLabel: '명 선택 — 다음',
        );
      },
    );
  }

  void _skipToSetupAnilist() {
    setState(() {
      _selectedSetupChars = [];
      _workTitle = _selectedWork!.displayTitle;
      _coverUrl = _selectedWork!.coverImageUrl;
      _step = 2;
    });
  }

  void _skipToSetupIgdb() {
    setState(() {
      _selectedSetupChars = [];
      _workTitle = _selectedGame!.name;
      _coverUrl = _selectedGame!.coverUrl;
      _step = 2;
    });
  }

  Widget _charErrorWidget(Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text('캐릭터를 불러올 수 없어요\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DuckColors.textSub)),
      ),
    );
  }

  Widget _charEmptyWidget(VoidCallback onSkip) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsBold.users,
                size: 40, color: DuckColors.textLight),
            const SizedBox(height: 12),
            const Text('캐릭터 데이터가 없어요',
                textAlign: TextAlign.center,
                style: TextStyle(color: DuckColors.textSub)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onSkip,
              icon: const Icon(PhosphorIconsBold.caretRight, size: 18),
              label: const Text('캐릭터 없이 계속하기'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared selection list ──

  Widget _buildSelectionList({
    required int count,
    required VoidCallback onSelectAll,
    required Widget Function(int index) itemBuilder,
    required VoidCallback onConfirm,
    required String buttonLabel,
  }) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('$count명의 캐릭터',
                      style: const TextStyle(
                          fontSize: 13, color: DuckColors.textSub)),
                  const Spacer(),
                  TextButton(
                    onPressed: onSelectAll,
                    child: Text(
                      _selectedIds.length == count ? '선택 해제' : '전체 선택',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(
                    bottom: _selectedIds.isNotEmpty ? 80 : 16),
                itemCount: count,
                itemBuilder: (context, index) => itemBuilder(index),
              ),
            ),
          ],
        ),
        if (_selectedIds.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(PhosphorIconsBold.caretRight, size: 20),
                label: Text('${_selectedIds.length}$buttonLabel'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGenericTile({
    required int id,
    required String name,
    String? imageUrl,
    String? subtitle,
    String? badge,
    bool isBadgeHighlighted = false,
  }) {
    final isSelected = _selectedIds.contains(id);
    return GestureDetector(
      onTap: () => _toggleSelection(id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? DuckColors.primaryLight.withValues(alpha: 0.3)
              : DuckColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? DuckColors.primary : DuckColors.surface,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected
                    ? DuckColors.primary
                    : DuckColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? null
                    : Border.all(color: DuckColors.textLight),
              ),
              child: isSelected
                  ? const Icon(PhosphorIconsBold.check,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: DuckColors.surface),
                        errorWidget: (_, e, s) => Container(
                          color: DuckColors.surface,
                          child: const Icon(PhosphorIconsBold.user,
                              size: 20, color: DuckColors.textLight),
                        ),
                      )
                    : Container(
                        color: DuckColors.surface,
                        child: const Icon(PhosphorIconsBold.user,
                            size: 20, color: DuckColors.textLight),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (badge != null || subtitle != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isBadgeHighlighted
                                  ? DuckColors.primary
                                      .withValues(alpha: 0.15)
                                  : DuckColors.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isBadgeHighlighted
                                    ? DuckColors.primary
                                    : DuckColors.textSub,
                              ),
                            ),
                          ),
                        if (subtitle != null) ...[
                          if (badge != null) const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              subtitle,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: DuckColors.textSub),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Setup form ──

  Widget _buildSetupForm() {
    final title = _workTitle ?? '';
    final defaultName = '$title 피규어';

    return CatalogSetupForm(
      initialName: defaultName,
      initialCategory: 'figure',
      initialWorkTag: title,
      initialCoverUrl: _coverUrl,
      characters: _selectedSetupChars,
      onSubmit: _createCatalog,
    );
  }
}
