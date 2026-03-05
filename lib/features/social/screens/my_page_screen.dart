import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/services/auth_service.dart';
import '../services/friend_service.dart';
import 'friend_list_screen.dart';
import 'profile_edit_screen.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final pendingAsync = ref.watch(pendingCountProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Profile section
        profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const DuckEmptyState(
                message: '프로필을 설정해주세요.',
                icon: PhosphorIconsBold.user,
              );
            }
            return DuckCard(
              margin: EdgeInsets.zero,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileEditScreen(),
                  ),
                );
              },
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: DuckColors.surface,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: DuckColors.outline, width: 2),
                    ),
                    child: profile.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              profile.avatarUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Center(
                            child:
                                Text('🐥', style: TextStyle(fontSize: 28)),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.nickname,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (profile.bio != null &&
                            profile.bio!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            profile.bio!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(PhosphorIconsBold.caretRight,
                      size: 18, color: DuckColors.textSub),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: DuckColors.primary),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),

        // Menu items
        _menuSection(context, '덕질 관리', [
          _menuItem(
            context,
            icon: PhosphorIconsBold.chartBar,
            label: '지출 통계',
            onTap: () {
              // TODO: Navigate to stats
            },
          ),
          _menuItem(
            context,
            icon: PhosphorIconsBold.receipt,
            label: '영수증 관리',
            onTap: () {
              // TODO: Navigate to receipts
            },
          ),
          _menuItem(
            context,
            icon: PhosphorIconsBold.arrowSquareOut,
            label: '데이터 내보내기',
            onTap: () {
              // TODO: Export feature
            },
          ),
        ]),
        const SizedBox(height: 16),

        _menuSection(context, '소셜', [
          _friendMenuItem(context, ref, pendingAsync),
          _menuItem(
            context,
            icon: PhosphorIconsBold.shareNetwork,
            label: '프로필 공유',
            onTap: () {
              // TODO: Share profile
            },
          ),
        ]),
        const SizedBox(height: 16),

        _menuSection(context, '설정', [
          _menuItem(
            context,
            icon: PhosphorIconsBold.bell,
            label: '알림 설정',
            onTap: () {
              // TODO: Notification settings
            },
          ),
          _menuItem(
            context,
            icon: PhosphorIconsBold.shieldCheck,
            label: '개인정보처리방침',
            onTap: () {
              // TODO: Privacy policy
            },
          ),
          _menuItem(
            context,
            icon: PhosphorIconsBold.fileText,
            label: '이용약관',
            onTap: () {
              // TODO: Terms of service
            },
          ),
          _menuItem(
            context,
            icon: PhosphorIconsBold.info,
            label: '앱 정보',
            subtitle: 'v1.0.0',
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 16),

        // Logout
        DuckCard(
          margin: EdgeInsets.zero,
          onTap: () => _confirmSignOut(context, ref),
          child: Row(
            children: [
              const Icon(PhosphorIconsBold.signOut,
                  size: 20, color: DuckColors.error),
              const SizedBox(width: 12),
              Text(
                '로그아웃',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DuckColors.error,
                    ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _friendMenuItem(
      BuildContext context, WidgetRef ref, AsyncValue<int> pendingAsync) {
    final pendingCount = pendingAsync.valueOrNull ?? 0;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FriendListScreen()),
        );
      },
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(PhosphorIconsBold.users,
                size: 20, color: DuckColors.text),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '친구 관리',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (pendingCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: DuckColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            const Icon(PhosphorIconsBold.caretRight,
                size: 14, color: DuckColors.textSub),
          ],
        ),
      ),
    );
  }

  Widget _menuSection(
      BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        DuckCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: DuckColors.text),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(width: 4),
            const Icon(PhosphorIconsBold.caretRight,
                size: 14, color: DuckColors.textSub),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(authServiceProvider).signOut();
            },
            child: const Text('로그아웃',
                style: TextStyle(color: DuckColors.error)),
          ),
        ],
      ),
    );
  }
}
