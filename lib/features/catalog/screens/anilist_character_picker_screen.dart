import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../services/anilist_figure_service.dart';
import '../../calendar/services/igdb_service.dart';
import '../widgets/catalog_setup_form.dart';

/// 작품/게임 → 캐릭터 선택 피커
/// Navigator.pop으로 `List<CharacterSetupData>`를 반환
class AnilistCharacterPickerScreen extends ConsumerStatefulWidget {
  const AnilistCharacterPickerScreen({super.key});

  @override
  ConsumerState<AnilistCharacterPickerScreen> createState() =>
      _AnilistCharacterPickerScreenState();
}

class _AnilistCharacterPickerScreenState
    extends ConsumerState<AnilistCharacterPickerScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  // 'ANIME', 'MANGA', 'GAME'
  String _sourceType = 'ANIME';

  // Step 0: work/game search, Step 1: character select
  int _step = 0;
  // AniList
  AnilistWork? _selectedWork;
  // IGDB
  IgdbGame? _selectedGame;

  final Set<int> _selectedIds = {};

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
      _selectedIds.clear();
      _step = 1;
    });
  }

  void _goBack() {
    if (_step == 1) {
      setState(() {
        _selectedWork = null;
        _selectedGame = null;
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

  void _selectAllAnilist(List<AnilistCharacter> chars) {
    setState(() {
      if (_selectedIds.length == chars.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(chars.map((c) => c.id));
      }
    });
  }

  void _selectAllIgdb(List<IgdbCharacter> chars) {
    setState(() {
      if (_selectedIds.length == chars.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(chars.map((c) => c.id));
      }
    });
  }

  void _confirmAnilist(List<AnilistCharacter> allChars) {
    final selected =
        allChars.where((c) => _selectedIds.contains(c.id)).toList();
    if (selected.isEmpty) return;

    final result = selected
        .map((ch) => CharacterSetupData(
              name: ch.displayName,
              photoUrl: ch.imageUrl,
              externalId: ch.id.toString(),
              items: [ItemSetupData(name: '아이템')],
            ))
        .toList();
    Navigator.of(context).pop(result);
  }

  void _confirmIgdb(List<IgdbCharacter> allChars) {
    final selected =
        allChars.where((c) => _selectedIds.contains(c.id)).toList();
    if (selected.isEmpty) return;

    final result = selected
        .map((ch) => CharacterSetupData(
              name: ch.name,
              photoUrl: ch.imageUrl,
              externalId: 'igdb_${ch.id}',
              items: [ItemSetupData(name: '아이템')],
            ))
        .toList();
    Navigator.of(context).pop(result);
  }

  String get _appBarTitle {
    if (_step == 0) return '작품 선택';
    if (_selectedWork != null) return _selectedWork!.displayTitle;
    if (_selectedGame != null) return _selectedGame!.name;
    return '캐릭터 선택';
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
      body: _step == 0
          ? _buildSearch()
          : _selectedGame != null
              ? _buildIgdbCharacterList()
              : _buildAnilistCharacterList(),
    );
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
              hintText: _sourceType == 'GAME'
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
                  _sourceType == 'GAME' ? '인기 게임' : '인기 작품',
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
                      placeholder: (_, _) =>
                          Container(color: DuckColors.surface),
                      errorWidget: (_, e, s) => _buildCardPlaceholder(
                          PhosphorIconsBold.filmSlate),
                    )
                  : _buildCardPlaceholder(PhosphorIconsBold.filmSlate),
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
                      placeholder: (_, _) =>
                          Container(color: DuckColors.surface),
                      errorWidget: (_, e, s) => _buildCardPlaceholder(
                          PhosphorIconsBold.gameController),
                    )
                  : _buildCardPlaceholder(
                      PhosphorIconsBold.gameController),
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

  Widget _buildCardPlaceholder(IconData icon) {
    return Container(
      color: DuckColors.surface,
      child: Center(
        child: Icon(icon, size: 24, color: DuckColors.textLight),
      ),
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
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('캐릭터를 불러올 수 없어요\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DuckColors.textSub)),
        ),
      ),
      data: (chars) {
        if (chars.isEmpty) {
          return _charEmptyWidget(() {
            Navigator.of(context).pop(<CharacterSetupData>[]);
          });
        }
        return _buildSelectionList(
          count: chars.length,
          onSelectAll: () => _selectAllAnilist(chars),
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
          onConfirm: () => _confirmAnilist(chars),
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
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('캐릭터를 불러올 수 없어요\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DuckColors.textSub)),
        ),
      ),
      data: (chars) {
        if (chars.isEmpty) {
          return _charEmptyWidget(() {
            Navigator.of(context).pop(<CharacterSetupData>[]);
          });
        }
        return _buildSelectionList(
          count: chars.length,
          onSelectAll: () => _selectAllIgdb(chars),
          itemBuilder: (index) {
            final ch = chars[index];
            return _buildGenericTile(
              id: ch.id,
              name: ch.name,
              imageUrl: ch.imageUrl,
            );
          },
          onConfirm: () => _confirmIgdb(chars),
        );
      },
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
            OutlinedButton.icon(
              onPressed: onSkip,
              icon: const Icon(PhosphorIconsBold.caretLeft, size: 18),
              label: const Text('돌아가기'),
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
                  Text(
                    '$count명의 캐릭터',
                    style: const TextStyle(
                        fontSize: 13, color: DuckColors.textSub),
                  ),
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
                icon: const Icon(PhosphorIconsBold.check, size: 20),
                label: Text('${_selectedIds.length}명 추가'),
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
            // Checkbox
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
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
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
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
                                color: DuckColors.textSub,
                              ),
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
}
