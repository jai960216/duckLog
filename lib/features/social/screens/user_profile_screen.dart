import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../services/block_service.dart';
import '../../../services/report_service.dart';
import '../../../shared/models/friendship.dart';
import '../../../shared/utils/throttle.dart';
import '../../../shared/widgets/report_dialog.dart';
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
    final blockedIds = ref.watch(blockedUserIdsProvider).valueOrNull ?? {};
    if (blockedIds.contains(widget.userId)) {
      return Scaffold(
        appBar: AppBar(title: const Text('프로필')),
        body: const Center(
          child: Text('차단된 사용자입니다',
              style: TextStyle(fontSize: 16, color: DuckColors.textSub)),
        ),
      );
    }

    final profileAsync = ref.watch(userProfileProvider(widget.userId));
    final goodsAsync = ref.watch(userGoodsProvider(widget.userId));
    final catalogsAsync = ref.watch(userCatalogsProvider(widget.userId));
    final relationAsync = ref.watch(relationshipProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(PhosphorIconsBold.dotsThreeVertical),
            onSelected: (value) {
              if (value == 'block') _handleBlock();
              if (value == 'report') _handleReportUser();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(PhosphorIconsBold.warningCircle, size: 18, color: DuckColors.textSub),
                    SizedBox(width: 8),
                    Text('유저 신고'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(PhosphorIconsBold.prohibit, size: 18, color: DuckColors.error),
                    SizedBox(width: 8),
                    Text('차단하기', style: TextStyle(color: DuckColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const DuckEmptyState(
              message: '프로필을 찾을 수 없어요.',
              icon: PhosphorIconsBold.userCircle,
            );
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
              20, 20, 20,
              20 + MediaQuery.of(context).viewPadding.bottom,
            ),
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
                                placeholder: (_, _) => Center(
                                    child: Image.asset('assets/images/duck_avatar.png', width: 40, height: 40)),
                                errorWidget: (_, _, _) => Center(
                                    child: Image.asset('assets/images/duck_avatar.png', width: 40, height: 40)),
                              ),
                            )
                          : Center(
                              child: Image.asset('assets/images/duck_avatar.png', width: 40, height: 40)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            profile.nickname,
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(PhosphorIconsFill.sealCheck, size: 20, color: Color(0xFF4A9EFF)),
                        ],
                        if (profile.isSupporter) ...[
                          const SizedBox(width: 4),
                          const Icon(PhosphorIconsFill.crown, size: 18, color: Color(0xFFFFAA00)),
                        ],
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
                        GestureDetector(
                          onTap: () => launchUrl(
                            Uri.parse('https://instagram.com/${profile.snsLinks['instagram']}'),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PhosphorIconsBold.instagramLogo,
                                  size: 14, color: DuckColors.textSub),
                              const SizedBox(width: 4),
                              Text(
                                '@${profile.snsLinks['instagram']!}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: DuckColors.textSub,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      if (profile.snsLinks['twitter'] != null &&
                          profile.snsLinks['twitter']!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () => launchUrl(
                            Uri.parse('https://x.com/${profile.snsLinks['twitter']}'),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PhosphorIconsBold.xLogo,
                                  size: 14, color: DuckColors.textSub),
                              const SizedBox(width: 4),
                              Text(
                                '@${profile.snsLinks['twitter']!}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: DuckColors.textSub,
                                    ),
                              ),
                            ],
                          ),
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
                error: (_, _) => const SizedBox.shrink(),
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
                error: (_, _) => const SizedBox.shrink(),
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
                error: (_, _) => const DuckEmptyState(
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
                                ownerUserId: widget.userId,
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
                                        errorBuilder: (_, _, _) =>
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
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: DuckColors.primary),
        ),
        error: (_, _) => const DuckEmptyState(
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
    if (!ActionThrottle.allowFriendRequest(widget.userId)) {
      DuckSnackBar.error(context, '잠시 후 다시 시도해주세요');
      return;
    }
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
        DuckSnackBar.error(context, '요청 실패');
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
        DuckSnackBar.error(context, '처리 실패');
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleBlock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('유저 차단'),
        content: const Text(
          '차단하면 상대의 피드, 프로필, 굿즈가 보이지 않으며 '
          '기존 친구 관계도 해제됩니다.\n\n차단하시겠어요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('차단', style: TextStyle(color: DuckColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(blockServiceProvider).blockUser(widget.userId);
      ref.invalidate(blockedUserIdsProvider);
      ref.invalidate(relationshipProvider(widget.userId));
      ref.invalidate(friendsProvider);
      if (mounted) {
        DuckSnackBar.show(context, '차단했습니다');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) DuckSnackBar.error(context, '차단에 실패했어요');
    }
  }

  Future<void> _handleReportUser() async {
    // 중복 신고 사전 확인
    try {
      final alreadyReported =
          await ref.read(reportServiceProvider).hasAlreadyReported(widget.userId);
      if (alreadyReported) {
        if (mounted) DuckSnackBar.info(context, '이미 신고한 유저입니다');
        return;
      }
    } catch (_) {}

    if (!mounted) return;

    final result = await ReportDialog.show(
      context,
      title: '유저 신고',
      reportedUserId: widget.userId,
    );

    if (result == null || !mounted) return;

    if (!ActionThrottle.allowReport()) {
      if (mounted) DuckSnackBar.error(context, '잠시 후 다시 시도해주세요');
      return;
    }

    try {
      final reportResult = await ref.read(reportServiceProvider).reportAndBlock(
            reportedUserId: widget.userId,
            reason: result['reason']!,
            description: result['description'],
          );

      if (reportResult.alreadyReported) {
        if (mounted) DuckSnackBar.info(context, '이미 신고한 유저입니다');
        return;
      }

      ref.invalidate(blockedUserIdsProvider);
      ref.invalidate(relationshipProvider(widget.userId));
      ref.invalidate(friendsProvider);

      if (mounted) {
        DuckSnackBar.show(context, '신고가 접수되고 해당 유저가 차단되었습니다');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) DuckSnackBar.error(context, '신고에 실패했어요');
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
