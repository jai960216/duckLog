import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ── Models ──

class PokemonSet {
  final String id;
  final String name;
  final String? imageUrl;
  final int totalCards;
  final String? releaseDate;

  const PokemonSet({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.totalCards,
    this.releaseDate,
  });

  factory PokemonSet.fromJson(Map<String, dynamic> json) {
    final cardCount = json['cardCount'] as Map<String, dynamic>?;
    final logo = json['logo'] as String?;
    return PokemonSet(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: logo != null ? '$logo.png' : null,
      totalCards: cardCount?['total'] as int? ?? 0,
      releaseDate: json['releaseDate'] as String?,
    );
  }
}

class PokemonCard {
  final String id;
  final String name;
  final String? imageUrl;
  final String? localId;

  const PokemonCard({
    required this.id,
    required this.name,
    this.imageUrl,
    this.localId,
  });

  factory PokemonCard.fromJson(Map<String, dynamic> json) {
    // TCGdex image URL needs /high.webp suffix for full card image
    final baseImage = json['image'] as String?;
    return PokemonCard(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: baseImage != null ? '$baseImage/high.webp' : null,
      localId: json['localId'] as String?,
    );
  }
}

// ── Service (TCGdex API) ──

class PokemonTcgService {
  static const _baseUrl = 'https://api.tcgdex.net/v2';
  static const _httpTimeout = Duration(seconds: 15);

  /// 세트 목록 캐시 (전체 재요청 방지)
  List<PokemonSet>? _setsCache;

  /// 영문 세트 목록 (카드 데이터 포함)
  Future<List<PokemonSet>> getSets() async {
    if (_setsCache != null) return _setsCache!;

    final uri = Uri.parse('$_baseUrl/en/sets');
    final response = await http.get(uri).timeout(_httpTimeout);
    if (response.statusCode != 200) {
      throw Exception('Pokemon TCG API 오류: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    final sets = list
        .map((e) => PokemonSet.fromJson(e as Map<String, dynamic>))
        // 로고 없거나 카드 0장인 세트 제외
        .where((s) => s.imageUrl != null && s.totalCards > 0)
        .toList();
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

  /// 세트 이름으로 필터링 (캐시된 전체 목록에서 검색)
  Future<List<PokemonSet>> searchSets(String query) async {
    final all = await getSets();
    final lower = query.toLowerCase();
    return all.where((s) => s.name.toLowerCase().contains(lower)).toList();
  }

  /// 특정 세트의 카드 목록
  Future<List<PokemonCard>> getCardsBySet(String setId) async {
    final uri = Uri.parse('$_baseUrl/en/sets/$setId');
    final response = await http.get(uri).timeout(_httpTimeout);
    if (response.statusCode != 200) {
      throw Exception('세트 정보를 불러올 수 없어요: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final cards = data['cards'] as List? ?? [];
    return cards
        .map((e) => PokemonCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ── Providers ──

final pokemonTcgServiceProvider = Provider<PokemonTcgService>((ref) {
  return PokemonTcgService();
});

final pokemonSetsProvider =
    FutureProvider.autoDispose<List<PokemonSet>>((ref) async {
  final service = ref.read(pokemonTcgServiceProvider);
  return await service.getSets();
});

final pokemonSetSearchProvider =
    FutureProvider.autoDispose.family<List<PokemonSet>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final service = ref.read(pokemonTcgServiceProvider);
    return await service.searchSets(query);
  },
);

final pokemonCardsProvider =
    FutureProvider.autoDispose.family<List<PokemonCard>, String>(
  (ref, setId) async {
    final service = ref.read(pokemonTcgServiceProvider);
    return await service.getCardsBySet(setId);
  },
);
