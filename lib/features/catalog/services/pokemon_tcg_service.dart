import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/tcg_types.dart';

// ── Service (TCGdex API) ──

class PokemonTcgService {
  static const _baseUrl = 'https://api.tcgdex.net/v2';
  static const _httpTimeout = Duration(seconds: 15);

  List<TcgSet>? _setsCache;

  Future<List<TcgSet>> getSets() async {
    if (_setsCache != null) return _setsCache!;

    final uri = Uri.parse('$_baseUrl/en/sets');
    final response = await http.get(uri).timeout(_httpTimeout);
    if (response.statusCode != 200) {
      throw Exception('Pokemon TCG API 오류: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    final sets = list.map((e) {
      final json = e as Map<String, dynamic>;
      final cardCount = json['cardCount'] as Map<String, dynamic>?;
      final logo = json['logo'] as String?;
      return TcgSet(
        id: json['id'] as String,
        name: json['name'] as String,
        imageUrl: logo != null ? '$logo.png' : null,
        totalCards: cardCount?['total'] as int? ?? 0,
        releaseDate: json['releaseDate'] as String?,
      );
    }).where((s) => s.imageUrl != null && s.totalCards > 0).toList();
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
    final uri = Uri.parse('$_baseUrl/en/cards?name=${Uri.encodeComponent(query)}');
    final response = await http.get(uri).timeout(_httpTimeout);
    if (response.statusCode != 200) {
      throw Exception('카드 검색 오류: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) {
      final json = e as Map<String, dynamic>;
      final baseImage = json['image'] as String?;
      return TcgCard(
        id: json['id'] as String,
        name: json['name'] as String,
        imageUrl: baseImage != null ? '$baseImage/high.webp' : null,
        localId: json['localId'] as String?,
      );
    }).where((c) => c.imageUrl != null).toList();
  }

  Future<List<TcgCard>> getCardsBySet(String setId) async {
    final uri = Uri.parse('$_baseUrl/en/sets/$setId');
    final response = await http.get(uri).timeout(_httpTimeout);
    if (response.statusCode != 200) {
      throw Exception('세트 정보를 불러올 수 없어요: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final cards = data['cards'] as List? ?? [];
    return cards.map((e) {
      final json = e as Map<String, dynamic>;
      final baseImage = json['image'] as String?;
      return TcgCard(
        id: json['id'] as String,
        name: json['name'] as String,
        imageUrl: baseImage != null ? '$baseImage/high.webp' : null,
        localId: json['localId'] as String?,
      );
    }).toList();
  }
}

// ── Providers ──

final pokemonTcgServiceProvider = Provider<PokemonTcgService>((ref) {
  return PokemonTcgService();
});

final pokemonSetsProvider =
    FutureProvider.autoDispose<List<TcgSet>>((ref) async {
  final service = ref.read(pokemonTcgServiceProvider);
  return await service.getSets();
});

final pokemonSetSearchProvider =
    FutureProvider.autoDispose.family<List<TcgSet>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final service = ref.read(pokemonTcgServiceProvider);
    return await service.searchSets(query);
  },
);

final pokemonCardSearchProvider =
    FutureProvider.autoDispose.family<List<TcgCard>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final service = ref.read(pokemonTcgServiceProvider);
    return await service.searchCards(query);
  },
);

final pokemonCardsProvider =
    FutureProvider.autoDispose.family<List<TcgCard>, String>(
  (ref, setId) async {
    final service = ref.read(pokemonTcgServiceProvider);
    return await service.getCardsBySet(setId);
  },
);
