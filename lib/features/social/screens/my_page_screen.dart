import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/services/auth_service.dart';
import '../../goods/services/goods_service.dart';
import '../../goods/screens/receipt_list_screen.dart';
import '../../stats/screens/stats_screen.dart';
import '../services/friend_service.dart';
import 'friend_list_screen.dart';
import 'legal_screen.dart';
import 'notification_settings_screen.dart';
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
            return Column(
              children: [
                // 프로필 카드
                DuckCard(
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
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: DuckColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: profile.avatarUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  profile.avatarUrl!,
                                  fit: BoxFit.cover,
                                  width: 56,
                                  height: 56,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Text('🐥',
                                        style: TextStyle(fontSize: 28)),
                                  ),
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
                ),

                // 친구 코드 카드
                const SizedBox(height: 12),
                DuckCard(
                  margin: EdgeInsets.zero,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: DuckColors.primarySurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(PhosphorIconsBold.identificationBadge,
                              size: 18, color: DuckColors.primaryDark),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '내 친구 코드',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: DuckColors.textSub),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile.friendCode.isNotEmpty
                                  ? profile.friendCode
                                  : '코드 생성 중...',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    letterSpacing: 3,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (profile.friendCode.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: profile.friendCode));
                            DuckSnackBar.success(
                                context, '친구 코드가 복사되었어요!');
                          },
                          icon: const Icon(PhosphorIconsBold.copy,
                              size: 20, color: DuckColors.primary),
                          tooltip: '복사',
                        ),
                    ],
                  ),
                ),
              ],
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
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              );
            },
          ),
          _menuItem(
            context,
            icon: PhosphorIconsBold.receipt,
            label: '영수증 관리',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReceiptListScreen()),
              );
            },
          ),
          _menuItem(
            context,
            icon: PhosphorIconsBold.arrowSquareOut,
            label: '지출통계 내보내기',
            onTap: () => _exportData(context, ref),
          ),
        ]),
        const SizedBox(height: 16),

        _menuSection(context, '소셜', [
          _friendMenuItem(context, ref, pendingAsync),
          _menuItem(
            context,
            icon: PhosphorIconsBold.shareNetwork,
            label: '프로필 공유',
            onTap: () => _shareProfile(context, ref),
          ),
        ]),
        const SizedBox(height: 16),

        _menuSection(context, '설정', [
          _menuItem(
            context,
            icon: PhosphorIconsBold.bell,
            label: '알림 설정',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
          _menuItem(
            context,
            icon: PhosphorIconsBold.shieldCheck,
            label: '개인정보처리방침',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LegalScreen(
                    title: '개인정보처리방침',
                    content: LegalScreen.privacyPolicyText,
                  ),
                ),
              );
            },
          ),
          _menuItem(
            context,
            icon: PhosphorIconsBold.fileText,
            label: '이용약관',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LegalScreen(
                    title: '이용약관',
                    content: LegalScreen.termsOfServiceText,
                  ),
                ),
              );
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

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: DuckColors.primary),
      ),
    );

    try {
      final goods = await ref.read(goodsServiceProvider).getAllGoods();
      final dateFormat = DateFormat('yyyy-MM-dd');

      final buffer = StringBuffer();
      buffer.write('\uFEFF'); // UTF-8 BOM for Excel compatibility
      buffer.writeln('이름,금액,카테고리,작품,아티스트,구매일,메모');
      for (final item in goods) {
        final name = _escapeCsv(item.name);
        final price = item.price?.toString() ?? '';
        final category = item.category != null
            ? _escapeCsv(item.category!)
            : '';
        final work = item.workTag != null ? _escapeCsv(item.workTag!) : '';
        final artist =
            item.artistTag != null ? _escapeCsv(item.artistTag!) : '';
        final date = item.purchasedAt != null
            ? dateFormat.format(item.purchasedAt!)
            : '';
        final memo = item.memo != null ? _escapeCsv(item.memo!) : '';
        buffer.writeln('$name,$price,$category,$work,$artist,$date,$memo');
      }

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/ducklog_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');
      await file.writeAsString(buffer.toString());

      navigator.pop(); // dismiss loading

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '덕로그 지출통계 내보내기',
      );
    } catch (e) {
      navigator.pop(); // dismiss loading
      messenger.showSnackBar(
        SnackBar(content: Text('내보내기에 실패했어요: $e')),
      );
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void _shareProfile(BuildContext context, WidgetRef ref) {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) {
      DuckSnackBar.info(context, '프로필 정보를 불러올 수 없어요');
      return;
    }

    final hasCode = profile.friendCode.isNotEmpty;
    final displayName = hasCode
        ? '${profile.nickname}#${profile.friendCode}'
        : profile.nickname;
    final text = '$displayName의 덕로그를 구경해보세요!\n'
        '${hasCode ? '친구 코드: ${profile.friendCode}\n' : ''}'
        '${profile.bio != null && profile.bio!.isNotEmpty ? '${profile.bio}\n' : ''}'
        '#덕로그 #DuckLog';

    Share.share(text);
  }
}
