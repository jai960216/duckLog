import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/anilist_service.dart';
import '../services/igdb_service.dart';
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
  String _selectedType = 'anime'; // anime or game

  // 검색
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = []; // AnilistMedia or IgdbGame
  bool _isSearching = false;
  Timer? _debounce;

  // 검색 세대 카운터 (stale 결과 방지)
  int _searchGeneration = 0;

  // 팔로우 진행 중 ID
  int? _followingId;

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
      DuckSnackBar.error(context, '검색 실패: $e');
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
          MaterialPageRoute(builder: (_) => WorkDetailScreen(work: work)),
        );
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '추가 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _followingId = null);
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
          MaterialPageRoute(builder: (_) => WorkDetailScreen(work: work)),
        );
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '추가 실패: $e');
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
        DuckSnackBar.error(context, '해제 실패: $e');
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
                      label: '게임',
                      icon: PhosphorIconsBold.gameController,
                      selected: !isAnime,
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
                  Tab(text: isAnime ? '방영 중' : '출시 예정'),
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
          isAnime
              ? _AnimeTrendingTab(
                  onFollow: _followAnime, followingId: _followingId)
              : _GamePopularTab(
                  onFollow: _followGame, followingId: _followingId),
          // Tab 2: 방영 중 / 출시 예정
          isAnime
              ? _AnimeAiringTab(
                  onFollow: _followAnime, followingId: _followingId)
              : _GameUpcomingTab(
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
    final igdbConfigured = ref.read(igdbServiceProvider).isConfigured;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: DuckTextField(
            hint: isAnime ? '애니 제목으로 검색' : '게임 제목으로 검색',
            controller: _searchController,
            prefix: const Icon(PhosphorIconsBold.magnifyingGlass, size: 20),
            onChanged: (value) {
              setState(() {});
              _onSearchChanged(value);
            },
          ),
        ),
        Expanded(
          child: !isAnime && !igdbConfigured
              ? const DuckEmptyState(
                  message:
                      'IGDB API 설정이 필요해요.\nigdb_config.dart에 Twitch 자격증명을 입력해주세요.',
                  icon: PhosphorIconsBold.gear,
                )
              : _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchController.text.trim().isEmpty
                      ? DuckEmptyState(
                          message: isAnime
                              ? '애니 제목을 입력해서\n검색해보세요!'
                              : '게임 제목을 입력해서\n검색해보세요!',
                          icon: PhosphorIconsBold.magnifyingGlass,
                        )
                      : _searchResults.isEmpty
                          ? DuckEmptyState(
                              message: isAnime
                                  ? '검색 결과가 없어요.\n영어 또는 일본어 제목으로\n검색해보세요!'
                                  : '검색 결과가 없어요.\n영어 제목으로 검색해보세요!',
                              icon: PhosphorIconsBold.magnifyingGlass,
                            )
                          : isAnime
                              ? _buildAnimeList(
                                  _searchResults.cast<AnilistMedia>())
                              : _buildGameList(
                                  _searchResults.cast<IgdbGame>()),
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
            final isAnime = work.workType == 'anime';
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
                        errorWidget: (_, __, ___) => _typeIcon(isAnime),
                      ),
                    )
                  else
                    _typeIcon(isAnime),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(work.title,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(isAnime ? '애니메이션' : '게임',
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

  Widget _buildAnimeList(List<AnilistMedia> list) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final media = list[index];
        return _AnimeCard(
          media: media,
          isFollowing: _followingId == media.id,
          onTap: () => _followAnime(media),
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

  Widget _typeIcon(bool isAnime) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isAnime ? DuckColors.subLight : DuckColors.accentLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isAnime
            ? PhosphorIconsBold.television
            : PhosphorIconsBold.gameController,
        size: 20,
        color: isAnime ? DuckColors.sub : DuckColors.accent,
      ),
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

  const _AnimeCard({
    required this.media,
    required this.isFollowing,
    required this.onTap,
    this.rank,
  });

  bool get _canFollow =>
      media.status != 'FINISHED' && media.status != 'CANCELLED';

  @override
  Widget build(BuildContext context) {
    return DuckCard(
      onTap: isFollowing || !_canFollow ? null : onTap,
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
          _FollowButton(
            isFollowing: isFollowing,
            color: DuckColors.sub,
            enabled: _canFollow,
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

  @override
  Widget build(BuildContext context) {
    return DuckCard(
      onTap: isFollowing || !_canFollow ? null : onTap,
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
          _FollowButton(
            isFollowing: isFollowing,
            color: DuckColors.accent,
            enabled: _canFollow,
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
      'RELEASING' => ('방영 중', DuckColors.success),
      'FINISHED' => ('완결', DuckColors.textSub),
      'NOT_YET_RELEASED' => ('방영 예정', DuckColors.primary),
      'CANCELLED' => ('취소', DuckColors.error),
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
