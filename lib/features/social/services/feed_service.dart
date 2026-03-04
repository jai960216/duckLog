import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

/// Another user's public goods
final userGoodsProvider =
    FutureProvider.autoDispose.family<List<Goods>, String>(
  (ref, userId) async {
    final service = ref.read(feedServiceProvider);
    return await service.getUserPublicGoods(userId);
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
  /// Joins with profiles to get owner info.
  Future<List<FeedItem>> getFeed({int page = 0, int pageSize = 20}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // Fetch public goods with profile join
    final response = await _client
        .from('goods')
        .select('*, profiles!goods_user_id_fkey(*)')
        .eq('visibility', 'public')
        .neq('user_id', _userId ?? '')
        .order('created_at', ascending: false)
        .range(from, to);

    final items = <FeedItem>[];
    for (final row in response as List) {
      final profileData = row['profiles'] as Map<String, dynamic>?;
      if (profileData == null) continue;

      final goods = Goods.fromJson(row);
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

  /// Get another user's public goods
  Future<List<Goods>> getUserPublicGoods(String userId,
      {int page = 0, int pageSize = 20}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final response = await _client
        .from('goods')
        .select()
        .eq('user_id', userId)
        .eq('visibility', 'public')
        .order('created_at', ascending: false)
        .range(from, to);

    return (response as List).map((e) => Goods.fromJson(e)).toList();
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
