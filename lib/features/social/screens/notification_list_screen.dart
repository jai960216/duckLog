import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import 'notification_settings_screen.dart';

final notificationListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final box = await Hive.openBox('notifications');
  final list = <Map<String, dynamic>>[];
  for (int i = box.length - 1; i >= 0; i--) {
    final item = box.getAt(i);
    if (item is Map) {
      list.add(Map<String, dynamic>.from(item));
    }
  }
  return list;
});

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.gear, size: 20),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()),
              );
            },
            tooltip: '알림 설정',
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: DuckColors.primary),
        ),
        error: (_, _) => const Center(child: Text('알림을 불러올 수 없어요')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const DuckEmptyState(
              message: '아직 받은 알림이 없어요',
              icon: PhosphorIconsBold.bellSlash,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = notifications[index];
              final title = item['title'] as String? ?? '';
              final body = item['body'] as String? ?? '';
              final timestamp = item['timestamp'] as String?;
              final isRead = item['is_read'] as bool? ?? false;

              return DuckCard(
                margin: EdgeInsets.zero,
                onTap: () async {
                  // 읽음 처리
                  if (!isRead) {
                    final box = await Hive.openBox('notifications');
                    final realIndex = box.length - 1 - index;
                    if (realIndex >= 0) {
                      final updated = Map<String, dynamic>.from(item);
                      updated['is_read'] = true;
                      await box.putAt(realIndex, updated);
                      ref.invalidate(notificationListProvider);
                    }
                  }
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isRead
                            ? DuckColors.surface
                            : DuckColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          _getIcon(item['type'] as String?),
                          size: 18,
                          color: isRead
                              ? DuckColors.textSub
                              : DuckColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight:
                                          isRead ? FontWeight.normal : FontWeight.w600,
                                    ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              body,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (timestamp != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(timestamp),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: DuckColors.textSub),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: DuckColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'friend_request':
        return PhosphorIconsBold.userPlus;
      case 'like':
        return PhosphorIconsBold.heart;
      case 'calendar':
        return PhosphorIconsBold.calendarDots;
      default:
        return PhosphorIconsBold.bell;
    }
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}
