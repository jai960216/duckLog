import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/calendar_event.dart';
import '../../../shared/models/followed_work.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/calendar_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final followedWorks = ref.watch(followedWorksProvider);
    final monthEvents = ref.watch(monthEventsProvider(_monthKey));

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
                  });
                },
                icon: const Icon(PhosphorIconsBold.caretRight, size: 20),
              ),
            ],
          ),
        ),

        // Calendar grid
        _buildCalendarGrid(monthEvents),

        const Divider(height: 1),

        // Events for selected date
        Expanded(
          child: _selectedDate != null
              ? _buildEventsForDate(_selectedDate!, monthEvents)
              : const DuckEmptyState(
                  message: '날짜를 선택하면\n일정을 확인할 수 있어요.',
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
                MaterialPageRoute(
                    builder: (_) => const WorkSearchScreen()),
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
                    Icon(PhosphorIconsBold.plus, size: 16,
                        color: DuckColors.textSub),
                    SizedBox(width: 4),
                    Text('작품 추가',
                        style: TextStyle(
                            fontSize: 13, color: DuckColors.textSub)),
                  ],
                ),
              ),
            ),
            // Followed work chips
            ...works.map((work) {
              final isAnime = work.workType == 'anime';
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: DuckChip(
                  label: work.title,
                  icon: isAnime
                      ? PhosphorIconsBold.television
                      : PhosphorIconsBold.gameController,
                  backgroundColor:
                      isAnime ? DuckColors.subLight : DuckColors.accentLight,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkDetailScreen(work: work),
                    ),
                  ),
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

  Widget _buildCalendarGrid(AsyncValue<List<CalendarEvent>> monthEvents) {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // Sunday = 0

    // Build a set of days that have events for fast lookup
    final eventDays = <int>{};
    final eventDayColors = <int, Set<String>>{}; // day -> set of workTypes
    monthEvents.whenData((events) {
      for (final event in events) {
        if (event.eventDate.month == _selectedMonth.month &&
            event.eventDate.year == _selectedMonth.year) {
          eventDays.add(event.eventDate.day);
          eventDayColors
              .putIfAbsent(event.eventDate.day, () => {})
              .add(event.workType);
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
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
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
                final dayNum =
                    weekIndex * 7 + dayIndex - startWeekday + 1;
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
                final hasEvents = eventDays.contains(dayNum);
                final dayWorkTypes = eventDayColors[dayNum] ?? {};

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
                                ? DuckColors.primaryLight.withValues(alpha: 0.3)
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
                                if (dayWorkTypes.contains('anime'))
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
                                if (dayWorkTypes.contains('game'))
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
      DateTime date, AsyncValue<List<CalendarEvent>> monthEvents) {
    return monthEvents.when(
      data: (allEvents) {
        final dayEvents = allEvents
            .where((e) =>
                e.eventDate.year == date.year &&
                e.eventDate.month == date.month &&
                e.eventDate.day == date.day)
            .toList();

        if (dayEvents.isEmpty) {
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
                  '이 날에는 일정이 없어요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: dayEvents.length,
          itemBuilder: (context, index) {
            final event = dayEvents[index];
            final isAnime = event.isAnime;

            return DuckCard(
              child: Row(
                children: [
                  // Type indicator
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isAnime ? DuckColors.sub : DuckColors.accent,
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
                          event.displayTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              isAnime
                                  ? PhosphorIconsBold.television
                                  : PhosphorIconsBold.gameController,
                              size: 12,
                              color: DuckColors.textSub,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.eventType == 'airing' ? '방영' : '발매',
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          '${Formatters.date(date)}의 일정을 불러올 수 없어요.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
