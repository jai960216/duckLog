import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/friendship.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/friend_service.dart';
import 'user_profile_screen.dart';

class FriendListScreen extends ConsumerStatefulWidget {
  const FriendListScreen({super.key});

  @override
  ConsumerState<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends ConsumerState<FriendListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 관리'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: DuckColors.text,
          unselectedLabelColor: DuckColors.textSub,
          indicatorColor: DuckColors.primary,
          tabs: [
            const Tab(text: '친구'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('받은 요청'),
                  pendingAsync.when(
                    data: (count) {
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: DuckColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const Tab(text: '보낸 요청'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FriendsTab(),
          _ReceivedRequestsTab(),
          _SentRequestsTab(),
        ],
      ),
    );
  }
}

// ──────────── 친구 탭 ────────────

class _FriendsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<_FriendsTab> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return const DuckEmptyState(
            message: '아직 친구가 없어요.\n피드에서 다른 유저에게 친구 요청을 보내보세요!',
            icon: PhosphorIconsBold.users,
          );
        }
        final currentUserId =
            ref.read(friendServiceProvider).currentUserId;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friendship = friends[index];
            final friendProfile = friendship.requesterId == currentUserId
                ? friendship.receiverProfile
                : friendship.requesterProfile;

            return _ProfileTile(
              profile: friendProfile,
              onTap: () {
                if (friendProfile == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        UserProfileScreen(userId: friendProfile.id),
                  ),
                );
              },
              trailing: IconButton(
                icon: const Icon(PhosphorIconsBold.trash,
                    size: 18, color: DuckColors.error),
                onPressed: _busy
                    ? null
                    : () => _confirmRemoveFriend(friendship),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: DuckColors.primary),
      ),
      error: (_, __) => const DuckEmptyState(
        message: '친구 목록을 불러올 수 없어요.',
        icon: PhosphorIconsBold.warning,
      ),
    );
  }

  void _confirmRemoveFriend(Friendship friendship) {
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
              setState(() => _busy = true);
              try {
                await ref
                    .read(friendServiceProvider)
                    .removeFriendship(friendship.id);
                ref.invalidate(friendsProvider);
                ref.invalidate(pendingCountProvider);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            child: const Text('삭제',
                style: TextStyle(color: DuckColors.error)),
          ),
        ],
      ),
    );
  }
}

// ──────────── 받은 요청 탭 ────────────

class _ReceivedRequestsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ReceivedRequestsTab> createState() =>
      _ReceivedRequestsTabState();
}

class _ReceivedRequestsTabState extends ConsumerState<_ReceivedRequestsTab> {
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(receivedRequestsProvider);

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const DuckEmptyState(
            message: '받은 친구 요청이 없어요.',
            icon: PhosphorIconsBold.userPlus,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final friendship = requests[index];
            final isBusy = _busyId == friendship.id;
            return _ProfileTile(
              profile: friendship.requesterProfile,
              onTap: () {
                final profile = friendship.requesterProfile;
                if (profile == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: profile.id),
                  ),
                );
              },
              trailing: isBusy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: DuckColors.primary),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(PhosphorIconsBold.check,
                              size: 20, color: DuckColors.success),
                          onPressed: () => _accept(friendship.id),
                        ),
                        IconButton(
                          icon: const Icon(PhosphorIconsBold.x,
                              size: 20, color: DuckColors.error),
                          onPressed: () => _reject(friendship.id),
                        ),
                      ],
                    ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: DuckColors.primary),
      ),
      error: (_, __) => const DuckEmptyState(
        message: '요청 목록을 불러올 수 없어요.',
        icon: PhosphorIconsBold.warning,
      ),
    );
  }

  Future<void> _accept(String id) async {
    setState(() => _busyId = id);
    try {
      await ref.read(friendServiceProvider).acceptRequest(id);
      ref.invalidate(receivedRequestsProvider);
      ref.invalidate(friendsProvider);
      ref.invalidate(pendingCountProvider);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(String id) async {
    setState(() => _busyId = id);
    try {
      await ref.read(friendServiceProvider).rejectRequest(id);
      ref.invalidate(receivedRequestsProvider);
      ref.invalidate(pendingCountProvider);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

// ──────────── 보낸 요청 탭 ────────────

class _SentRequestsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SentRequestsTab> createState() => _SentRequestsTabState();
}

class _SentRequestsTabState extends ConsumerState<_SentRequestsTab> {
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(sentRequestsProvider);

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const DuckEmptyState(
            message: '보낸 친구 요청이 없어요.',
            icon: PhosphorIconsBold.paperPlaneTilt,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final friendship = requests[index];
            final isBusy = _busyId == friendship.id;
            return _ProfileTile(
              profile: friendship.receiverProfile,
              onTap: () {
                final profile = friendship.receiverProfile;
                if (profile == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: profile.id),
                  ),
                );
              },
              trailing: isBusy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: DuckColors.primary),
                    )
                  : TextButton(
                      onPressed: () => _cancel(friendship.id),
                      child: const Text('취소',
                          style: TextStyle(color: DuckColors.textSub)),
                    ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: DuckColors.primary),
      ),
      error: (_, __) => const DuckEmptyState(
        message: '요청 목록을 불러올 수 없어요.',
        icon: PhosphorIconsBold.warning,
      ),
    );
  }

  Future<void> _cancel(String id) async {
    setState(() => _busyId = id);
    try {
      await ref.read(friendServiceProvider).removeFriendship(id);
      ref.invalidate(sentRequestsProvider);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

// ──────────── 프로필 타일 위젯 ────────────

class _ProfileTile extends StatelessWidget {
  final Profile? profile;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ProfileTile({
    this.profile,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile?.nickname ?? '알 수 없는 유저';

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: DuckColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: DuckColors.outline, width: 1.5),
        ),
        child: profile?.avatarUrl != null
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: profile!.avatarUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                      child: Text('🐥', style: TextStyle(fontSize: 20))),
                  errorWidget: (_, __, ___) => const Center(
                      child: Text('🐥', style: TextStyle(fontSize: 20))),
                ),
              )
            : const Center(
                child: Text('🐥', style: TextStyle(fontSize: 20))),
      ),
      title: Text(name, style: Theme.of(context).textTheme.bodyMedium),
      trailing: trailing,
    );
  }
}
