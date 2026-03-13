import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/http_retry.dart';
import '../models/tcg_types.dart';

// ── Service (YGOProDeck API v7) ──

class YugiohService {
  static const _baseUrl = 'https://db.ygoprodeck.com/api/v7';
  static const _httpTimeout = Duration(seconds: 15);

  List<TcgSet>? _setsCache;

  Future<List<TcgSet>> getSets() async {
    if (_setsCache != null) return _setsCache!;

    final uri = Uri.parse('$_baseUrl/cardsets.php');
    final response = await HttpRetry.get(uri, timeout: _httpTimeout);
    if (response.statusCode != 200) {
      throw Exception('Yu-Gi-Oh API 오류: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    final sets = list.map((e) {
      final json = e as Map<String, dynamic>;
      return TcgSet(
        id: json['set_name'] as String,
        name: json['set_name'] as String,
        imageUrl: null, // YGOProDeck 세트에는 로고 이미지 없음
        totalCards: json['num_of_cards'] as int? ?? 0,
        releaseDate: json['tcg_date'] as String?,
      );
    }).where((s) => s.totalCards > 0).toList();
    sets.sort((a, b) {
      if (a.releaseDate == null && b.releaseDate == null) return 0;
      if (a.releaseDate == null) return 1;
      if (b.releaseDate == null) return -1;
      return b.releaseDate!.compareTo(a.releaseDate!);
    });
    _setsCache = sets;
    return sets;
  }

  Future<List<TcgSet>> searchSets(String query) async {
    final all = await getSets();
    final lower = query.toLowerCase();
    return all.where((s) => s.name.toLowerCase().contains(lower)).toList();
  }

  Future<List<TcgCard>> searchCards(String query) async {
    final uri = Uri.parse('$_baseUrl/cardinfo.php?fname=${Uri.encodeComponent(query)}');
    final response = await HttpRetry.get(uri, timeout: _httpTimeout);
    if (response.statusCode == 400) return []; // no results
    if (response.statusCode != 200) {
      throw Exception('카드 검색 오류: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list.map((e) {
      final json = e as Map<String, dynamic>;
      final images = json['card_images'] as List?;
      final imageUrl = images != null && images.isNotEmpty
          ? images[0]['image_url_small'] as String?
          : null;
      return TcgCard(
        id: (json['id'] as num).toString(),
        name: json['name'] as String,
        imageUrl: imageUrl,
      );
    }).where((c) => c.imageUrl != null).toList();
  }

  Future<List<TcgCard>> getCardsBySet(String setName) async {
    final uri = Uri.parse(
        '$_baseUrl/cardinfo.php?cardset=${Uri.encodeComponent(setName)}');
    final response = await HttpRetry.get(uri, timeout: _httpTimeout);
    if (response.statusCode == 400) return [];
    if (response.statusCode != 200) {
      throw Exception('세트 정보를 불러올 수 없어요: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list.map((e) {
      final json = e as Map<String, dynamic>;
      final images = json['card_images'] as List?;
      final imageUrl = images != null && images.isNotEmpty
          ? images[0]['image_url_small'] as String?
          : null;
      // 세트 내 카드 번호 추출
      final sets = json['card_sets'] as List?;
      String? setCode;
      if (sets != null) {
        for (final s in sets) {
          if ((s as Map<String, dynamic>)['set_name'] == setName) {
            setCode = s['set_code'] as String?;
            break;
          }
        }
      }
      return TcgCard(
        id: (json['id'] as num).toString(),
        name: json['name'] as String,
        imageUrl: imageUrl,
        localId: setCode,
      );
    }).where((c) => c.imageUrl != null).toList();
  }
}

// ── Providers ──

final yugiohServiceProvider = Provider<YugiohService>((ref) {
  return YugiohService();
});

final yugiohSetsProvider =
    FutureProvider.autoDispose<List<TcgSet>>((ref) async {
  final service = ref.read(yugiohServiceProvider);
  return await service.getSets();
});

final yugiohSetSearchProvider =
    FutureProvider.autoDispose.family<List<TcgSet>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final service = ref.read(yugiohServiceProvider);
    return await service.searchSets(query);
  },
);

final yugiohCardSearchProvider =
    FutureProvider.autoDispose.family<List<TcgCard>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final service = ref.read(yugiohServiceProvider);
    return await service.searchCards(query);
  },
);

final yugiohCardsProvider =
    FutureProvider.autoDispose.family<List<TcgCard>, String>(
  (ref, setId) async {
    final service = ref.read(yugiohServiceProvider);
    return await service.getCardsBySet(setId);
  },
);
