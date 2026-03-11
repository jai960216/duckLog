import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/catalog.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/models/profile.dart';
import '../../auth/services/auth_service.dart';

/// A feed item: goods + owner profile
class FeedItem {
  final Goods goods;
  final Profile owner;

  const FeedItem({required this.goods, required this.owner});
}

final feedServiceProvider = Provider<FeedService>((ref) {
  return FeedService(ref.read(supabaseClientProvider));
});

/// Feed list provider — key is page number
final feedProvider = FutureProvider.autoDispose.family<List<FeedItem>, int>(
  (ref, page) async {
    final service = ref.read(feedServiceProvider);
    return await service.getFeed(page: page);
  },
);

/// Recommended feed — public goods from users who follow the same works
final recommendedFeedProvider =
    FutureProvider.autoDispose.family<List<FeedItem>, int>(
  (ref, page) async {
    final service = ref.read(feedServiceProvider);
    return await service.getRecommendedFeed(page: page);
  },
);

/// Another user's public goods
final userGoodsProvider =
    FutureProvider.autoDispose.family<List<Goods>, String>(
  (ref, userId) async {
    final service = ref.read(feedServiceProvider);
    return await service.getUserPublicGoods(userId);
  },
);

/// Another user's public catalogs
final userCatalogsProvider =
    FutureProvider.autoDispose.family<List<Catalog>, String>(
  (ref, userId) async {
    final service = ref.read(feedServiceProvider);
    return await service.getUserPublicCatalogs(userId);
  },
);

/// Another user's profile
final userProfileProvider =
    FutureProvider.autoDispose.family<Profile?, String>(
  (ref, userId) async {
    final service = ref.read(feedServiceProvider);
    return await service.getUserProfile(userId);
  },
);

class FeedService {
  final SupabaseClient _client;

  FeedService(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  /// Fetch public goods from all users (excluding self), newest first.
  /// Joins with profiles and likes to get owner info + like data.
  Future<List<FeedItem>> getFeed({int page = 0, int pageSize = 20}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // Fetch goods with profile + likes count
    final response = await _client
        .from('goods')
        .select('*, profiles!goods_user_id_fkey(*), likes(count)')
        .neq('user_id', _userId ?? '')
        .inFilter('visibility', ['public', 'friends'])
        .order('created_at', ascending: false)
        .range(from, to);

    // Batch fetch current user's liked goods IDs
    final goodsIds = (response as List).map((r) => r['id'] as String).toList();
    final Set<String> likedIds = {};
    if (_userId != null && goodsIds.isNotEmpty) {
      final likedResponse = await _client
          .from('likes')
          .select('goods_id')
          .eq('user_id', _userId!)
          .inFilter('goods_id', goodsIds);
      for (final row in likedResponse as List) {
        likedIds.add(row['goods_id'] as String);
      }
    }

    final items = <FeedItem>[];
    for (final row in response) {
      final profileData = row['profiles'] as Map<String, dynamic>?;
      if (profileData == null) continue;

      // Extract like count from aggregation
      final likesData = row['likes'] as List?;
      final likeCount = (likesData != null && likesData.isNotEmpty)
          ? (likesData[0]['count'] as int? ?? 0)
          : 0;

      final enriched = Map<String, dynamic>.from(row);
      enriched['like_count'] = likeCount;
      enriched['is_liked_by_me'] = likedIds.contains(row['id']);

      final goods = Goods.fromJson(enriched);
      final owner = Profile.fromJson(profileData);
      items.add(FeedItem(goods: goods, owner: owner));
    }
    return items;
  }

  /// Fetch recommended goods with relevance scoring.
  /// Signals: same work tag (+3), same category (+2), friend (+2),
  /// like count (+1 per 5 likes, max +3), recency (+1 if < 7 days)
  Future<List<FeedItem>> getRecommendedFeed(
      {int page = 0, int pageSize = 20}) async {
    if (_userId == null) return [];

    // 1. 내 프로필 데이터 수집 (병렬)
    final results = await Future.wait([
      // 내가 팔로우한 작품
      _client
          .from('followed_works')
          .select('external_id, title')
          .eq('user_id', _userId!),
      // 내 굿즈의 작품태그 + 카테고리 분포
      _client
          .from('goods')
          .select('work_tag, category')
          .eq('user_id', _userId!),
      // 내 친구 목록
      _client
          .from('friendships')
          .select('requester_id, receiver_id')
          .eq('status', 'accepted')
          .or('requester_id.eq.$_userId,receiver_id.eq.$_userId'),
    ]);

    final myFollows = results[0] as List;
    final myGoods = results[1] as List;
    final myFriendships = results[2] as List;

    // 팔로우한 작품 제목 set
    final myWorkTitles = myFollows
        .map((r) => r['title'] as String?)
        .whereType<String>()
        .toSet();

    // 내 굿즈 작품태그 set
    final myWorkTags = myGoods
        .map((r) => r['work_tag'] as String?)
        .whereType<String>()
        .toSet();

    // 내 굿즈 카테고리 빈도 (상위 카테고리에 가중치)
    final categoryCount = <String, int>{};
    for (final g in myGoods) {
      final cat = g['category'] as String?;
      if (cat != null) categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
    }
    final myTopCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final myCategories = myTopCategories
        .take(5)
        .map((e) => e.key)
        .toSet();

    // 친구 ID set
    final friendIds = <String>{};
    for (final f in myFriendships) {
      final reqId = f['requester_id'] as String;
      final recId = f['receiver_id'] as String;
      friendIds.add(reqId == _userId ? recId : reqId);
    }

    // 관련 유저 찾기: 같은 작품 팔로우 유저
    final myExternalIds = myFollows
        .map((r) => r['external_id'] as String)
        .toSet();

    Set<String> relatedUserIds = {};
    if (myExternalIds.isNotEmpty) {
      final sameFollowers = await _client
          .from('followed_works')
          .select('user_id')
          .neq('user_id', _userId!)
          .inFilter('external_id', myExternalIds.toList());
      relatedUserIds = (sameFollowers as List)
          .map((r) => r['user_id'] as String)
          .toSet();
    }

    // 친구도 후보에 추가
    final candidateUserIds = {...relatedUserIds, ...friendIds};
    if (candidateUserIds.isEmpty) return [];

    // 2. 후보 유저들의 public 굿즈 조회 (넉넉하게 가져와서 스코어링)
    final fetchSize = pageSize * 4; // 스코어링 후 잘라내기 위해 여유있게
    final response = await _client
        .from('goods')
        .select('*, profiles!goods_user_id_fkey(*), likes(count)')
        .inFilter('user_id', candidateUserIds.toList())
        .inFilter('visibility', ['public', 'friends'])
        .order('created_at', ascending: false)
        .range(0, fetchSize - 1);

    // Like 상태 batch fetch
    final goodsIds =
        (response as List).map((r) => r['id'] as String).toList();
    final Set<String> likedIds = {};
    if (goodsIds.isNotEmpty) {
      final likedResponse = await _client
          .from('likes')
          .select('goods_id')
          .eq('user_id', _userId!)
          .inFilter('goods_id', goodsIds);
      for (final row in likedResponse as List) {
        likedIds.add(row['goods_id'] as String);
      }
    }

    // 3. FeedItem 생성 + 스코어 계산
    final scored = <(FeedItem, double)>[];
    final now = DateTime.now();

    for (final row in response) {
      final profileData = row['profiles'] as Map<String, dynamic>?;
      if (profileData == null) continue;
      final likesData = row['likes'] as List?;
      final likeCount = (likesData != null && likesData.isNotEmpty)
          ? (likesData[0]['count'] as int? ?? 0)
          : 0;
      final enriched = Map<String, dynamic>.from(row);
      enriched['like_count'] = likeCount;
      enriched['is_liked_by_me'] = likedIds.contains(row['id']);
      final goods = Goods.fromJson(enriched);
      final owner = Profile.fromJson(profileData);
      final item = FeedItem(goods: goods, owner: owner);

      // 스코어 계산
      double score = 0;

      // 같은 작품태그 (+3)
      if (goods.workTag != null &&
          (myWorkTags.contains(goods.workTag) ||
           myWorkTitles.contains(goods.workTag))) {
        score += 3;
      }

      // 같은 카테고리 (+2)
      if (goods.category != null && myCategories.contains(goods.category)) {
        score += 2;
      }

      // 친구 (+2)
      if (friendIds.contains(goods.userId)) {
        score += 2;
      }

      // 좋아요 인기도 (+1 per 5 likes, max +3)
      score += (likeCount / 5).clamp(0, 3).toDouble();

      // 최신 글 보너스 (7일 이내 +1)
      if (now.difference(goods.createdAt).inDays < 7) {
        score += 1;
      }

      scored.add((item, score));
    }

    // 4. 스코어 내림차순 정렬 → 페이지네이션
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    final from = page * pageSize;
    final to = (from + pageSize).clamp(0, scored.length);
    if (from >= scored.length) return [];

    return scored.sublist(from, to).map((e) => e.$1).toList();
  }

  /// Get another user's public profile
  Future<Profile?> getUserProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (response == null) return null;
    return Profile.fromJson(response);
  }

  /// Get another user's visible goods (public + friends if friended)
  Future<List<Goods>> getUserPublicGoods(String userId,
      {int page = 0, int pageSize = 20}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // RLS handles friends visibility check
    final response = await _client
        .from('goods')
        .select()
        .eq('user_id', userId)
        .inFilter('visibility', ['public', 'friends'])
        .order('created_at', ascending: false)
        .range(from, to);

    return (response as List).map((e) => Goods.fromJson(e)).toList();
  }

  /// Get another user's public catalogs
  Future<List<Catalog>> getUserPublicCatalogs(String userId) async {
    final response = await _client
        .from('catalogs')
        .select()
        .eq('user_id', userId)
        .eq('visibility', 'public')
        .order('updated_at', ascending: false);

    return (response as List).map((e) => Catalog.fromJson(e)).toList();
  }

  /// Toggle like on a goods item. Returns new like state.
  Future<bool> toggleLike(String goodsId) async {
    if (_userId == null) throw Exception('Not authenticated');

    final existing = await _client
        .from('likes')
        .select('id')
        .eq('user_id', _userId!)
        .eq('goods_id', goodsId)
        .maybeSingle();

    if (existing != null) {
      await _client.from('likes').delete().eq('id', existing['id']);
      return false;
    } else {
      await _client.from('likes').insert({
        'user_id': _userId,
        'goods_id': goodsId,
      });
      return true;
    }
  }

  /// Get like count for a goods item
  Future<int> getLikeCount(String goodsId) async {
    final response = await _client
        .from('likes')
        .select('id')
        .eq('goods_id', goodsId);
    return (response as List).length;
  }

  /// Check if current user liked a goods item
  Future<bool> isLiked(String goodsId) async {
    if (_userId == null) return false;
    final response = await _client
        .from('likes')
        .select('id')
        .eq('user_id', _userId!)
        .eq('goods_id', goodsId)
        .maybeSingle();
    return response != null;
  }
}
