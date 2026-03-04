import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../../goods/widgets/goods_card.dart';
import '../services/feed_service.dart';

class UserProfileScreen extends ConsumerWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final goodsAsync = ref.watch(userGoodsProvider(userId));

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
                            color: DuckColors.outline, width: 2),
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
                    Text(
                      profile.nickname,
                      style: Theme.of(context).textTheme.titleLarge,
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
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Goods count
              goodsAsync.when(
                data: (goods) => DuckCard(
                  margin: EdgeInsets.zero,
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
                        .map((g) => GoodsCard(goods: g))
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
}
