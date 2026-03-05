import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../../../shared/models/calendar_event.dart';
import '../../../shared/models/followed_work.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/anilist_service.dart';
import '../services/calendar_service.dart';

class WorkDetailScreen extends ConsumerStatefulWidget {
  final FollowedWork work;

  const WorkDetailScreen({super.key, required this.work});

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('해제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnime = widget.work.workType == 'anime';
    final airingSchedule = isAnime
        ? ref.watch(workAiringScheduleProvider(widget.work.externalId))
        : null;
    final gameEvents = !isAnime
        ? ref.watch(workEventsProvider(widget.work.externalId))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.work.title),
        actions: [
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
          _buildHeader(context, isAnime),

          const SizedBox(height: 8),

          // ── 방영 스케줄 (애니) ──
          if (isAnime && airingSchedule != null)
            _buildAiringSection(context, airingSchedule),

          // ── 출시 정보 (게임) ──
          if (!isAnime && gameEvents != null)
            _buildGameEventsSection(context, gameEvents),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isAnime) {
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
              color: isAnime ? DuckColors.subLight : DuckColors.accentLight,
              child: Icon(
                isAnime
                    ? PhosphorIconsBold.television
                    : PhosphorIconsBold.gameController,
                size: 48,
                color: isAnime ? DuckColors.sub : DuckColors.accent,
              ),
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
                        label: isAnime ? '애니메이션' : '게임',
                        backgroundColor:
                            isAnime ? DuckColors.subLight : DuckColors.accentLight,
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
