import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../services/anilist_figure_service.dart';
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
  String _mediaType = 'ANIME';

  // Step 0: search, Step 1: character select, Step 2: setup
  int _step = 0;
  AnilistWork? _selectedWork;
  final Set<int> _selectedIds = {};
  List<AnilistCharacter> _selectedChars = [];

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
      _selectedIds.clear();
      _step = 1;
    });
  }

  void _goBack() {
    if (_step == 2) {
      setState(() => _step = 1);
    } else if (_step == 1) {
      setState(() {
        _selectedWork = null;
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

  void _selectAll(List<AnilistCharacter> chars) {
    setState(() {
      if (_selectedIds.length == chars.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(chars.map((c) => c.id));
      }
    });
  }

  void _goToSetup(List<AnilistCharacter> allChars) {
    final selected =
        allChars.where((c) => _selectedIds.contains(c.id)).toList();
    if (selected.isEmpty) return;
    setState(() {
      _selectedChars = selected;
      _step = 2;
    });
  }

  Future<void> _createCatalog({
    required String name,
    required String? category,
    required String? workTag,
    required String visibility,
    required List<CharacterSetupData> characters,
  }) async {
    final service = ref.read(catalogServiceProvider);
    final work = _selectedWork!;

    final charData = characters.map((c) => {
      'name': c.name,
      'photo_url': c.photoUrl,
      'external_id': c.externalId,
      'items': c.items
          .where((i) => i.name.trim().isNotEmpty)
          .map((i) => {'name': i.name})
          .toList(),
    }).toList();

    final catalog = await service.createCatalogWithCharacters(
      name: name,
      category: category,
      workTag: workTag ?? work.displayTitle,
      coverUrl: work.coverImageUrl,
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

  @override
  Widget build(BuildContext context) {
    String title;
    switch (_step) {
      case 0:
        title = '작품 선택';
        break;
      case 1:
        title = _selectedWork?.displayTitle ?? '캐릭터 선택';
        break;
      case 2:
        title = '도감 설정';
        break;
      default:
        title = '작품 선택';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
        return _buildWorkSearch();
      case 1:
        return _buildCharacterList(_selectedWork!);
      case 2:
        return _buildSetupForm();
      default:
        return _buildWorkSearch();
    }
  }

  // ── Step 0: Work search ──

  Widget _buildWorkSearch() {
    final params = (query: _searchQuery, type: _mediaType);
    final asyncWorks = ref.watch(anilistWorkSearchProvider(params));

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '작품 검색 (예: 귀멸의 칼날)',
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

        // Type toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _typeChip('ANIME', '애니메이션'),
              const SizedBox(width: 8),
              _typeChip('MANGA', '만화/소설'),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Info text
        if (_searchQuery.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(PhosphorIconsBold.trendUp,
                    size: 14, color: DuckColors.textSub),
                const SizedBox(width: 6),
                const Text(
                  '인기 작품',
                  style: TextStyle(fontSize: 13, color: DuckColors.textSub),
                ),
              ],
            ),
          ),

        const SizedBox(height: 4),

        // Results grid
        Expanded(
          child: asyncWorks.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '작품을 불러올 수 없어요\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DuckColors.textSub),
                ),
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
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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
          ),
        ),
      ],
    );
  }

  Widget _typeChip(String type, String label) {
    final selected = _mediaType == type;
    return GestureDetector(
      onTap: () {
        if (_mediaType != type) {
          setState(() => _mediaType = type);
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

  Widget _buildWorkCard(AnilistWork work) {
    return GestureDetector(
      onTap: () => _selectWork(work),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover image
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: work.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: work.coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: DuckColors.surface,
                        child: const Center(
                          child: Icon(PhosphorIconsBold.filmSlate,
                              size: 24, color: DuckColors.textLight),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: DuckColors.surface,
                        child: const Center(
                          child: Icon(PhosphorIconsBold.filmSlate,
                              size: 24, color: DuckColors.textLight),
                        ),
                      ),
                    )
                  : Container(
                      color: DuckColors.surface,
                      child: const Center(
                        child: Icon(PhosphorIconsBold.filmSlate,
                            size: 24, color: DuckColors.textLight),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          // Title
          Text(
            work.displayTitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Step 1: Character list ──

  Widget _buildCharacterList(AnilistWork work) {
    final asyncChars = ref.watch(anilistCharactersProvider(work.id));

    return asyncChars.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '캐릭터를 불러올 수 없어요\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DuckColors.textSub),
          ),
        ),
      ),
      data: (chars) {
        if (chars.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                '캐릭터 데이터가 없어요',
                textAlign: TextAlign.center,
                style: TextStyle(color: DuckColors.textSub),
              ),
            ),
          );
        }

        return Stack(
          children: [
            Column(
              children: [
                // Header: select all + count
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${chars.length}명의 캐릭터',
                        style: const TextStyle(
                          fontSize: 13,
                          color: DuckColors.textSub,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _selectAll(chars),
                        child: Text(
                          _selectedIds.length == chars.length
                              ? '선택 해제'
                              : '전체 선택',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: _selectedIds.isNotEmpty ? 80 : 16,
                    ),
                    itemCount: chars.length,
                    itemBuilder: (context, index) {
                      final ch = chars[index];
                      final isSelected = _selectedIds.contains(ch.id);
                      return _buildCharacterTile(ch, isSelected);
                    },
                  ),
                ),
              ],
            ),

            // Bottom action bar — "다음"
            if (_selectedIds.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: ElevatedButton.icon(
                    onPressed: () => _goToSetup(chars),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(PhosphorIconsBold.caretRight, size: 20),
                    label: Text(
                        '${_selectedIds.length}명 선택 — 다음'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCharacterTile(AnilistCharacter ch, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleSelection(ch.id),
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
                color: isSelected ? DuckColors.primary : DuckColors.surface,
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

            // Character image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: ch.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: ch.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: DuckColors.surface),
                        errorWidget: (_, __, ___) => Container(
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
                    ch.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: ch.role == 'MAIN'
                              ? DuckColors.primary.withValues(alpha: 0.15)
                              : DuckColors.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ch.roleLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: ch.role == 'MAIN'
                                ? DuckColors.primary
                                : DuckColors.textSub,
                          ),
                        ),
                      ),
                      // Sub name
                      if (ch.nativeName != null &&
                          ch.nativeName != ch.name) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ch.name,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Setup form ──

  Widget _buildSetupForm() {
    final work = _selectedWork!;
    final defaultName = '${work.displayTitle} 피규어';

    // Convert selected chars to CharacterSetupData
    final charSetupList = _selectedChars.map((ch) {
      return CharacterSetupData(
        name: ch.displayName,
        photoUrl: ch.imageUrl,
        externalId: ch.id.toString(),
        items: [ItemSetupData(name: '아이템')],
      );
    }).toList();

    return CatalogSetupForm(
      initialName: defaultName,
      initialCategory: 'figure',
      initialWorkTag: work.displayTitle,
      characters: charSetupList,
      onSubmit: _createCatalog,
    );
  }
}
