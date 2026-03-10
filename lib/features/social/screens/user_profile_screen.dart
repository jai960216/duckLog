import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/friendship.dart';
import '../../../shared/widgets/widgets.dart';
import '../../catalog/screens/catalog_detail_screen.dart';
import '../../goods/screens/goods_detail_screen.dart';
import '../../goods/widgets/goods_card.dart';
import '../services/feed_service.dart';
import '../services/friend_service.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _actionLoading = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.userId));
    final goodsAsync = ref.watch(userGoodsProvider(widget.userId));
    final catalogsAsync = ref.watch(userCatalogsProvider(widget.userId));
    final relationAsync = ref.watch(relationshipProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const DuckEmptyState(
              message: '프로필을 찾을 수 없어요.',
              icon: PhosphorIconsBold.userCircle,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Profile header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: DuckColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: DuckColors.textLight, width: 1.5),
                      ),
                      child: profile.avatarUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: profile.avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                    child: Text('🐥',
                                        style: TextStyle(fontSize: 32))),
                                errorWidget: (_, __, ___) => const Center(
                                    child: Text('🐥',
                                        style: TextStyle(fontSize: 32))),
                              ),
                            )
                          : const Center(
                              child: Text('🐥',
                                  style: TextStyle(fontSize: 32))),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          profile.nickname,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (profile.friendCode.isNotEmpty)
                          Text(
                            '#${profile.friendCode}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: DuckColors.textSub),
                          ),
                      ],
                    ),
                    if (profile.bio != null &&
                        profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        profile.bio!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: DuckColors.textSub,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    // SNS 링크
                    if (profile.snsLinks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      if (profile.snsLinks['instagram'] != null &&
                          profile.snsLinks['instagram']!.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(PhosphorIconsBold.instagramLogo,
                                size: 14, color: DuckColors.textSub),
                            const SizedBox(width: 4),
                            Text(
                              profile.snsLinks['instagram']!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: DuckColors.textSub,
                                  ),
                            ),
                          ],
                        ),
                      if (profile.snsLinks['twitter'] != null &&
                          profile.snsLinks['twitter']!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(PhosphorIconsBold.xLogo,
                                size: 14, color: DuckColors.textSub),
                            const SizedBox(width: 4),
                            Text(
                              profile.snsLinks['twitter']!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: DuckColors.textSub,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Friend relationship button
              relationAsync.when(
                data: (friendship) =>
                    _buildRelationButton(context, friendship),
                loading: () => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: DuckColors.primary),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),

              // Goods count
              goodsAsync.when(
                data: (goods) => DuckCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(PhosphorIconsBold.package,
                          size: 18, color: DuckColors.textSub),
                      const SizedBox(width: 8),
                      Text(
                        '공개 굿즈 ${goods.length}개',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),

              // User's public goods
              Text(
                '굿즈 목록',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              goodsAsync.when(
                data: (goods) {
                  if (goods.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: DuckEmptyState(
                        message: '공개된 굿즈가 없어요.',
                        icon: PhosphorIconsBold.package,
                      ),
                    );
                  }
                  return Column(
                    children: goods
                        .map((g) => GoodsCard(
                              goods: g,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => GoodsDetailScreen(
                                      goodsId: g.id,
                                      readOnly: true,
                                    ),
                                  ),
                                );
                              },
                            ))
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: DuckColors.primary),
                  ),
                ),
                error: (_, __) => const DuckEmptyState(
                  message: '데이터를 불러올 수 없어요.',
                  icon: PhosphorIconsBold.warning,
                ),
              ),

              const SizedBox(height: 24),

              // Catalogs section
              catalogsAsync.when(
                data: (catalogs) {
                  if (catalogs.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '공개 도감 ${catalogs.length}개',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...catalogs.map((catalog) => DuckCard(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CatalogDetailScreen(
                                catalogId: catalog.id,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            // Cover thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: catalog.coverUrl != null
                                    ? Image.network(
                                        catalog.coverUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          color: DuckColors.surface,
                                          child: const Icon(
                                            PhosphorIconsBold.books,
                                            color: DuckColors.textSub,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: DuckColors.surface,
                                        child: const Icon(
                                          PhosphorIconsBold.books,
                                          color: DuckColors.textSub,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    catalog.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (catalog.workTag != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      catalog.workTag!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: DuckColors.textSub,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(
                              PhosphorIconsBold.caretRight,
                              size: 16,
                              color: DuckColors.textSub,
                            ),
                          ],
                        ),
                      )),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: DuckColors.primary),
        ),
        error: (_, __) => const DuckEmptyState(
          message: '프로필을 불러올 수 없어요.',
          icon: PhosphorIconsBold.warning,
        ),
      ),
    );
  }

  Widget _buildRelationButton(
      BuildContext context, Friendship? friendship) {
    if (_actionLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: DuckColors.primary),
        ),
      );
    }

    final currentUserId = ref.read(friendServiceProvider).currentUserId;

    // 관계 없음
    if (friendship == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () => _sendRequest(),
          icon: const Icon(PhosphorIconsBold.userPlus, size: 18),
          label: const Text('친구 요청'),
        ),
      );
    }

    // accepted
    if (friendship.isAccepted) {
      return Center(
        child: OutlinedButton.icon(
          onPressed: () => _confirmRemoveFriend(friendship.id),
          icon: const Icon(PhosphorIconsBold.checkCircle, size: 18,
              color: DuckColors.success),
          label: const Text('친구',
              style: TextStyle(color: DuckColors.success)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: DuckColors.success),
          ),
        ),
      );
    }

    // pending — 내가 보냄
    if (friendship.isPending && friendship.requesterId == currentUserId) {
      return Center(
        child: OutlinedButton.icon(
          onPressed: () => _cancelRequest(friendship.id),
          icon: const Icon(PhosphorIconsBold.clock, size: 18,
              color: DuckColors.textSub),
          label: const Text('요청 보냄',
              style: TextStyle(color: DuckColors.textSub)),
        ),
      );
    }

    // pending — 상대가 보냄
    if (friendship.isPending && friendship.receiverId == currentUserId) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => _acceptRequest(friendship.id),
            child: const Text('수락'),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _rejectRequest(friendship.id),
            child: const Text('거절'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _sendRequest() async {
    setState(() => _actionLoading = true);
    try {
      await ref.read(friendServiceProvider).sendRequest(widget.userId);
      ref.invalidate(relationshipProvider(widget.userId));
      ref.invalidate(sentRequestsProvider);
      ref.invalidate(friendsProvider);
      ref.invalidate(receivedRequestsProvider);
      ref.invalidate(pendingCountProvider);
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '요청 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _cancelRequest(String friendshipId) async {
    await _runAction(() async {
      await ref.read(friendServiceProvider).removeFriendship(friendshipId);
      ref.invalidate(relationshipProvider(widget.userId));
      ref.invalidate(sentRequestsProvider);
    });
  }

  Future<void> _acceptRequest(String friendshipId) async {
    await _runAction(() async {
      await ref.read(friendServiceProvider).acceptRequest(friendshipId);
      ref.invalidate(relationshipProvider(widget.userId));
      ref.invalidate(receivedRequestsProvider);
      ref.invalidate(friendsProvider);
      ref.invalidate(pendingCountProvider);
    });
  }

  Future<void> _rejectRequest(String friendshipId) async {
    await _runAction(() async {
      await ref.read(friendServiceProvider).rejectRequest(friendshipId);
      ref.invalidate(relationshipProvider(widget.userId));
      ref.invalidate(receivedRequestsProvider);
      ref.invalidate(pendingCountProvider);
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _actionLoading = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '처리 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _confirmRemoveFriend(String friendshipId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('친구 삭제'),
        content: const Text('정말 친구를 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _runAction(() async {
                await ref
                    .read(friendServiceProvider)
                    .removeFriendship(friendshipId);
                ref.invalidate(relationshipProvider(widget.userId));
                ref.invalidate(friendsProvider);
              });
            },
            child: const Text('삭제',
                style: TextStyle(color: DuckColors.error)),
          ),
        ],
      ),
    );
  }

}
