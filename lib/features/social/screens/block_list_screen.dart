import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/colors.dart';
import '../../../services/block_service.dart';
import '../../../shared/widgets/widgets.dart';

final _blockedUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(blockServiceProvider).getBlockedUsers();
});

class BlockListScreen extends ConsumerWidget {
  const BlockListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(_blockedUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('차단 관리')),
      body: blockedAsync.when(
        data: (blockedUsers) {
          if (blockedUsers.isEmpty) {
            return const DuckEmptyState(
              message: '차단한 유저가 없어요.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: blockedUsers.length,
            itemBuilder: (context, index) {
              final block = blockedUsers[index];
              final nickname = block['nickname'] as String? ?? '알 수 없음';
              final avatarUrl = block['avatar_url'] as String?;
              final blockedId = block['blocked_id'] as String;

              return DuckCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: DuckColors.surface,
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? const Text('🐥', style: TextStyle(fontSize: 20))
                        : null,
                  ),
                  title: Text(nickname),
                  trailing: TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('차단 해제'),
                          content: Text('$nickname님의 차단을 해제하시겠어요?'),
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

                      if (confirmed == true) {
                        try {
                          await ref
                              .read(blockServiceProvider)
                              .unblockUser(blockedId);
                          ref.invalidate(_blockedUsersProvider);
                          ref.invalidate(blockedUserIdsProvider);
                        } catch (e) {
                          if (context.mounted) {
                            DuckSnackBar.error(context, '차단 해제에 실패했어요');
                          }
                        }
                      }
                    },
                    child: const Text('해제',
                        style: TextStyle(color: DuckColors.error)),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: DuckColors.primary)),
        error: (_, __) =>
            const DuckEmptyState(message: '차단 목록을 불러올 수 없어요.'),
      ),
    );
  }
}
