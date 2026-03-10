import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/tcg_types.dart';

// ── Service (DigimonCard.io API) ──

class DigimonTcgService {
  static const _baseUrl = 'https://digimoncard.io/api-public';
  static const _httpTimeout = Duration(seconds: 15);

  List<TcgSet>? _setsCache;
  List<Map<String, dynamic>>? _allCardsCache;

  /// 전체 카드를 한 번 로드하여 캐시
  Future<List<Map<String, dynamic>>> _getAllCards() async {
    if (_allCardsCache != null) return _allCardsCache!;

    final uri = Uri.parse(
        '$_baseUrl/getAllCards.php?series=Digimon Card Game&sort=name&sortdirection=asc');
    final response =
        await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Digimon API 오류: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    _allCardsCache =
        list.map((e) => e as Map<String, dynamic>).toList();
    return _allCardsCache!;
  }

  Future<List<TcgSet>> getSets() async {
    if (_setsCache != null) return _setsCache!;

    final allCards = await _getAllCards();

    // 팩별 카드 수 집계 + 대표 이미지
    final packCounts = <String, int>{};
    final packImages = <String, String>{};
    for (final json in allCards) {
      final pack = json['cardnumber'] as String? ?? '';
      final dash = pack.indexOf('-');
      if (dash > 0) {
        final code = pack.substring(0, dash);
        packCounts[code] = (packCounts[code] ?? 0) + 1;
        // 첫 번째 카드 이미지를 세트 커버로 사용
        if (!packImages.containsKey(code)) {
          final img = json['image_url'] as String?;
          if (img != null) packImages[code] = img;
        }
      }
    }

    final sets = packCounts.entries
        .map((e) => TcgSet(
              id: e.key,
              name: _packCodeToName(e.key),
              imageUrl: packImages[e.key],
              totalCards: e.value,
            ))
        .toList();
    sets.sort((a, b) => b.id.compareTo(a.id));
    _setsCache = sets;
    return sets;
  }

  String _packCodeToName(String code) {
    if (code.startsWith('BT')) return 'Booster $code';
    if (code.startsWith('ST')) return 'Starter Deck $code';
    if (code.startsWith('EX')) return 'Extra Booster $code';
    if (code.startsWith('RB')) return 'Reboot Booster $code';
    if (code.startsWith('P')) return 'Promo $code';
    return code;
  }

  Future<List<TcgSet>> searchSets(String query) async {
    final all = await getSets();
    final lower = query.toLowerCase();
    return all
        .where((s) =>
            s.name.toLowerCase().contains(lower) ||
            s.id.toLowerCase().contains(lower))
        .toList();
  }

  Future<List<TcgCard>> searchCards(String query) async {
    final uri = Uri.parse(
        '$_baseUrl/search.php?n=${Uri.encodeComponent(query)}&series=Digimon Card Game');
    final response = await http.get(uri).timeout(_httpTimeout);
    if (response.statusCode == 400) return [];
    if (response.statusCode != 200) {
      throw Exception('카드 검색 오류: ${response.statusCode}');
    }
    final body = response.body.trim();
    if (body.isEmpty || body == '[]') return [];
    final list = jsonDecode(body) as List;
    return list
        .map((e) => _parseCard(e as Map<String, dynamic>))
        .where((c) => c.imageUrl != null)
        .toList();
  }

  /// 세트별 카드: 캐시된 전체 카드에서 팩 코드로 필터링
  Future<List<TcgCard>> getCardsBySet(String packCode) async {
    final allCards = await _getAllCards();
    final cards = allCards
        .where((json) {
          final cn = json['cardnumber'] as String? ?? '';
          return cn.startsWith('$packCode-');
        })
        .map((e) => _parseCard(e))
        .where((c) => c.imageUrl != null)
        .toList();
    cards.sort((a, b) => (a.localId ?? '').compareTo(b.localId ?? ''));
    return cards;
  }

  TcgCard _parseCard(Map<String, dynamic> json) {
    final imageUrl = json['image_url'] as String?;
    final cardNumber = json['cardnumber'] as String?;
    return TcgCard(
      id: cardNumber ?? json['name'] as String,
      name: json['name'] as String,
      imageUrl: imageUrl,
      localId: cardNumber,
    );
  }
}

// ── Providers ──

final digimonTcgServiceProvider = Provider<DigimonTcgService>((ref) {
  return DigimonTcgService();
});

final digimonSetsProvider =
    FutureProvider.autoDispose<List<TcgSet>>((ref) async {
  final service = ref.read(digimonTcgServiceProvider);
  return await service.getSets();
});

final digimonSetSearchProvider =
    FutureProvider.autoDispose.family<List<TcgSet>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final service = ref.read(digimonTcgServiceProvider);
    return await service.searchSets(query);
  },
);

final digimonCardSearchProvider =
    FutureProvider.autoDispose.family<List<TcgCard>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final service = ref.read(digimonTcgServiceProvider);
    return await service.searchCards(query);
  },
);

final digimonCardsProvider =
    FutureProvider.autoDispose.family<List<TcgCard>, String>(
  (ref, setId) async {
    final service = ref.read(digimonTcgServiceProvider);
    return await service.getCardsBySet(setId);
  },
);
