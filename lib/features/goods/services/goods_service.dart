import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/utils/constants.dart';
import '../../auth/services/auth_service.dart';

final goodsServiceProvider = Provider<GoodsService>((ref) {
  return GoodsService(ref.read(supabaseClientProvider));
});

// Provider for goods list with filters
final goodsListProvider =
    FutureProvider.autoDispose.family<List<Goods>, GoodsFilter>(
  (ref, filter) async {
    try {
      final service = ref.read(goodsServiceProvider);
      return await service.getGoods(filter: filter);
    } catch (e) {
      return [];
    }
  },
);

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
    try {
      final parts = monthKey.split('-');
      final month = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      final service = ref.read(goodsServiceProvider);
      return await service.getMonthlyStats(month);
    } catch (e) {
      return const MonthlyStats(goodsCount: 0, categoryCount: 0, workTagCount: 0);
    }
  },
);

// Provider for monthly spending - key is "yyyy-MM" string for stable identity
final monthlySpendingProvider =
    FutureProvider.autoDispose.family<int, String>(
  (ref, monthKey) async {
    try {
      final parts = monthKey.split('-');
      final month = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      final service = ref.read(goodsServiceProvider);
      return await service.getMonthlySpending(month);
    } catch (e) {
      return 0;
    }
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
    String? memo,
    String visibility = 'public',
    String? catalogItemId,
  }) async {
    final data = {
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

    final response =
        await _client.from('goods').insert(data).select().single();
    return Goods.fromJson(response);
  }

  // Read - list with filters
  Future<List<Goods>> getGoods({GoodsFilter filter = const GoodsFilter()}) async {
    var query = _client.from('goods').select().eq('user_id', _userId);

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

    return (response as List).map((e) => Goods.fromJson(e)).toList();
  }

  // Read - single
  Future<Goods> getGoodsById(String id) async {
    final response =
        await _client.from('goods').select().eq('id', id).single();
    return Goods.fromJson(response);
  }

  // Update
  Future<Goods> updateGoods(String id, Map<String, dynamic> updates) async {
    final response = await _client
        .from('goods')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Goods.fromJson(response);
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

  // Upload photo to Supabase Storage
  Future<String> uploadPhoto(Uint8List bytes, String fileName,
      {String bucket = 'goods-photos'}) async {
    final ext = fileName.split('.').last;
    final path = '$_userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(bucket).uploadBinary(path, bytes);
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
