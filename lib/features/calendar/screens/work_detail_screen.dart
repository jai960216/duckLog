import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/colors.dart';
import '../../../shared/models/calendar_event.dart';
import '../../../shared/models/followed_work.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/anilist_service.dart';
import '../services/calendar_service.dart';
import '../services/igdb_service.dart';
import '../services/webtoon_service.dart';

class WorkDetailScreen extends ConsumerStatefulWidget {
  final FollowedWork work;
  final AnilistMedia? animeData;
  final WebtoonData? webtoonData;
  final IgdbGame? gameData;

  const WorkDetailScreen({
    super.key,
    required this.work,
    this.animeData,
    this.webtoonData,
    this.gameData,
  });

  @override
  ConsumerState<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends ConsumerState<WorkDetailScreen> {
  Future<void> _unfollow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팔로우 해제'),
        content: Text('\'${widget.work.title}\'을(를) 팔로우 해제할까요?'),
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
      await service.unfollowWork(widget.work.id);
      ref.invalidate(followedWorksProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '해제 실패: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workType = widget.work.workType;
    final isAnime = workType == 'anime';
    final isManga = workType == 'manga';
    final isWebtoon = workType == 'webtoon';
    final isGame = workType == 'game';
    final airingSchedule = isAnime
        ? ref.watch(workAiringScheduleProvider(widget.work.externalId))
        : null;
    final calendarEvents = (isGame || isWebtoon)
        ? ref.watch(workEventsProvider(widget.work.externalId))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.work.title),
        actions: [
          if (widget.work.id.isNotEmpty)
            IconButton(
              onPressed: _unfollow,
              icon: Icon(PhosphorIconsBold.heartBreak, color: DuckColors.error),
              tooltip: '팔로우 해제',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── 커버 이미지 + 작품 정보 ──
          _buildHeader(context, workType),

          const SizedBox(height: 8),

          // ── 애니/만화: 작품 정보 ──
          if ((isAnime || isManga) && widget.animeData != null)
            _buildAnimeInfoSection(context, widget.animeData!),

          // ── 방영 스케줄 (애니) ──
          if (isAnime && airingSchedule != null)
            _buildAiringSection(context, airingSchedule),

          // ── 만화: 스케줄 없음 안내 (작품 정보가 없을 때만) ──
          if (isManga && widget.animeData == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DuckEmptyState(
                message: '만화/소설은 회차별 스케줄이 없어요.\n팔로우 후 내 작품에서 확인하세요.',
                icon: PhosphorIconsBold.bookOpen,
              ),
            ),

          // ── 웹툰: 작품 정보 + 연재 일정 ──
          if (isWebtoon && widget.webtoonData != null)
            _buildWebtoonInfoSection(context, widget.webtoonData!),
          if (isWebtoon && calendarEvents != null)
            _buildWebtoonSection(context, calendarEvents),

          // ── 게임: 작품 정보 ──
          if (isGame && widget.gameData != null)
            _buildGameInfoSection(context, widget.gameData!),

          // ── 출시 정보 (게임) ──
          if (isGame && calendarEvents != null)
            _buildGameEventsSection(context, calendarEvents),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String workType) {
    final (bgColor, iconData, iconColor, label) = switch (workType) {
      'anime' => (DuckColors.subLight, PhosphorIconsBold.television, DuckColors.sub, '애니메이션'),
      'manga' => (DuckColors.primaryLight, PhosphorIconsBold.bookOpen, DuckColors.primary, '만화/소설'),
      'webtoon' => (DuckColors.webtoonLight, PhosphorIconsBold.bookOpen, DuckColors.webtoon, '웹툰'),
      _ => (DuckColors.accentLight, PhosphorIconsBold.gameController, DuckColors.accent, '게임'),
    };

    return Container(
      color: DuckColors.surface,
      child: Column(
        children: [
          // 커버 이미지
          if (widget.work.coverUrl != null)
            CachedNetworkImage(
              imageUrl: widget.work.coverUrl!,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 220,
                color: DuckColors.surface,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 120,
                color: DuckColors.surface,
                child: Icon(
                  PhosphorIconsBold.image,
                  size: 48,
                  color: DuckColors.textSub,
                ),
              ),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              color: bgColor,
              child: Icon(iconData, size: 48, color: iconColor),
            ),
          // 작품 정보
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.work.title,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      DuckChip(
                        label: label,
                        backgroundColor: bgColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiringSection(
      BuildContext context, AsyncValue<List<AnilistAiringSchedule>> schedule) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Icon(PhosphorIconsBold.calendarDots, size: 18),
              const SizedBox(width: 8),
              Text('방영 예정',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              schedule.when(
                data: (list) => Text(
                  '${list.length}개',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: DuckColors.textSub),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        schedule.when(
          data: (schedules) {
            if (schedules.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DuckEmptyState(
                  message: '예정된 방영 회차가 없어요.\n완결 또는 휴방 중일 수 있어요.',
                  icon: PhosphorIconsBold.calendarCheck,
                ),
              );
            }

            return Column(
              children: schedules.map((s) {
                final date = s.airingDateTime;
                final now = DateTime.now();
                final diff = date.difference(now);
                final daysLeft = diff.inDays;

                String timeLabel;
                if (daysLeft == 0) {
                  final hoursLeft = diff.inHours;
                  timeLabel = hoursLeft > 0 ? '$hoursLeft시간 후' : '오늘';
                } else if (daysLeft == 1) {
                  timeLabel = '내일';
                } else if (daysLeft < 7) {
                  timeLabel = '$daysLeft일 후';
                } else {
                  timeLabel = '${(daysLeft / 7).floor()}주 후';
                }

                return DuckCard(
                  child: Row(
                    children: [
                      // 날짜
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: DuckColors.subLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${date.month}/${date.day}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              Formatters.weekday(date),
                              style: TextStyle(
                                fontSize: 11,
                                color: DuckColors.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 에피소드 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.episode}화',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.date(date),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: DuckColors.textSub),
                            ),
                          ],
                        ),
                      ),
                      // D-day
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: daysLeft <= 1
                              ? DuckColors.primary.withValues(alpha: 0.2)
                              : DuckColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: daysLeft <= 1
                                ? DuckColors.primaryDark
                                : DuckColors.textSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: DuckEmptyState(
              message: '방영 정보를 불러올 수 없어요.\n$e',
              icon: PhosphorIconsBold.warning,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimeInfoSection(BuildContext context, AnilistMedia media) {
    final isAnime = widget.work.workType == 'anime';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsBold.info, size: 18),
              const SizedBox(width: 8),
              Text('작품 정보',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          // 포맷
          if (media.format != null)
            _infoRow(context, '유형', media.formatKorean),
          // 상태
          _infoRow(context, '상태', media.statusKorean),
          // 스튜디오 (애니만)
          if (isAnime && media.studios.isNotEmpty)
            _infoRow(context, '제작사', media.studios.join(', ')),
          // 시즌 (애니만)
          if (isAnime && media.seasonKorean != null)
            _infoRow(context, '시즌', media.seasonKorean!),
          // 에피소드 (애니)
          if (isAnime && media.episodes != null)
            _infoRow(context, '에피소드', '${media.episodes}화'),
          // 챕터/권수 (만화)
          if (!isAnime && media.chapters != null)
            _infoRow(context, '챕터', '${media.chapters}화'),
          if (!isAnime && media.volumes != null)
            _infoRow(context, '권수', '${media.volumes}권'),
          // 장르
          if (media.genres.isNotEmpty)
            _infoRow(context, '장르', media.genres.join(', ')),
          // 평균 점수
          if (media.meanScore != null)
            _infoRow(context, '평점', '${media.meanScore}점'),
          // 원제
          if (media.subtitle != null)
            _infoRow(context, '원제', media.subtitle!),
          const SizedBox(height: 8),
          // 줄거리
          if (media.description != null && media.description!.isNotEmpty)
            _buildDescription(context, media.description!),
          // AniList 바로가기
          if (media.siteUrl != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(media.siteUrl!);
                  if (uri != null) {
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {
                      if (mounted) {
                        DuckSnackBar.error(context, '링크를 열 수 없어요.');
                      }
                    }
                  }
                },
                icon: const Icon(PhosphorIconsBold.arrowSquareOut, size: 16),
                label: const Text('AniList에서 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isAnime ? DuckColors.sub : DuckColors.primary,
                  side: BorderSide(
                    color: (isAnime ? DuckColors.sub : DuckColors.primary)
                        .withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _buildGameInfoSection(BuildContext context, IgdbGame game) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsBold.info, size: 18),
              const SizedBox(width: 8),
              Text('작품 정보',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          // 출시일
          if (game.releaseDateHuman != null)
            _infoRow(context, '출시일', game.releaseDateHuman!),
          // 평점
          if (game.rating != null)
            _infoRow(context, '평점', '${game.rating!.toStringAsFixed(0)}점'),
          // 관심도
          if (game.hypes != null)
            _infoRow(context, '관심도', '${game.hypes}'),
          // 장르
          if (game.genres.isNotEmpty)
            _infoRow(context, '장르', game.genres.join(', ')),
          // 플랫폼
          if (game.platforms.isNotEmpty)
            _infoRow(context, '플랫폼', game.platforms.join(', ')),
          const SizedBox(height: 8),
          // 줄거리
          if (game.summary != null && game.summary!.isNotEmpty)
            _buildDescription(context, game.summary!),
          // IGDB 바로가기
          if (game.url != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(game.url!);
                  if (uri != null) {
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {
                      if (mounted) {
                        DuckSnackBar.error(context, '링크를 열 수 없어요.');
                      }
                    }
                  }
                },
                icon: const Icon(PhosphorIconsBold.arrowSquareOut, size: 16),
                label: const Text('IGDB에서 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DuckColors.accent,
                  side: BorderSide(
                    color: DuckColors.accent.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context, String description) {
    // AniList description may contain HTML-like tags, strip them
    final cleaned = description
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
    if (cleaned.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('줄거리',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: DuckColors.textSub)),
          const SizedBox(height: 4),
          Text(
            cleaned,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWebtoonInfoSection(BuildContext context, WebtoonData webtoon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsBold.info, size: 18),
              const SizedBox(width: 8),
              Text('작품 정보',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          // 작가
          if (webtoon.authors.isNotEmpty)
            _infoRow(context, '작가', webtoon.authors.join(', ')),
          // 연재처
          _infoRow(context, '연재처', webtoon.providerKorean),
          // 연재 요일
          if (webtoon.updateDays.isNotEmpty)
            _infoRow(context, '연재 요일', webtoon.updateDaysKorean),
          // 상태
          _infoRow(
            context,
            '상태',
            webtoon.isEnd
                ? '완결'
                : webtoon.isUpdated
                    ? '연재 중 (오늘 업데이트)'
                    : '연재 중',
          ),
          // 유/무료
          _infoRow(context, '이용', webtoon.isFree ? '무료' : '유료'),
          const SizedBox(height: 8),
          // 웹툰 바로가기 버튼
          if (webtoon.url.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(webtoon.url);
                  if (uri != null) {
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {
                      if (mounted) {
                        DuckSnackBar.error(context, '링크를 열 수 없어요.');
                      }
                    }
                  }
                },
                icon: const Icon(PhosphorIconsBold.arrowSquareOut, size: 16),
                label: Text('${webtoon.providerKorean}에서 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DuckColors.webtoon,
                  side: BorderSide(color: DuckColors.webtoon.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: DuckColors.textSub),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebtoonSection(
      BuildContext context, AsyncValue<List<CalendarEvent>> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Icon(PhosphorIconsBold.calendarDots, size: 18),
              const SizedBox(width: 8),
              Text('연재 일정',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        events.when(
          data: (eventList) {
            if (eventList.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DuckEmptyState(
                  message: '등록된 연재 일정이 없어요.',
                  icon: PhosphorIconsBold.bookOpen,
                ),
              );
            }

            return Column(
              children: eventList.map((event) {
                final date = event.eventDate;
                final now = DateTime.now();
                final diff = date.difference(DateTime(now.year, now.month, now.day));
                final daysLeft = diff.inDays;

                String timeLabel;
                if (daysLeft < 0) {
                  timeLabel = '업데이트됨';
                } else if (daysLeft == 0) {
                  timeLabel = '오늘!';
                } else if (daysLeft == 1) {
                  timeLabel = '내일';
                } else if (daysLeft < 7) {
                  timeLabel = '$daysLeft일 후';
                } else {
                  timeLabel = '${(daysLeft / 7).floor()}주 후';
                }

                return DuckCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: DuckColors.webtoonLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${date.month}/${date.day}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              Formatters.weekday(date),
                              style: TextStyle(
                                fontSize: 11,
                                color: DuckColors.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '업데이트',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.date(date),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: DuckColors.textSub),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: daysLeft <= 1 && daysLeft >= 0
                              ? DuckColors.webtoon.withValues(alpha: 0.2)
                              : DuckColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: daysLeft <= 1 && daysLeft >= 0
                                ? DuckColors.webtoon
                                : DuckColors.textSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: DuckEmptyState(
              message: '연재 정보를 불러올 수 없어요.\n$e',
              icon: PhosphorIconsBold.warning,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameEventsSection(
      BuildContext context, AsyncValue<List<CalendarEvent>> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Icon(PhosphorIconsBold.calendarDots, size: 18),
              const SizedBox(width: 8),
              Text('출시 일정',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        events.when(
          data: (eventList) {
            if (eventList.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DuckEmptyState(
                  message: '등록된 출시 일정이 없어요.',
                  icon: PhosphorIconsBold.gameController,
                ),
              );
            }

            return Column(
              children: eventList.map((event) {
                final date = event.eventDate;
                final now = DateTime.now();
                final diff = date.difference(DateTime(now.year, now.month, now.day));
                final daysLeft = diff.inDays;

                String timeLabel;
                if (daysLeft < 0) {
                  timeLabel = '출시됨';
                } else if (daysLeft == 0) {
                  timeLabel = '오늘 출시!';
                } else if (daysLeft == 1) {
                  timeLabel = '내일';
                } else if (daysLeft < 7) {
                  timeLabel = '$daysLeft일 후';
                } else if (daysLeft < 30) {
                  timeLabel = '${(daysLeft / 7).floor()}주 후';
                } else {
                  timeLabel = '${(daysLeft / 30).floor()}개월 후';
                }

                return DuckCard(
                  child: Row(
                    children: [
                      // 날짜 박스
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: DuckColors.accentLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${date.month}/${date.day}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              Formatters.weekday(date),
                              style: TextStyle(
                                fontSize: 11,
                                color: DuckColors.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 이벤트 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.eventType == 'release' ? '출시일' : event.displayTitle,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.date(date),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: DuckColors.textSub),
                            ),
                          ],
                        ),
                      ),
                      // D-day 라벨
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: daysLeft <= 1 && daysLeft >= 0
                              ? DuckColors.accent.withValues(alpha: 0.2)
                              : DuckColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: daysLeft <= 1 && daysLeft >= 0
                                ? DuckColors.accent
                                : DuckColors.textSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: DuckEmptyState(
              message: '출시 정보를 불러올 수 없어요.\n$e',
              icon: PhosphorIconsBold.warning,
            ),
          ),
        ),
      ],
    );
  }
}
