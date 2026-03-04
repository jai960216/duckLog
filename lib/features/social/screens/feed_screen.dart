import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/feed_service.dart';
import '../widgets/feed_goods_card.dart';
import 'user_profile_screen.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  // Track like states locally for instant UI feedback
  final Map<String, bool> _likeStates = {};
  final Map<String, int> _likeCounts = {};

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedProvider(0));

    return feedAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const DuckEmptyState(
            message: '아직 피드가 비어있어요.\n다른 덕후들의 굿즈가 여기 표시됩니다!',
            icon: PhosphorIconsBold.usersThree,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(feedProvider(0));
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isLiked =
                  _likeStates[item.goods.id] ?? item.goods.isLikedByMe;
              final likeCount =
                  _likeCounts[item.goods.id] ?? item.goods.likeCount;

              return FeedGoodsCard(
                goods: item.goods,
                owner: item.owner,
                isLiked: isLiked,
                likeCount: likeCount,
                onProfileTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        UserProfileScreen(userId: item.owner.id),
                  ));
                },
                onLikeTap: () => _handleLike(item.goods.id, isLiked, likeCount),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: DuckColors.primary),
      ),
      error: (_, __) => DuckEmptyState(
        message: '피드를 불러올 수 없어요.\n다시 시도해주세요.',
        actionText: '새로고침',
        icon: PhosphorIconsBold.warning,
        onAction: () => ref.invalidate(feedProvider(0)),
      ),
    );
  }

  Future<void> _handleLike(String goodsId, bool currentlyLiked, int currentCount) async {
    // Optimistic update
    setState(() {
      _likeStates[goodsId] = !currentlyLiked;
      _likeCounts[goodsId] = currentlyLiked ? currentCount - 1 : currentCount + 1;
    });

    try {
      await ref.read(feedServiceProvider).toggleLike(goodsId);
    } catch (_) {
      // Revert on error
      setState(() {
        _likeStates[goodsId] = currentlyLiked;
        _likeCounts[goodsId] = currentCount;
      });
    }
  }
}
