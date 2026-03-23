import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/utils/constants.dart';
import '../../auth/services/auth_service.dart';
import '../../subscription/services/subscription_service.dart';

final goodsServiceProvider = Provider<GoodsService>((ref) {
  return GoodsService(ref.read(supabaseClientProvider));
});

// Provider for goods list with filters
final goodsListProvider =
    FutureProvider.autoDispose.family<List<Goods>, GoodsFilter>(
  (ref, filter) async {
    final service = ref.read(goodsServiceProvider);
    return await service.getGoods(filter: filter);
  },
);

// Monthly spending entry for history chart
class MonthlySpendingEntry {
  final DateTime month;
  final int amount;
  const MonthlySpendingEntry({required this.month, required this.amount});
}

// Monthly stats data class
class MonthlyStats {
  final int goodsCount;
  final int categoryCount;
  final int workTagCount;

  const MonthlyStats({
    required this.goodsCount,
    required this.categoryCount,
    required this.workTagCount,
  });
}

// Provider for monthly stats - key is "yyyy-MM" string
final monthlyStatsProvider =
    FutureProvider.autoDispose.family<MonthlyStats, String>(
  (ref, monthKey) async {
    final parts = monthKey.split('-');
    final month = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final service = ref.read(goodsServiceProvider);
    return await service.getMonthlyStats(month);
  },
);

// Provider for monthly spending - key is "yyyy-MM" string for stable identity
final monthlySpendingProvider =
    FutureProvider.autoDispose.family<int, String>(
  (ref, monthKey) async {
    final parts = monthKey.split('-');
    final month = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final service = ref.read(goodsServiceProvider);
    return await service.getMonthlySpending(month);
  },
);

// Provider for work tag spending - key is "yyyy-MM" string
final workTagSpendingProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>(
  (ref, monthKey) async {
    final parts = monthKey.split('-');
    final month = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final service = ref.read(goodsServiceProvider);
    return await service.getWorkTagSpending(month);
  },
);

// Provider for spending history - key is number of months
final spendingHistoryProvider =
    FutureProvider.autoDispose.family<List<MonthlySpendingEntry>, int>(
  (ref, months) async {
    final service = ref.read(goodsServiceProvider);
    return await service.getMonthlySpendingHistory(months);
  },
);

class GoodsFilter {
  final String? category;
  final String? workTag;
  final String? artistTag;
  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final int pageSize;

  const GoodsFilter({
    this.category,
    this.workTag,
    this.artistTag,
    this.startDate,
    this.endDate,
    this.page = 0,
    this.pageSize = AppConstants.pageSize,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoodsFilter &&
          category == other.category &&
          workTag == other.workTag &&
          artistTag == other.artistTag &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(
      category, workTag, artistTag, startDate, endDate, page, pageSize);

  GoodsFilter copyWith({
    String? category,
    String? workTag,
    String? artistTag,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
  }) {
    return GoodsFilter(
      category: category ?? this.category,
      workTag: workTag ?? this.workTag,
      artistTag: artistTag ?? this.artistTag,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      page: page ?? this.page,
      pageSize: pageSize,
    );
  }
}

class GoodsService {
  final SupabaseClient _client;

  GoodsService(this._client);

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.id;
  }

  // Create
  Future<Goods> createGoods({
    required String name,
    int? price,
    String? category,
    String? workTag,
    String? artistTag,
    List<String>? photoUrls,
    DateTime? purchasedAt,
    String? purchasePlace,
    String? memo,
    String visibility = 'public',
    String? catalogItemId,
  }) async {
    final baseData = {
      'user_id': _userId,
      'name': name,
      'price': price,
      'category': category,
      'work_tag': workTag,
      'artist_tag': artistTag,
      'photo_urls': photoUrls ?? [],
      'purchased_at': purchasedAt?.toIso8601String().split('T').first,
      'memo': memo,
      'visibility': visibility,
      'catalog_item_id': catalogItemId,
    };

    // purchase_place 컬럼이 DB에 없을 수 있으므로 포함해서 시도 후 실패 시 제외
    if (purchasePlace != null && purchasePlace.isNotEmpty) {
      try {
        final data = {...baseData, 'purchase_place': purchasePlace};
        final response =
            await _client.from('goods').insert(data).select().single();
        return Goods.fromJson(response);
      } catch (_) {
        // purchase_place 컬럼이 없을 수 있음 — 컬럼 없이 재시도
      }
    }

    final response =
        await _client.from('goods').insert(baseData).select().single();
    return Goods.fromJson(response);
  }

  // Read - all goods (no pagination, for export)
  Future<List<Goods>> getAllGoods() async {
    final response = await _client
        .from('goods')
        .select()
        .eq('user_id', _userId)
        .order('purchased_at', ascending: false)
        .order('created_at', ascending: false);

    return (response as List).map((e) => Goods.fromJson(e)).toList();
  }

  // Read - list with filters (with like counts)
  Future<List<Goods>> getGoods({GoodsFilter filter = const GoodsFilter()}) async {
    var query = _client.from('goods').select('*, likes(count)').eq('user_id', _userId);

    if (filter.category != null) {
      query = query.eq('category', filter.category!);
    }
    if (filter.workTag != null) {
      query = query.eq('work_tag', filter.workTag!);
    }
    if (filter.artistTag != null) {
      query = query.eq('artist_tag', filter.artistTag!);
    }
    if (filter.startDate != null) {
      query = query.gte(
          'purchased_at', filter.startDate!.toIso8601String().split('T').first);
    }
    if (filter.endDate != null) {
      query = query.lte(
          'purchased_at', filter.endDate!.toIso8601String().split('T').first);
    }

    final from = filter.page * filter.pageSize;
    final to = from + filter.pageSize - 1;

    final response = await query
        .order('purchased_at', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);

    final rows = response as List;

    // 현재 유저가 좋아요한 goods_id 목록 batch fetch
    final goodsIds = rows.map((r) => r['id'] as String).toList();
    final Set<String> likedIds = {};
    final user = _client.auth.currentUser;
    if (user != null && goodsIds.isNotEmpty) {
      final likedResponse = await _client
          .from('likes')
          .select('goods_id')
          .eq('user_id', user.id)
          .inFilter('goods_id', goodsIds);
      for (final row in likedResponse as List) {
        likedIds.add(row['goods_id'] as String);
      }
    }

    return rows.map((e) {
      final likesData = e['likes'] as List?;
      final likeCount = (likesData != null && likesData.isNotEmpty)
          ? (likesData[0]['count'] as int? ?? 0)
          : 0;
      final enriched = Map<String, dynamic>.from(e);
      enriched['like_count'] = likeCount;
      enriched['is_liked_by_me'] = likedIds.contains(e['id']);
      return Goods.fromJson(enriched);
    }).toList();
  }

  // Read - single (with like count + is_liked_by_me)
  Future<Goods> getGoodsById(String id) async {
    final response = await _client
        .from('goods')
        .select('*, likes(count)')
        .eq('id', id)
        .single();

    final likesData = response['likes'] as List?;
    final likeCount = (likesData != null && likesData.isNotEmpty)
        ? (likesData[0]['count'] as int? ?? 0)
        : 0;

    // 현재 유저가 좋아요했는지 확인
    bool isLikedByMe = false;
    final user = _client.auth.currentUser;
    if (user != null) {
      final likeCheck = await _client
          .from('likes')
          .select('id')
          .eq('user_id', user.id)
          .eq('goods_id', id)
          .maybeSingle();
      isLikedByMe = likeCheck != null;
    }

    final enriched = Map<String, dynamic>.from(response);
    enriched['like_count'] = likeCount;
    enriched['is_liked_by_me'] = isLikedByMe;
    return Goods.fromJson(enriched);
  }

  // Update
  Future<Goods> updateGoods(String id, Map<String, dynamic> updates) async {
    try {
      final response = await _client
          .from('goods')
          .update(updates)
          .eq('id', id)
          .select()
          .single();
      return Goods.fromJson(response);
    } catch (e) {
      // purchase_place 컬럼이 없을 수 있음 — 제외 후 재시도
      if (updates.containsKey('purchase_place') &&
          e.toString().contains('purchase_place')) {
        final safeUpdates = Map<String, dynamic>.from(updates)
          ..remove('purchase_place');
        final response = await _client
            .from('goods')
            .update(safeUpdates)
            .eq('id', id)
            .select()
            .single();
        return Goods.fromJson(response);
      }
      rethrow;
    }
  }

  // Delete
  Future<void> deleteGoods(String id) async {
    await _client.from('goods').delete().eq('id', id);
  }

  // Monthly stats (goods count, categories, work tags)
  Future<MonthlyStats> getMonthlyStats(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final response = await _client
        .from('goods')
        .select('category, work_tag')
        .eq('user_id', _userId)
        .gte('purchased_at', startOfMonth.toIso8601String().split('T').first)
        .lte('purchased_at', endOfMonth.toIso8601String().split('T').first);

    final rows = response as List;
    final categories = <String>{};
    final workTags = <String>{};
    for (final row in rows) {
      if (row['category'] != null) categories.add(row['category'] as String);
      if (row['work_tag'] != null) workTags.add(row['work_tag'] as String);
    }

    return MonthlyStats(
      goodsCount: rows.length,
      categoryCount: categories.length,
      workTagCount: workTags.length,
    );
  }

  // Monthly spending
  Future<int> getMonthlySpending(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final response = await _client
        .from('goods')
        .select('price')
        .eq('user_id', _userId)
        .gte('purchased_at', startOfMonth.toIso8601String().split('T').first)
        .lte('purchased_at', endOfMonth.toIso8601String().split('T').first);

    int total = 0;
    for (final row in response as List) {
      total += (row['price'] as int?) ?? 0;
    }
    return total;
  }

  // Category spending for a month
  Future<Map<String, int>> getCategorySpending(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final response = await _client
        .from('goods')
        .select('category, price')
        .eq('user_id', _userId)
        .gte('purchased_at', startOfMonth.toIso8601String().split('T').first)
        .lte('purchased_at', endOfMonth.toIso8601String().split('T').first);

    final Map<String, int> result = {};
    for (final row in response as List) {
      final category = (row['category'] as String?) ?? 'other';
      final price = (row['price'] as int?) ?? 0;
      result[category] = (result[category] ?? 0) + price;
    }
    return result;
  }

  // Work tag spending for a month
  Future<Map<String, int>> getWorkTagSpending(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final response = await _client
        .from('goods')
        .select('work_tag, price')
        .eq('user_id', _userId)
        .gte('purchased_at', startOfMonth.toIso8601String().split('T').first)
        .lte('purchased_at', endOfMonth.toIso8601String().split('T').first);

    final Map<String, int> result = {};
    for (final row in response as List) {
      final workTag = row['work_tag'] as String?;
      if (workTag == null || workTag.isEmpty) continue;
      final price = (row['price'] as int?) ?? 0;
      result[workTag] = (result[workTag] ?? 0) + price;
    }
    return result;
  }

  // Monthly spending history for last N months (single query)
  Future<List<MonthlySpendingEntry>> getMonthlySpendingHistory(int months) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months + 1, 1);
    final end = DateTime(now.year, now.month + 1, 0);

    final response = await _client
        .from('goods')
        .select('price, purchased_at')
        .eq('user_id', _userId)
        .gte('purchased_at', start.toIso8601String().split('T').first)
        .lte('purchased_at', end.toIso8601String().split('T').first);

    // Group by year-month
    final Map<String, int> monthlyTotals = {};
    for (final row in response as List) {
      final price = (row['price'] as int?) ?? 0;
      final dateStr = row['purchased_at'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr);
      final key = '${date.year}-${date.month}';
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + price;
    }

    // Build entries for each month
    final entries = <MonthlySpendingEntry>[];
    for (int i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      final key = '${m.year}-${m.month}';
      entries.add(MonthlySpendingEntry(month: m, amount: monthlyTotals[key] ?? 0));
    }
    return entries;
  }

  // Upload photo to Supabase Storage (with Pro limit check)
  Future<String> uploadPhoto(Uint8List bytes, String fileName,
      {String bucket = 'goods-photos',
      SubscriptionService? subscriptionService}) async {
    // Check photo upload limit for free users
    if (subscriptionService != null) {
      final canUpload = await subscriptionService.checkCanUploadPhoto();
      if (!canUpload) {
        throw PhotoLimitExceededException();
      }
    }

    final ext = fileName.split('.').last;
    final path = '$_userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(bucket).uploadBinary(path, bytes);

    // Increment photo usage counter
    if (subscriptionService != null) {
      await subscriptionService.incrementPhotoUsage();
    }

    return _client.storage.from(bucket).getPublicUrl(path);
  }

  // Get unique work tags for the user
  Future<List<String>> getWorkTags() async {
    final response = await _client
        .from('goods')
        .select('work_tag')
        .eq('user_id', _userId)
        .not('work_tag', 'is', null);

    final tags = <String>{};
    for (final row in response as List) {
      if (row['work_tag'] != null) {
        tags.add(row['work_tag'] as String);
      }
    }
    return tags.toList()..sort();
  }

  // Get unique artist tags for the user
  Future<List<String>> getArtistTags() async {
    final response = await _client
        .from('goods')
        .select('artist_tag')
        .eq('user_id', _userId)
        .not('artist_tag', 'is', null);

    final tags = <String>{};
    for (final row in response as List) {
      if (row['artist_tag'] != null) {
        tags.add(row['artist_tag'] as String);
      }
    }
    return tags.toList()..sort();
  }
}

class PhotoLimitExceededException implements Exception {
  @override
  String toString() => '이번 달 사진 업로드 한도를 초과했어요';
}

class CatalogLimitExceededException implements Exception {
  @override
  String toString() => '무료 플랜의 도감 생성 한도를 초과했어요';
}

class CatalogItemLimitExceededException implements Exception {
  @override
  String toString() => '무료 플랜의 도감 아이템 한도를 초과했어요';
}
