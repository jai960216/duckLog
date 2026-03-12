import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../../../shared/models/followed_work.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/anilist_service.dart';
import '../services/igdb_service.dart';
import '../services/webtoon_service.dart';
import '../services/calendar_service.dart';
import 'work_detail_screen.dart';

class WorkSearchScreen extends ConsumerStatefulWidget {
  const WorkSearchScreen({super.key});

  @override
  ConsumerState<WorkSearchScreen> createState() => _WorkSearchScreenState();
}

class _WorkSearchScreenState extends ConsumerState<WorkSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedType = 'anime'; // anime, manga, webtoon, or game

  // 검색
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = []; // AnilistMedia, IgdbGame, or WebtoonData
  bool _isSearching = false;
  Timer? _debounce;

  // 검색 세대 카운터 (stale 결과 방지)
  int _searchGeneration = 0;

  // 팔로우 진행 중 ID
  int? _followingId;
  String? _followingWebtoonId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── 검색 ──

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _searchGeneration++;
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _doSearch(query);
    });
  }

  Future<void> _doSearch(String query) async {
    if (query.trim().isEmpty) return;
    final gen = _searchGeneration;
    try {
      List<dynamic> results;
      if (_selectedType == 'anime') {
        final service = ref.read(anilistServiceProvider);
        results = await service.searchAnime(query);
      } else if (_selectedType == 'manga') {
        final service = ref.read(anilistServiceProvider);
        results = await service.searchManga(query);
      } else if (_selectedType == 'webtoon') {
        final service = ref.read(webtoonServiceProvider);
        results = await service.searchWebtoons(query);
      } else {
        final service = ref.read(igdbServiceProvider);
        if (!service.isConfigured) return;
        results = await service.searchGames(query);
      }
      // stale 결과 무시: 검색 중 새 입력이 들어왔으면 반영하지 않음
      if (!mounted || gen != _searchGeneration) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted || gen != _searchGeneration) return;
      setState(() => _isSearching = false);
      DuckSnackBar.error(context, '검색 실패');
    }
  }

  // ── 팔로우: 애니 ──

  Future<void> _followAnime(AnilistMedia media) async {
    if (_followingId != null) return;
    setState(() => _followingId = media.id);

    try {
      final calendarService = ref.read(calendarServiceProvider);
      final work = await calendarService.followWork(
        workType: 'anime',
        title: media.displayTitle,
        coverUrl: media.coverImageUrl,
        externalId: media.id.toString(),
      );

      // 방영 스케줄 자동 저장 (병렬, 실패해도 OK)
      try {
        final anilistService = ref.read(anilistServiceProvider);
        final schedules = await anilistService.getAiringSchedule(media.id);
        await Future.wait(
          schedules.map((schedule) => calendarService.addEvent(
            workType: 'anime',
            externalId: media.id.toString(),
            title: media.displayTitle,
            eventType: 'airing',
            eventDate: schedule.airingDateTime,
            episodeNumber: schedule.episode,
          )),
        );
      } catch (_) {}

      ref.invalidate(followedWorksProvider);
      if (mounted) {
        DuckSnackBar.success(context, '\'${media.displayTitle}\' 팔로우 시작!');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkDetailScreen(work: work, animeData: media),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '추가 실패');
      }
    } finally {
      if (mounted) setState(() => _followingId = null);
    }
  }

  // ── 팔로우: 만화 ──

  Future<void> _followManga(AnilistMedia media) async {
    if (_followingId != null) return;
    setState(() => _followingId = media.id);

    try {
      final calendarService = ref.read(calendarServiceProvider);
      final work = await calendarService.followWork(
        workType: 'manga',
        title: media.displayTitle,
        coverUrl: media.coverImageUrl,
        externalId: media.id.toString(),
      );

      ref.invalidate(followedWorksProvider);
      if (mounted) {
        DuckSnackBar.success(context, '\'${media.displayTitle}\' 팔로우 시작!');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkDetailScreen(work: work, animeData: media),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '추가 실패');
      }
    } finally {
      if (mounted) setState(() => _followingId = null);
    }
  }

  // ── 팔로우: 웹툰 ──

  Future<void> _followWebtoon(WebtoonData webtoon) async {
    if (_followingWebtoonId != null) return;
    setState(() => _followingWebtoonId = webtoon.id);

    try {
      final calendarService = ref.read(calendarServiceProvider);
      final work = await calendarService.followWork(
        workType: 'webtoon',
        title: webtoon.displayTitle,
        coverUrl: webtoon.thumbnailUrl,
        externalId: webtoon.id,
        updateDays: webtoon.updateDays,
      );

      // 연재 일정은 updateDays 패턴에서 동적으로 생성하므로 calendar_events 저장 불필요

      ref.invalidate(followedWorksProvider);
      if (mounted) {
        DuckSnackBar.success(
            context, '\'${webtoon.displayTitle}\' 팔로우 시작!');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkDetailScreen(
              work: work,
              webtoonData: webtoon,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '추가 실패');
      }
    } finally {
      if (mounted) setState(() => _followingWebtoonId = null);
    }
  }

  // ── 팔로우: 게임 ──

  Future<void> _followGame(IgdbGame game) async {
    if (_followingId != null) return;
    setState(() => _followingId = game.id);

    try {
      final calendarService = ref.read(calendarServiceProvider);
      final work = await calendarService.followWork(
        workType: 'game',
        title: game.name,
        coverUrl: game.coverUrl,
        externalId: game.id.toString(),
      );

      // 출시일이 있으면 캘린더에 저장 (실패해도 OK)
      if (game.releaseDate != null) {
        try {
          await calendarService.addEvent(
            workType: 'game',
            externalId: game.id.toString(),
            title: game.name,
            eventType: 'release',
            eventDate: game.releaseDate!,
          );
        } catch (_) {}
      }

      ref.invalidate(followedWorksProvider);
      if (mounted) {
        DuckSnackBar.success(context, '\'${game.name}\' 팔로우 시작!');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkDetailScreen(work: work, gameData: game),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '추가 실패');
      }
    } finally {
      if (mounted) setState(() => _followingId = null);
    }
  }

  Future<void> _unfollowWork(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팔로우 해제'),
        content: Text('\'$title\'을(를) 팔로우 해제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('해제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final service = ref.read(calendarServiceProvider);
      await service.unfollowWork(id);
      ref.invalidate(followedWorksProvider);
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '해제 실패');
      }
    }
  }

  void _switchType(String type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _searchResults = [];
      _searchController.clear();
    });
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isAnime = _selectedType == 'anime';
    final isManga = _selectedType == 'manga';
    final isWebtoon = _selectedType == 'webtoon';
    final isGame = _selectedType == 'game';

    String tab2Label;
    if (isAnime) {
      tab2Label = '방영 중';
    } else if (isManga) {
      tab2Label = '연재 중';
    } else if (isWebtoon) {
      tab2Label = '요일별';
    } else {
      tab2Label = '출시 예정';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('작품 추가'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(84),
          child: Column(
            children: [
              // 타입 선택
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    DuckChip(
                      label: '애니',
                      icon: PhosphorIconsBold.television,
                      selected: isAnime,
                      backgroundColor: DuckColors.subLight,
                      onTap: () => _switchType('anime'),
                    ),
                    const SizedBox(width: 8),
                    DuckChip(
                      label: '만화/소설',
                      icon: PhosphorIconsBold.bookOpen,
                      selected: isManga,
                      backgroundColor: DuckColors.primaryLight,
                      onTap: () => _switchType('manga'),
                    ),
                    const SizedBox(width: 8),
                    DuckChip(
                      label: '웹툰',
                      icon: PhosphorIconsBold.bookOpen,
                      selected: isWebtoon,
                      backgroundColor: DuckColors.webtoonLight,
                      onTap: () => _switchType('webtoon'),
                    ),
                    const SizedBox(width: 8),
                    DuckChip(
                      label: '게임',
                      icon: PhosphorIconsBold.gameController,
                      selected: isGame,
                      backgroundColor: DuckColors.accentLight,
                      onTap: () => _switchType('game'),
                    ),
                  ],
                ),
              ),
              // 탭
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: DuckColors.text,
                unselectedLabelColor: DuckColors.textSub,
                indicatorColor: DuckColors.primary,
                indicatorWeight: 3,
                tabs: [
                  const Tab(text: '인기'),
                  Tab(text: tab2Label),
                  const Tab(text: '검색'),
                  const Tab(text: '내 작품'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: 인기
          if (isAnime)
            _AnimeTrendingTab(
                onFollow: _followAnime, followingId: _followingId)
          else if (isManga)
            _MangaTrendingTab(
                onFollow: _followManga, followingId: _followingId)
          else if (isWebtoon)
            _WebtoonTrendingTab(
                onFollow: _followWebtoon,
                followingWebtoonId: _followingWebtoonId)
          else
            _GamePopularTab(
                onFollow: _followGame, followingId: _followingId),
          // Tab 2: 방영 중 / 연재 중 / 요일별 / 출시 예정
          if (isAnime)
            _AnimeAiringTab(
                onFollow: _followAnime, followingId: _followingId)
          else if (isManga)
            _MangaPublishingTab(
                onFollow: _followManga, followingId: _followingId)
          else if (isWebtoon)
            _WebtoonWeekdayTab(
                onFollow: _followWebtoon,
                followingWebtoonId: _followingWebtoonId)
          else
            _GameUpcomingTab(
                onFollow: _followGame, followingId: _followingId),
          // Tab 3: 검색
          _buildSearchTab(),
          // Tab 4: 내 작품
          _buildMyWorksTab(),
        ],
      ),
    );
  }

  // ── Tab 3: 검색 ──

  Widget _buildSearchTab() {
    final isAnime = _selectedType == 'anime';
    final isManga = _selectedType == 'manga';
    final isWebtoon = _selectedType == 'webtoon';
    final isGame = _selectedType == 'game';
    final igdbConfigured = ref.read(igdbServiceProvider).isConfigured;
    final webtoonConfigured = ref.read(webtoonServiceProvider).isConfigured;

    String hintText;
    if (isAnime) {
      hintText = '애니 제목으로 검색';
    } else if (isManga) {
      hintText = '만화/소설 제목으로 검색';
    } else if (isWebtoon) {
      hintText = '웹툰 제목으로 검색';
    } else {
      hintText = '게임 제목으로 검색';
    }

    String emptyMessage;
    if (isAnime) {
      emptyMessage = '애니 제목을 입력해서\n검색해보세요!';
    } else if (isManga) {
      emptyMessage = '만화/소설 제목을 입력해서\n검색해보세요!';
    } else if (isWebtoon) {
      emptyMessage = '웹툰 제목을 입력해서\n검색해보세요!';
    } else {
      emptyMessage = '게임 제목을 입력해서\n검색해보세요!';
    }

    String noResultMessage;
    if (isGame) {
      noResultMessage = '검색 결과가 없어요.\n영어 제목으로 검색해보세요!';
    } else if (isWebtoon) {
      noResultMessage = '검색 결과가 없어요.\n정확한 제목으로 검색해보세요!';
    } else {
      noResultMessage = '검색 결과가 없어요.\n영어 또는 일본어 제목으로\n검색해보세요!';
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: DuckTextField(
            hint: hintText,
            controller: _searchController,
            prefix: const Icon(PhosphorIconsBold.magnifyingGlass, size: 20),
            onChanged: (value) {
              setState(() {});
              _onSearchChanged(value);
            },
          ),
        ),
        // 만화 검색 시 한국 웹툰 안내
        if (isManga && _searchResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: DuckColors.webtoonLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIconsBold.info, size: 16, color: DuckColors.webtoon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '한국 웹툰은 웹툰 탭에서 검색하세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: DuckColors.webtoon,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: isGame && !igdbConfigured
              ? const DuckEmptyState(
                  message:
                      'IGDB API 설정이 필요해요.\nigdb_config.dart에 Twitch 자격증명을 입력해주세요.',
                  icon: PhosphorIconsBold.gear,
                )
              : isWebtoon && !webtoonConfigured
              ? _webtoonNotConfigured()
              : _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchController.text.trim().isEmpty
                      ? DuckEmptyState(
                          message: emptyMessage,
                          icon: PhosphorIconsBold.magnifyingGlass,
                        )
                      : _searchResults.isEmpty
                          ? DuckEmptyState(
                              message: noResultMessage,
                              icon: PhosphorIconsBold.magnifyingGlass,
                            )
                          : isGame
                              ? _buildGameList(
                                  _searchResults.cast<IgdbGame>())
                              : isWebtoon
                                  ? _buildWebtoonList(
                                      _searchResults.cast<WebtoonData>())
                                  : _buildAnimeList(
                                      _searchResults.cast<AnilistMedia>(),
                                      onFollow: isManga ? _followManga : _followAnime,
                                      workType: isManga ? 'manga' : 'anime',
                                    ),
        ),
      ],
    );
  }

  // ── Tab 4: 내 작품 ──

  Widget _buildMyWorksTab() {
    final followedWorks = ref.watch(followedWorksProvider);

    return followedWorks.when(
      data: (works) {
        if (works.isEmpty) {
          return const DuckEmptyState(
            message: '아직 팔로우한 작품이 없어요.\n인기 탭이나 검색에서 추가해보세요!',
            icon: PhosphorIconsBold.heartStraight,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: works.length,
          itemBuilder: (context, index) {
            final work = works[index];
            final workType = work.workType;
            return DuckCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => WorkDetailScreen(work: work)),
              ),
              child: Row(
                children: [
                  if (work.coverUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: work.coverUrl!,
                        width: 40,
                        height: 52,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _typeIcon(workType),
                      ),
                    )
                  else
                    _typeIcon(workType),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(work.title,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                            workType == 'anime'
                                ? '애니메이션'
                                : workType == 'manga'
                                    ? '만화/소설'
                                    : workType == 'webtoon'
                                        ? '웹툰'
                                        : '게임',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: DuckColors.textSub)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _unfollowWork(work.id, work.title),
                    icon: Icon(PhosphorIconsBold.heartBreak,
                        size: 20, color: DuckColors.textSub),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DuckEmptyState(
        message: '작품 목록을 불러올 수 없어요.\n$e',
        icon: PhosphorIconsBold.warning,
      ),
    );
  }

  // ── Shared list builders ──

  Widget _buildAnimeList(List<AnilistMedia> list, {Future<void> Function(AnilistMedia)? onFollow, String workType = 'anime'}) {
    final followFn = onFollow ?? _followAnime;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final media = list[index];
        return _AnimeCard(
          media: media,
          isFollowing: _followingId == media.id,
          onTap: () => followFn(media),
          workType: workType,
        );
      },
    );
  }

  Widget _buildWebtoonList(List<WebtoonData> list) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final webtoon = list[index];
        return _WebtoonCard(
          webtoon: webtoon,
          isFollowing: _followingWebtoonId == webtoon.id,
          onTap: () => _followWebtoon(webtoon),
        );
      },
    );
  }

  Widget _buildGameList(List<IgdbGame> list) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final game = list[index];
        return _GameCard(
          game: game,
          isFollowing: _followingId == game.id,
          onTap: () => _followGame(game),
        );
      },
    );
  }

  Widget _typeIcon(String workType) {
    final (bgColor, iconData, iconColor) = switch (workType) {
      'anime' => (DuckColors.subLight, PhosphorIconsBold.television, DuckColors.sub),
      'manga' => (DuckColors.primaryLight, PhosphorIconsBold.bookOpen, DuckColors.primary),
      'webtoon' => (DuckColors.webtoonLight, PhosphorIconsBold.bookOpen, DuckColors.webtoon),
      _ => (DuckColors.accentLight, PhosphorIconsBold.gameController, DuckColors.accent),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, size: 20, color: iconColor),
    );
  }
}

// ══════════════════════════════════════════
// Anime tabs
// ══════════════════════════════════════════

class _AnimeTrendingTab extends ConsumerWidget {
  final Future<void> Function(AnilistMedia) onFollow;
  final int? followingId;
  const _AnimeTrendingTab({required this.onFollow, this.followingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingAnimeProvider);
    return trending.when(
      data: (list) => list.isEmpty
          ? const DuckEmptyState(
              message: '트렌딩 데이터를 불러올 수 없어요.',
              icon: PhosphorIconsBold.trendUp)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: list.length,
              itemBuilder: (_, i) => _AnimeCard(
                media: list[i],
                isFollowing: followingId == list[i].id,
                onTap: () => onFollow(list[i]),
                rank: i + 1,
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const DuckEmptyState(
          message: '네트워크를 확인해주세요.', icon: PhosphorIconsBold.wifiSlash),
    );
  }
}

class _AnimeAiringTab extends ConsumerWidget {
  final Future<void> Function(AnilistMedia) onFollow;
  final int? followingId;
  const _AnimeAiringTab({required this.onFollow, this.followingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airing = ref.watch(airingAnimeProvider);
    return airing.when(
      data: (list) => list.isEmpty
          ? const DuckEmptyState(
              message: '현재 방영 중인 애니가 없어요.',
              icon: PhosphorIconsBold.television)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: list.length,
              itemBuilder: (_, i) => _AnimeCard(
                media: list[i],
                isFollowing: followingId == list[i].id,
                onTap: () => onFollow(list[i]),
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const DuckEmptyState(
          message: '네트워크를 확인해주세요.', icon: PhosphorIconsBold.wifiSlash),
    );
  }
}

// ══════════════════════════════════════════
// Manga tabs
// ══════════════════════════════════════════

class _MangaTrendingTab extends ConsumerWidget {
  final Future<void> Function(AnilistMedia) onFollow;
  final int? followingId;
  const _MangaTrendingTab({required this.onFollow, this.followingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingMangaProvider);
    return trending.when(
      data: (list) => list.isEmpty
          ? const DuckEmptyState(
              message: '트렌딩 데이터를 불러올 수 없어요.',
              icon: PhosphorIconsBold.trendUp)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: list.length,
              itemBuilder: (_, i) => _AnimeCard(
                media: list[i],
                isFollowing: followingId == list[i].id,
                onTap: () => onFollow(list[i]),
                rank: i + 1,
                workType: 'manga',
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const DuckEmptyState(
          message: '네트워크를 확인해주세요.', icon: PhosphorIconsBold.wifiSlash),
    );
  }
}

class _MangaPublishingTab extends ConsumerWidget {
  final Future<void> Function(AnilistMedia) onFollow;
  final int? followingId;
  const _MangaPublishingTab({required this.onFollow, this.followingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publishing = ref.watch(publishingMangaProvider);
    return publishing.when(
      data: (list) => list.isEmpty
          ? const DuckEmptyState(
              message: '현재 연재 중인 만화가 없어요.',
              icon: PhosphorIconsBold.bookOpen)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: list.length,
              itemBuilder: (_, i) => _AnimeCard(
                media: list[i],
                isFollowing: followingId == list[i].id,
                onTap: () => onFollow(list[i]),
                workType: 'manga',
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const DuckEmptyState(
          message: '네트워크를 확인해주세요.', icon: PhosphorIconsBold.wifiSlash),
    );
  }
}

// ══════════════════════════════════════════
// Game tabs
// ══════════════════════════════════════════

class _GamePopularTab extends ConsumerWidget {
  final Future<void> Function(IgdbGame) onFollow;
  final int? followingId;
  const _GamePopularTab({required this.onFollow, this.followingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(igdbServiceProvider);
    if (!service.isConfigured) return _igdbNotConfigured();

    final popular = ref.watch(popularGamesProvider);
    return popular.when(
      data: (list) => list.isEmpty
          ? const DuckEmptyState(
              message: '인기 게임을 불러올 수 없어요.',
              icon: PhosphorIconsBold.trendUp)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: list.length,
              itemBuilder: (_, i) => _GameCard(
                game: list[i],
                isFollowing: followingId == list[i].id,
                onTap: () => onFollow(list[i]),
                rank: i + 1,
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const DuckEmptyState(
          message: '네트워크를 확인해주세요.', icon: PhosphorIconsBold.wifiSlash),
    );
  }
}

class _GameUpcomingTab extends ConsumerWidget {
  final Future<void> Function(IgdbGame) onFollow;
  final int? followingId;
  const _GameUpcomingTab({required this.onFollow, this.followingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(igdbServiceProvider);
    if (!service.isConfigured) return _igdbNotConfigured();

    final upcoming = ref.watch(upcomingGamesProvider);
    return upcoming.when(
      data: (list) => list.isEmpty
          ? const DuckEmptyState(
              message: '출시 예정 게임이 없어요.',
              icon: PhosphorIconsBold.gameController)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: list.length,
              itemBuilder: (_, i) => _GameCard(
                game: list[i],
                isFollowing: followingId == list[i].id,
                onTap: () => onFollow(list[i]),
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const DuckEmptyState(
          message: '네트워크를 확인해주세요.', icon: PhosphorIconsBold.wifiSlash),
    );
  }
}

// ══════════════════════════════════════════
// Webtoon tabs
// ══════════════════════════════════════════

class _WebtoonTrendingTab extends ConsumerWidget {
  final Future<void> Function(WebtoonData) onFollow;
  final String? followingWebtoonId;
  const _WebtoonTrendingTab({required this.onFollow, this.followingWebtoonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(webtoonServiceProvider);
    if (!service.isConfigured) return _webtoonNotConfigured();

    final trending = ref.watch(trendingWebtoonProvider);
    return trending.when(
      data: (list) => list.isEmpty
          ? const DuckEmptyState(
              message: '오늘 업데이트된 웹툰이 없어요.',
              icon: PhosphorIconsBold.bookOpen)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: list.length,
              itemBuilder: (_, i) => _WebtoonCard(
                webtoon: list[i],
                isFollowing: followingWebtoonId == list[i].id,
                onTap: () => onFollow(list[i]),
                rank: i + 1,
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const DuckEmptyState(
          message: '네트워크를 확인해주세요.', icon: PhosphorIconsBold.wifiSlash),
    );
  }
}

class _WebtoonWeekdayTab extends ConsumerStatefulWidget {
  final Future<void> Function(WebtoonData) onFollow;
  final String? followingWebtoonId;
  const _WebtoonWeekdayTab({required this.onFollow, this.followingWebtoonId});

  @override
  ConsumerState<_WebtoonWeekdayTab> createState() =>
      _WebtoonWeekdayTabState();
}

class _WebtoonWeekdayTabState extends ConsumerState<_WebtoonWeekdayTab> {
  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    // 오늘 요일로 초기 선택
    final today = DateTime.now().weekday; // 1=Mon, 7=Sun
    _selectedDay = _days[today - 1];
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(webtoonServiceProvider);
    if (!service.isConfigured) return _webtoonNotConfigured();

    final webtoons = ref.watch(weekdayWebtoonProvider(_selectedDay));

    return Column(
      children: [
        // 요일 선택 칩
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: List.generate(_days.length, (i) {
              final selected = _selectedDay == _days[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = _days[i]),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? DuckColors.webtoon
                          : DuckColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _dayLabels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                          color: selected
                              ? Colors.white
                              : DuckColors.textSub,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // 웹툰 리스트
        Expanded(
          child: webtoons.when(
            data: (list) => list.isEmpty
                ? const DuckEmptyState(
                    message: '해당 요일에 연재 중인 웹툰이 없어요.',
                    icon: PhosphorIconsBold.bookOpen)
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _WebtoonCard(
                      webtoon: list[i],
                      isFollowing:
                          widget.followingWebtoonId == list[i].id,
                      onTap: () => widget.onFollow(list[i]),
                    ),
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) => const DuckEmptyState(
                message: '네트워크를 확인해주세요.',
                icon: PhosphorIconsBold.wifiSlash),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════
// 웹툰 카드
// ══════════════════════════════════════════

class _WebtoonCard extends StatelessWidget {
  final WebtoonData webtoon;
  final bool isFollowing;
  final VoidCallback onTap;
  final int? rank;

  const _WebtoonCard({
    required this.webtoon,
    required this.isFollowing,
    required this.onTap,
    this.rank,
  });

  bool get _canFollow => !webtoon.isEnd;

  void _openDetail(BuildContext context) {
    final previewWork = FollowedWork(
      id: '',
      userId: '',
      workType: 'webtoon',
      externalId: webtoon.id,
      title: webtoon.displayTitle,
      coverUrl: webtoon.thumbnailUrl,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkDetailScreen(
          work: previewWork,
          webtoonData: webtoon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DuckCard(
      onTap: () => _openDetail(context),
      child: Row(
        children: [
          if (rank != null)
            SizedBox(
              width: 28,
              child: Text('$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color:
                        rank! <= 3 ? DuckColors.webtoon : DuckColors.textSub,
                  )),
            ),
          // 웹툰 썸네일 (네이버/카카오 CDN 대응)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: webtoon.thumbnailUrl != null
                ? Image.network(
                    webtoon.thumbnailUrl!,
                    width: 48,
                    height: 64,
                    fit: BoxFit.cover,
                    headers: const {'Referer': ''},
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 64,
                      decoration: BoxDecoration(
                        color: DuckColors.webtoonLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(PhosphorIconsBold.bookOpen,
                          size: 20, color: DuckColors.webtoon),
                    ),
                  )
                : Container(
                    width: 48,
                    height: 64,
                    decoration: BoxDecoration(
                      color: DuckColors.webtoonLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(PhosphorIconsBold.bookOpen,
                        size: 20, color: DuckColors.webtoon),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(webtoon.displayTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (webtoon.authors.isNotEmpty)
                  Text(webtoon.authors.join(', '),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: DuckColors.textSub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // 플랫폼 배지
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DuckColors.webtoonLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        webtoon.providerKorean,
                        style: const TextStyle(
                          fontSize: 10,
                          color: DuckColors.webtoon,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 연재요일 배지
                    if (webtoon.updateDays.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: DuckColors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          webtoon.updateDaysKorean,
                          style: TextStyle(
                            fontSize: 10,
                            color: DuckColors.textSub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (webtoon.isEnd) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: DuckColors.textSub.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '완결',
                          style: TextStyle(
                            fontSize: 10,
                            color: DuckColors.textSub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (webtoon.isUpdated) ...[
                      const SizedBox(width: 6),
                      Icon(PhosphorIconsBold.arrowClockwise,
                          size: 12, color: DuckColors.success),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // 팔로우 버튼 — 플러스 아이콘만 탭 가능
          GestureDetector(
            onTap: isFollowing || !_canFollow ? null : onTap,
            child: _FollowButton(
              isFollowing: isFollowing,
              color: DuckColors.webtoon,
              enabled: _canFollow,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _webtoonNotConfigured() {
  return const DuckEmptyState(
    message: '웹툰 API 설정이 필요해요.\nkorea-webtoon-api를 배포한 뒤\nconstants.dart에 URL을 입력해주세요.',
    icon: PhosphorIconsBold.gear,
  );
}

Widget _igdbNotConfigured() {
  return const DuckEmptyState(
    message: 'IGDB API 설정이 필요해요.\nigdb_config.dart에\nTwitch 자격증명을 입력해주세요.',
    icon: PhosphorIconsBold.gear,
  );
}

// ══════════════════════════════════════════
// 애니 카드
// ══════════════════════════════════════════

class _AnimeCard extends StatelessWidget {
  final AnilistMedia media;
  final bool isFollowing;
  final VoidCallback onTap;
  final int? rank;
  final String workType;

  const _AnimeCard({
    required this.media,
    required this.isFollowing,
    required this.onTap,
    this.rank,
    this.workType = 'anime',
  });

  bool get _canFollow =>
      media.status != 'FINISHED' && media.status != 'CANCELLED';

  void _openDetail(BuildContext context) {
    final previewWork = FollowedWork(
      id: '',
      userId: '',
      workType: workType,
      externalId: media.id.toString(),
      title: media.displayTitle,
      coverUrl: media.coverImageUrl,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkDetailScreen(
          work: previewWork,
          animeData: media,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DuckCard(
      onTap: () => _openDetail(context),
      child: Row(
        children: [
          if (rank != null)
            SizedBox(
              width: 28,
              child: Text('$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color:
                        rank! <= 3 ? DuckColors.primary : DuckColors.textSub,
                  )),
            ),
          _CoverImage(url: media.coverImageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(media.displayTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (media.subtitle != null)
                  Text(media.subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: DuckColors.textSub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  _StatusBadge(status: media.status),
                  if (media.nextAiringEpisode != null) ...[
                    const SizedBox(width: 8),
                    Text('${media.nextAiringEpisode}화 예정',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: DuckColors.sub)),
                  ],
                ]),
              ],
            ),
          ),
          GestureDetector(
            onTap: isFollowing || !_canFollow ? null : onTap,
            child: _FollowButton(
              isFollowing: isFollowing,
              color: DuckColors.sub,
              enabled: _canFollow,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// 게임 카드
// ══════════════════════════════════════════

class _GameCard extends StatelessWidget {
  final IgdbGame game;
  final bool isFollowing;
  final VoidCallback onTap;
  final int? rank;

  const _GameCard({
    required this.game,
    required this.isFollowing,
    required this.onTap,
    this.rank,
  });

  bool get _canFollow {
    if (game.releaseDate == null) return true;
    final today = DateTime.now();
    final releaseDay = DateTime(
      game.releaseDate!.year,
      game.releaseDate!.month,
      game.releaseDate!.day,
    );
    return !releaseDay.isBefore(DateTime(today.year, today.month, today.day));
  }

  void _openDetail(BuildContext context) {
    final previewWork = FollowedWork(
      id: '',
      userId: '',
      workType: 'game',
      externalId: game.id.toString(),
      title: game.name,
      coverUrl: game.coverUrl,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkDetailScreen(
          work: previewWork,
          gameData: game,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DuckCard(
      onTap: () => _openDetail(context),
      child: Row(
        children: [
          if (rank != null)
            SizedBox(
              width: 28,
              child: Text('$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color:
                        rank! <= 3 ? DuckColors.primary : DuckColors.textSub,
                  )),
            ),
          _CoverImage(url: game.coverUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (game.releaseDateHuman != null)
                  Text(game.releaseDateHuman!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: DuckColors.textSub)),
                const SizedBox(height: 4),
                Row(children: [
                  if (!_canFollow)
                    _ReleasedBadge()
                  else if (game.hypes != null) ...[
                    Icon(PhosphorIconsBold.fire,
                        size: 12, color: DuckColors.accent),
                    const SizedBox(width: 4),
                    Text('관심 ${game.hypes}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: DuckColors.accent)),
                  ] else if (game.rating != null) ...[
                    Icon(PhosphorIconsBold.star,
                        size: 12, color: DuckColors.primary),
                    const SizedBox(width: 4),
                    Text('${game.rating!.toStringAsFixed(0)}점',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: DuckColors.primaryDark)),
                  ],
                ]),
              ],
            ),
          ),
          GestureDetector(
            onTap: isFollowing || !_canFollow ? null : onTap,
            child: _FollowButton(
              isFollowing: isFollowing,
              color: DuckColors.accent,
              enabled: _canFollow,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// 공통 위젯
// ══════════════════════════════════════════

class _CoverImage extends StatelessWidget {
  final String? url;
  const _CoverImage({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              width: 48,
              height: 64,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: DuckColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child:
          const Icon(PhosphorIconsBold.image, size: 20, color: DuckColors.textSub),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final Color color;
  final bool enabled;
  const _FollowButton({
    required this.isFollowing,
    required this.color,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isFollowing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (!enabled) {
      return Icon(PhosphorIconsBold.prohibit, color: DuckColors.textLight, size: 22);
    }
    return Icon(PhosphorIconsBold.plusCircle, color: color, size: 24);
  }
}

class _ReleasedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: DuckColors.textSub.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('출시됨',
          style: TextStyle(
              fontSize: 11, color: DuckColors.textSub, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;
  const _StatusBadge({this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'RELEASING' => ('방영/연재 중', DuckColors.success),
      'FINISHED' => ('완결', DuckColors.textSub),
      'NOT_YET_RELEASED' => ('출시 예정', DuckColors.primary),
      'CANCELLED' => ('취소', DuckColors.error),
      'HIATUS' => ('휴재', DuckColors.textSub),
      _ => ('', DuckColors.textSub),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
