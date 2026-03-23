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

  void _showSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _FriendSearchSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 관리'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.magnifyingGlass, size: 22),
            onPressed: _showSearchDialog,
            tooltip: '친구 검색',
          ),
        ],
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

// ──────────── 친구 검색 바텀시트 ────────────

class _FriendSearchSheet extends ConsumerStatefulWidget {
  const _FriendSearchSheet();

  @override
  ConsumerState<_FriendSearchSheet> createState() => _FriendSearchSheetState();
}

class _FriendSearchSheetState extends ConsumerState<_FriendSearchSheet> {
  final _controller = TextEditingController();
  bool _isSearching = false;
  bool _isSending = false;
  Profile? _result;
  String? _errorMessage;
  String? _relationshipStatus; // null, 'pending_sent', 'pending_received', 'accepted'
  bool _hasSearched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    // 닉네임#코드 형식에서 코드 추출
    String code;
    if (input.contains('#')) {
      code = input.split('#').last.trim();
    } else {
      code = input;
    }

    if (code.length != 6) {
      setState(() {
        _errorMessage = '친구 코드는 6자리예요';
        _result = null;
        _hasSearched = true;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _relationshipStatus = null;
    });

    try {
      final service = ref.read(friendServiceProvider);
      final currentUserId = service.currentUserId;

      final profile = await service.searchByFriendCode(code);

      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _result = null;
          _errorMessage = '해당 코드의 유저를 찾을 수 없어요';
          _hasSearched = true;
        });
      } else if (profile.id == currentUserId) {
        setState(() {
          _result = null;
          _errorMessage = '본인의 친구 코드예요';
          _hasSearched = true;
        });
      } else {
        // 기존 관계 확인
        final relationship = await service.getRelationship(profile.id);
        String? status;
        if (relationship != null) {
          if (relationship.isAccepted) {
            status = 'accepted';
          } else if (relationship.requesterId == currentUserId) {
            status = 'pending_sent';
          } else {
            status = 'pending_received';
          }
        }

        if (!mounted) return;
        setState(() {
          _result = profile;
          _relationshipStatus = status;
          _errorMessage = null;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '검색 중 오류가 발생했어요';
          _result = null;
          _hasSearched = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendFriendRequest(Profile profile) async {
    setState(() => _isSending = true);
    try {
      await ref.read(friendServiceProvider).sendRequest(profile.id);
      ref.invalidate(sentRequestsProvider);
      ref.invalidate(friendsProvider);
      ref.invalidate(pendingCountProvider);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('${profile.nickname}님에게 친구 요청을 보냈어요!'),
            backgroundColor: DuckColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          // 관계 상태 업데이트 (이미 요청/친구인 경우)
          if (e.toString().contains('이미 친구')) {
            _relationshipStatus = 'accepted';
          } else if (e.toString().contains('이미 요청')) {
            _relationshipStatus = 'pending_sent';
          }
        });
        DuckSnackBar.error(context, '요청에 실패했어요');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DuckColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            '친구 검색',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '친구 코드 6자리를 입력해주세요',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: DuckColors.textSub),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '코드 또는 닉네임#코드',
                    prefixIcon: const Icon(PhosphorIconsBold.hash, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DuckColors.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DuckColors.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: DuckColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _search,
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('검색'),
                ),
              ),
            ],
          ),

          if (_hasSearched) ...[
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: DuckColors.textSub),
                  ),
                ),
              ),
            if (_result != null) _buildResultCard(_result!),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildResultCard(Profile profile) {
    return DuckCard(
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: DuckColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: DuckColors.outline, width: 1.5),
            ),
            child: profile.avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: profile.avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Center(
                          child: Image.asset('assets/images/duck_avatar.png', width: 24, height: 24)),
                      errorWidget: (_, __, ___) => Center(
                          child: Image.asset('assets/images/duck_avatar.png', width: 24, height: 24)),
                    ),
                  )
                : Center(
                    child: Image.asset('assets/images/duck_avatar.png', width: 24, height: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      profile.nickname,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '#${profile.friendCode}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: DuckColors.textSub),
                    ),
                  ],
                ),
                if (profile.bio != null && profile.bio!.isNotEmpty)
                  Text(
                    profile.bio!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          _buildActionButton(profile),
        ],
      ),
    );
  }

  Widget _buildActionButton(Profile profile) {
    if (_isSending) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: DuckColors.primary),
      );
    }

    switch (_relationshipStatus) {
      case 'accepted':
        return const Chip(
          label: Text('친구', style: TextStyle(fontSize: 12)),
          backgroundColor: DuckColors.surface,
          side: BorderSide(color: DuckColors.success),
          visualDensity: VisualDensity.compact,
        );
      case 'pending_sent':
        return const Chip(
          label: Text('요청 보냄', style: TextStyle(fontSize: 12)),
          backgroundColor: DuckColors.surface,
          side: BorderSide(color: DuckColors.outline),
          visualDensity: VisualDensity.compact,
        );
      case 'pending_received':
        return const Chip(
          label: Text('요청 받음', style: TextStyle(fontSize: 12)),
          backgroundColor: DuckColors.surface,
          side: BorderSide(color: DuckColors.primary),
          visualDensity: VisualDensity.compact,
        );
      default:
        return ElevatedButton(
          onPressed: () => _sendFriendRequest(profile),
          style: ElevatedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text('친구 요청'),
        );
    }
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
            message: '아직 친구가 없어요.\n검색 버튼을 눌러 친구를 찾아보세요!',
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
              } catch (e) {
                if (mounted) DuckSnackBar.error(context, '삭제 실패');
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
    } catch (e) {
      if (mounted) DuckSnackBar.error(context, '수락 실패');
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
    } catch (e) {
      if (mounted) DuckSnackBar.error(context, '거절 실패');
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
    } catch (e) {
      if (mounted) DuckSnackBar.error(context, '취소 실패');
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
    final code = profile?.friendCode ?? '';

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
                  placeholder: (_, __) => Center(
                      child: Image.asset('assets/images/duck_avatar.png', width: 24, height: 24)),
                  errorWidget: (_, __, ___) => Center(
                      child: Image.asset('assets/images/duck_avatar.png', width: 24, height: 24)),
                ),
              )
            : Center(
                child: Image.asset('assets/images/duck_avatar.png', width: 24, height: 24)),
      ),
      title: Row(
        children: [
          Text(name, style: Theme.of(context).textTheme.bodyMedium),
          if (code.isNotEmpty)
            Text(
              '#$code',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: DuckColors.textSub),
            ),
        ],
      ),
      trailing: trailing,
    );
  }
}
