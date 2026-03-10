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

  /// Fetch recommended goods: public goods from users who follow the same works
  Future<List<FeedItem>> getRecommendedFeed(
      {int page = 0, int pageSize = 20}) async {
    if (_userId == null) return [];
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // 1. 내가 팔로우한 작품의 external_id 목록
    final myFollows = await _client
        .from('followed_works')
        .select('external_id')
        .eq('user_id', _userId!);
    final myExternalIds = (myFollows as List)
        .map((r) => r['external_id'] as String)
        .toSet();
    if (myExternalIds.isEmpty) return [];

    // 2. 같은 작품을 팔로우하는 다른 유저 ID 목록
    final sameFollowers = await _client
        .from('followed_works')
        .select('user_id')
        .neq('user_id', _userId!)
        .inFilter('external_id', myExternalIds.toList());
    final sameUserIds = (sameFollowers as List)
        .map((r) => r['user_id'] as String)
        .toSet()
        .toList();
    if (sameUserIds.isEmpty) return [];

    // 3. 그 유저들의 public 굿즈 조회
    final response = await _client
        .from('goods')
        .select('*, profiles!goods_user_id_fkey(*), likes(count)')
        .inFilter('user_id', sameUserIds)
        .eq('visibility', 'public')
        .order('created_at', ascending: false)
        .range(from, to);

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

    final items = <FeedItem>[];
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
      items.add(FeedItem(goods: goods, owner: owner));
    }
    return items;
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
