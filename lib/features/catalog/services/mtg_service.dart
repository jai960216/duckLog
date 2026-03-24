import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/http_retry.dart';
import '../models/tcg_types.dart';

// ── Service (Scryfall API) ──

class MtgService {
  static const _baseUrl = 'https://api.scryfall.com';
  static const _httpTimeout = Duration(seconds: 15);

  // Scryfall 권장: 50-100ms 딜레이
  DateTime? _lastRequest;

  Future<void> _throttle() async {
    if (_lastRequest != null) {
      final elapsed = DateTime.now().difference(_lastRequest!);
      if (elapsed.inMilliseconds < 100) {
        await Future.delayed(
            Duration(milliseconds: 100 - elapsed.inMilliseconds));
      }
    }
    _lastRequest = DateTime.now();
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'User-Agent': 'DuckLog/1.0',
      };

  List<TcgSet>? _setsCache;

  Future<List<TcgSet>> getSets() async {
    if (_setsCache != null) return _setsCache!;

    await _throttle();
    final uri = Uri.parse('$_baseUrl/sets');
    final response =
        await HttpRetry.get(uri, headers: _headers, timeout: _httpTimeout);
    if (response.statusCode != 200) {
      throw Exception('MTG API 오류: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    final sets = list.map((e) {
      final json = e as Map<String, dynamic>;
      return TcgSet(
        id: json['code'] as String,
        name: json['name'] as String,
        // icon_svg_uri는 SVG 형식이라 CachedNetworkImage에서 렌더 불가 → null 처리
        imageUrl: null,
        totalCards: json['card_count'] as int? ?? 0,
        releaseDate: json['released_at'] as String?,
      );
    }).where((s) => s.totalCards > 0).toList();
    // 최신 세트 먼저
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
    await _throttle();
    final uri = Uri.parse(
        '$_baseUrl/cards/search?q=${Uri.encodeComponent(query)}&unique=cards');
    final response =
        await HttpRetry.get(uri, headers: _headers, timeout: _httpTimeout);
    if (response.statusCode == 404) return []; // no results
    if (response.statusCode != 200) {
      throw Exception('카드 검색 오류: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list.map((e) => _parseCard(e as Map<String, dynamic>)).toList();
  }

  Future<List<TcgCard>> getCardsBySet(String setCode) async {
    await _throttle();
    final uri = Uri.parse(
        '$_baseUrl/cards/search?q=${Uri.encodeComponent("set:$setCode")}&order=set&unique=prints');
    final response =
        await HttpRetry.get(uri, headers: _headers, timeout: _httpTimeout);
    if (response.statusCode == 404) return [];
    if (response.statusCode != 200) {
      throw Exception('세트 정보를 불러올 수 없어요: ${response.statusCode}');
    }

    // Scryfall paginates (175 cards per page)
    final firstPage = jsonDecode(response.body) as Map<String, dynamic>;
    final cards = <TcgCard>[];
    cards.addAll((firstPage['data'] as List)
        .map((e) => _parseCard(e as Map<String, dynamic>)));

    // 추가 페이지 로드 (최대 3페이지 = ~525장)
    var nextPage = firstPage['next_page'] as String?;
    var pageCount = 1;
    while (nextPage != null && pageCount < 3) {
      await _throttle();
      final resp =
          await HttpRetry.get(Uri.parse(nextPage), headers: _headers, timeout: _httpTimeout);
      if (resp.statusCode != 200) break;
      final page = jsonDecode(resp.body) as Map<String, dynamic>;
      cards.addAll((page['data'] as List)
          .map((e) => _parseCard(e as Map<String, dynamic>)));
      nextPage = page['next_page'] as String?;
      pageCount++;
    }

    return cards;
  }

  TcgCard _parseCard(Map<String, dynamic> json) {
    // 양면 카드 처리
    String? imageUrl;
    final imageUris = json['image_uris'] as Map<String, dynamic>?;
    if (imageUris != null) {
      imageUrl = imageUris['normal'] as String? ?? imageUris['small'] as String?;
    } else {
      // 양면 카드: card_faces 에서 첫 번째 면 사용
      final faces = json['card_faces'] as List?;
      if (faces != null && faces.isNotEmpty) {
        final faceImages =
            (faces[0] as Map<String, dynamic>)['image_uris'] as Map<String, dynamic>?;
        imageUrl = faceImages?['normal'] as String? ?? faceImages?['small'] as String?;
      }
    }

    return TcgCard(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: imageUrl,
      localId: json['collector_number'] as String?,
    );
  }
}

// ── Providers ──

final mtgServiceProvider = Provider<MtgService>((ref) {
  return MtgService();
});

final mtgSetsProvider = FutureProvider.autoDispose<List<TcgSet>>((ref) async {
  final service = ref.read(mtgServiceProvider);
  return await service.getSets();
});

final mtgSetSearchProvider =
    FutureProvider.autoDispose.family<List<TcgSet>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final service = ref.read(mtgServiceProvider);
    return await service.searchSets(query);
  },
);

final mtgCardSearchProvider =
    FutureProvider.autoDispose.family<List<TcgCard>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final service = ref.read(mtgServiceProvider);
    return await service.searchCards(query);
  },
);

final mtgCardsProvider =
    FutureProvider.autoDispose.family<List<TcgCard>, String>(
  (ref, setId) async {
    final service = ref.read(mtgServiceProvider);
    return await service.getCardsBySet(setId);
  },
);
