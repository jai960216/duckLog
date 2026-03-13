import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/followed_work.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/anilist_service.dart';
import '../services/calendar_service.dart';
import '../services/igdb_service.dart';
import '../services/webtoon_service.dart';
import 'work_detail_screen.dart';
import 'work_search_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;

  String get _monthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  Future<void> _openWorkDetail(FollowedWork work) async {
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: DuckColors.primary),
      ),
    );

    try {
      AnilistMedia? animeData;
      WebtoonData? webtoonData;
      IgdbGame? gameData;

      if (work.workType == 'anime' || work.workType == 'manga') {
        final mediaId = int.tryParse(work.externalId);
        if (mediaId != null) {
          final service = ref.read(anilistServiceProvider);
          final results = work.workType == 'anime'
              ? await service.searchAnime(work.title)
              : await service.searchManga(work.title);
          animeData = results
              .where((m) => m.id == mediaId)
              .firstOrNull;
          animeData ??= results.firstOrNull;
        }
      } else if (work.workType == 'webtoon') {
        final service = ref.read(webtoonServiceProvider);
        if (service.isConfigured) {
          webtoonData = await service.findWebtoon(work.title, work.externalId);
        }
      } else if (work.workType == 'game') {
        final gameId = int.tryParse(work.externalId);
        if (gameId != null) {
          final service = ref.read(igdbServiceProvider);
          if (service.isConfigured) {
            gameData = await service.findGame(work.title, gameId);
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkDetailScreen(
            work: work,
            animeData: animeData,
            webtoonData: webtoonData,
            gameData: gameData,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      // 데이터 로드 실패해도 기본 상세페이지 표시
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkDetailScreen(work: work),
        ),
      );
    }
  }


  Future<void> _confirmUnfollow(String id, String title) async {
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

  @override
  Widget build(BuildContext context) {
    final followedWorks = ref.watch(followedWorksProvider);
    final airingEntries = ref.watch(monthAiringScheduleProvider(_monthKey));

    return Column(
          children: [
            // Followed works chip bar
            _buildFollowedWorksBar(followedWorks),

            // Month selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.year,
                          _selectedMonth.month - 1,
                        );
                        _selectedDate = null;
                      });
                    },
                    icon: const Icon(PhosphorIconsBold.caretLeft, size: 20),
                  ),
                  Text(
                    Formatters.yearMonth(_selectedMonth),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.year,
                          _selectedMonth.month + 1,
                        );
                        _selectedDate = null;
                      });
                    },
                    icon: const Icon(PhosphorIconsBold.caretRight, size: 20),
                  ),
                ],
              ),
            ),

            // Calendar grid
            _buildCalendarGrid(airingEntries),

            const Divider(height: 1),

            // Events for selected date
            Expanded(
              child: _selectedDate != null
                  ? _buildEventsForDate(_selectedDate!, airingEntries)
                  : const DuckEmptyState(
                      message: '날짜를 선택하면\n방영 일정을 확인할 수 있어요.',
                      icon: PhosphorIconsBold.calendarBlank,
                    ),
            ),
          ],
    );
  }

  Widget _buildFollowedWorksBar(AsyncValue<List<FollowedWork>> followedWorks) {
    return SizedBox(
      height: 48,
      child: followedWorks.when(
        data: (works) => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          children: [
            // Add button
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkSearchScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: DuckColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: DuckColors.textLight,
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsBold.plus,
                        size: 16, color: DuckColors.textSub),
                    SizedBox(width: 4),
                    Text('작품 추가',
                        style:
                            TextStyle(fontSize: 13, color: DuckColors.textSub)),
                  ],
                ),
              ),
            ),
            // Followed work chips
            ...works.map((work) {
              final (icon, bgColor) = switch (work.workType) {
                'anime' => (PhosphorIconsBold.television, DuckColors.subLight),
                'manga' => (PhosphorIconsBold.bookOpen, DuckColors.primaryLight),
                'webtoon' => (PhosphorIconsBold.bookOpen, DuckColors.webtoonLight),
                _ => (PhosphorIconsBold.gameController, DuckColors.accentLight),
              };
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: DuckChip(
                  label: work.title,
                  icon: icon,
                  backgroundColor: bgColor,
                  onTap: () => _openWorkDetail(work),
                  onLongPress: () => _confirmUnfollow(work.id, work.title),
                ),
              );
            }),
          ],
        ),
        loading: () => const Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildCalendarGrid(AsyncValue<List<AiringEntry>> airingEntries) {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // Sunday = 0

    // 이벤트가 있는 날짜 + 타입 추적
    final eventDayTypes = <int, Set<String>>{}; // day -> {anime, game}
    airingEntries.whenData((entries) {
      for (final entry in entries) {
        if (entry.airingDate.month == _selectedMonth.month &&
            entry.airingDate.year == _selectedMonth.year) {
          eventDayTypes
              .putIfAbsent(entry.airingDate.day, () => {})
              .add(entry.workType);
        }
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['일', '월', '화', '수', '목', '금', '토']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: d == '일'
                                    ? DuckColors.accent
                                    : d == '토'
                                        ? const Color(0xFF6B9FFF)
                                        : DuckColors.textSub,
                              ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Date cells
          ...List.generate(6, (weekIndex) {
            return Row(
              children: List.generate(7, (dayIndex) {
                final dayNum = weekIndex * 7 + dayIndex - startWeekday + 1;
                if (dayNum < 1 || dayNum > lastDay.day) {
                  return const Expanded(child: SizedBox(height: 44));
                }

                final date = DateTime(
                    _selectedMonth.year, _selectedMonth.month, dayNum);
                final isSelected = _selectedDate != null &&
                    _selectedDate!.year == date.year &&
                    _selectedDate!.month == date.month &&
                    _selectedDate!.day == date.day;
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;
                final dayTypes = eventDayTypes[dayNum] ?? {};
                final hasEvents = dayTypes.isNotEmpty;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDate = date),
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DuckColors.primary
                            : isToday
                                ? DuckColors.primaryLight
                                    .withValues(alpha: 0.3)
                                : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? DuckColors.outline
                                  : DuckColors.text,
                            ),
                          ),
                          if (hasEvents)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (dayTypes.contains('anime'))
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(
                                        top: 2, right: 1),
                                    decoration: const BoxDecoration(
                                      color: DuckColors.sub,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (dayTypes.contains('manga'))
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(
                                        top: 2, right: 1),
                                    decoration: const BoxDecoration(
                                      color: DuckColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (dayTypes.contains('webtoon'))
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(
                                        top: 2, right: 1),
                                    decoration: const BoxDecoration(
                                      color: DuckColors.webtoon,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (dayTypes.contains('game'))
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(
                                        top: 2, left: 1),
                                    decoration: const BoxDecoration(
                                      color: DuckColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (dayTypes.contains('custom'))
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(
                                        top: 2, left: 1),
                                    decoration: const BoxDecoration(
                                      color: DuckColors.text,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEventsForDate(
      DateTime date, AsyncValue<List<AiringEntry>> airingEntries) {
    return airingEntries.when(
      data: (allEntries) {
        final dayEntries = allEntries
            .where((e) =>
                e.airingDate.year == date.year &&
                e.airingDate.month == date.month &&
                e.airingDate.day == date.day)
            .toList();

        if (dayEntries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsBold.calendarCheck,
                    size: 40, color: DuckColors.textSub),
                const SizedBox(height: 12),
                Text(
                  '${Formatters.date(date)}의 일정',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '이 날에는 방영 일정이 없어요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: dayEntries.length,
          itemBuilder: (context, index) {
            final entry = dayEntries[index];

            final (indicatorColor, iconData, eventLabel) = switch (entry.workType) {
              'anime' => (DuckColors.sub, PhosphorIconsBold.television, '방영'),
              'manga' => (DuckColors.primary, PhosphorIconsBold.bookOpen, '연재'),
              'webtoon' => (DuckColors.webtoon, PhosphorIconsBold.bookOpen, '업데이트'),
              'custom' => (DuckColors.text, PhosphorIconsBold.notepad, '일정'),
              _ => (DuckColors.accent, PhosphorIconsBold.gameController, '출시'),
            };

            return DuckCard(
              child: Row(
                children: [
                  // Type indicator
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Event info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.displayTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              iconData,
                              size: 12,
                              color: DuckColors.textSub,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              eventLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: DuckColors.textSub),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => DuckSkeleton(
        child: Column(
          children: List.generate(3, (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: DuckColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          )),
        ),
      ),
      error: (_, __) => Center(
        child: Text(
          '일정을 불러올 수 없어요.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
