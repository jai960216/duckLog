import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/followed_work.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/widgets.dart';
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
        content: Text('\'${widget.work.title}\'을(를) 팔로우 해제할까요?\n등록된 이벤트는 유지됩니다.'),
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

  Future<void> _showAddEventDialog() async {
    DateTime selectedDate = DateTime.now();
    String eventType = widget.work.workType == 'anime' ? 'airing' : 'release';
    final episodeController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('이벤트 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker
                Text('날짜', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                DuckCard(
                  margin: EdgeInsets.zero,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsBold.calendar, size: 18),
                      const SizedBox(width: 8),
                      Text(Formatters.date(selectedDate)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Event type
                Text('이벤트 타입', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DuckChip(
                      label: '방영',
                      selected: eventType == 'airing',
                      onTap: () =>
                          setDialogState(() => eventType = 'airing'),
                    ),
                    const SizedBox(width: 8),
                    DuckChip(
                      label: '발매',
                      selected: eventType == 'release',
                      onTap: () =>
                          setDialogState(() => eventType = 'release'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Episode number (optional)
                DuckTextField(
                  label: '에피소드 번호 (선택)',
                  hint: '예: 1',
                  controller: episodeController,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      episodeController.dispose();
      return;
    }

    try {
      final service = ref.read(calendarServiceProvider);
      final ep = int.tryParse(episodeController.text.trim());
      episodeController.dispose();

      await service.addEvent(
        workType: widget.work.workType,
        externalId: widget.work.externalId,
        title: widget.work.title,
        eventType: eventType,
        eventDate: selectedDate,
        episodeNumber: ep,
      );

      ref.invalidate(workEventsProvider(widget.work.externalId));
      // Invalidate all month events (any month could be affected)
      final monthKey =
          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}';
      ref.invalidate(monthEventsProvider(monthKey));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이벤트가 추가되었어요!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추가 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      final service = ref.read(calendarServiceProvider);
      await service.deleteEvent(eventId);
      ref.invalidate(workEventsProvider(widget.work.externalId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이벤트가 삭제되었어요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnime = widget.work.workType == 'anime';
    final events = ref.watch(workEventsProvider(widget.work.externalId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.work.title),
        actions: [
          IconButton(
            onPressed: _unfollow,
            icon: Icon(PhosphorIconsBold.heartBreak,
                color: DuckColors.error),
            tooltip: '팔로우 해제',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        child: const Icon(PhosphorIconsBold.plus),
      ),
      body: Column(
        children: [
          // Work info header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Type badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isAnime ? DuckColors.subLight : DuckColors.accentLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isAnime
                        ? PhosphorIconsBold.television
                        : PhosphorIconsBold.gameController,
                    size: 28,
                    color: isAnime ? DuckColors.sub : DuckColors.accent,
                  ),
                ),
                const SizedBox(width: 16),
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
                      const SizedBox(height: 4),
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

          const Divider(height: 1),

          // Events section header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(PhosphorIconsBold.calendarDots, size: 18),
                const SizedBox(width: 8),
                Text('등록된 이벤트',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                events.when(
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

          // Events list
          Expanded(
            child: events.when(
              data: (eventList) {
                if (eventList.isEmpty) {
                  return const DuckEmptyState(
                    message: '아직 등록된 이벤트가 없어요.\n아래 + 버튼으로 추가해보세요!',
                    icon: PhosphorIconsBold.calendarPlus,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: eventList.length,
                  itemBuilder: (context, index) {
                    final event = eventList[index];
                    return DuckCard(
                      child: Row(
                        children: [
                          // Date
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: DuckColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${event.eventDate.month}/${event.eventDate.day}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  Formatters.weekday(event.eventDate),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: DuckColors.textSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.displayTitle,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  event.eventType == 'airing' ? '방영' : '발매',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: DuckColors.textSub),
                                ),
                              ],
                            ),
                          ),
                          // Delete
                          IconButton(
                            onPressed: () => _deleteEvent(event.id),
                            icon: Icon(
                              PhosphorIconsBold.trash,
                              size: 18,
                              color: DuckColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => DuckEmptyState(
                message: '이벤트를 불러올 수 없어요.\n$e',
                icon: PhosphorIconsBold.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
