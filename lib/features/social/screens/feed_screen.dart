import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/utils/throttle.dart';
import '../../../shared/widgets/widgets.dart';
import '../../goods/screens/goods_detail_screen.dart';
import '../services/feed_service.dart';
import '../widgets/feed_goods_card.dart';
import 'user_profile_screen.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // Track like states locally for instant UI feedback
  final Map<String, bool> _likeStates = {};
  final Map<String, int> _likeCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: DuckColors.text,
          unselectedLabelColor: DuckColors.textSub,
          indicatorColor: DuckColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: '전체'),
            Tab(text: '추천'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFeedList(feedProvider(0), '아직 피드가 비어있어요.\n다른 덕후들의 굿즈가 여기 표시됩니다!'),
              _buildFeedList(recommendedFeedProvider(0), '같은 작품을 팔로우하는 유저가 없어요.\n캘린더에서 작품을 팔로우해보세요!'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedList(
      AutoDisposeFutureProvider<List<FeedItem>> provider, String emptyMessage) {
    final feedAsync = ref.watch(provider);

    return feedAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(provider);
            },
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: DuckEmptyState(
                    message: emptyMessage,
                    icon: PhosphorIconsBold.usersThree,
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
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
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GoodsDetailScreen(
                      goodsId: item.goods.id,
                      readOnly: true,
                    ),
                  ));
                  // 상세에서 좋아요 변경 후 돌아오면 로컬 캐시 제거 → provider 데이터로 갱신
                  _likeStates.remove(item.goods.id);
                  _likeCounts.remove(item.goods.id);
                  ref.invalidate(feedProvider(0));
                  ref.invalidate(recommendedFeedProvider(0));
                },
                onProfileTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        UserProfileScreen(userId: item.owner.id),
                  ));
                },
                onLikeTap: () =>
                    _handleLike(item.goods.id, isLiked, likeCount),
              );
            },
          ),
        );
      },
      loading: () => const DuckListSkeleton(
        itemSkeleton: FeedCardSkeleton(),
      ),
      error: (_, __) => DuckEmptyState(
        message: '피드를 불러올 수 없어요.\n다시 시도해주세요.',
        actionText: '새로고침',
        icon: PhosphorIconsBold.warning,
        onAction: () => ref.invalidate(provider),
      ),
    );
  }

  Future<void> _handleLike(
      String goodsId, bool currentlyLiked, int currentCount) async {
    if (!ActionThrottle.allowLike(goodsId)) return;

    // Optimistic update
    setState(() {
      _likeStates[goodsId] = !currentlyLiked;
      _likeCounts[goodsId] =
          currentlyLiked ? currentCount - 1 : currentCount + 1;
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
