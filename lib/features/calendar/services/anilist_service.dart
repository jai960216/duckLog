import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final anilistServiceProvider = Provider<AnilistService>((ref) {
  return AnilistService();
});

/// AniList API 검색 결과
class AnilistMedia {
  final int id;
  final String titleRomaji;
  final String? titleNative;
  final String? titleEnglish;
  final String? titleKorean; // synonyms에서 추출한 한국어 제목
  final String? coverImageUrl;
  final String? status; // RELEASING, FINISHED, NOT_YET_RELEASED, CANCELLED
  final int? nextAiringEpisode;
  final int? nextAiringAt; // Unix timestamp (seconds)

  const AnilistMedia({
    required this.id,
    required this.titleRomaji,
    this.titleNative,
    this.titleEnglish,
    this.titleKorean,
    this.coverImageUrl,
    this.status,
    this.nextAiringEpisode,
    this.nextAiringAt,
  });

  /// 한글 포함 여부 판별
  static final _hangulRegex = RegExp(r'[\uAC00-\uD7AF]');

  /// 메인 제목: 한국어 > 영어 > 원어 > romaji
  String get displayTitle =>
      titleKorean ?? titleEnglish ?? titleNative ?? titleRomaji;

  /// 서브 제목: 메인과 다른 언어를 보여줌
  String? get subtitle {
    final main = displayTitle;
    // 한국어가 메인이면 영어 또는 원어 표시
    if (main == titleKorean) return titleEnglish ?? titleNative ?? titleRomaji;
    // 영어가 메인이면 원어 표시
    if (main == titleEnglish) return titleNative ?? titleRomaji;
    // 원어가 메인이면 romaji 표시
    if (main == titleNative) return titleRomaji;
    return null;
  }

  factory AnilistMedia.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>?;
    final coverImage = json['coverImage'] as Map<String, dynamic>?;
    final nextAiring = json['nextAiringEpisode'] as Map<String, dynamic>?;
    final synonyms = json['synonyms'] as List<dynamic>? ?? [];

    // synonyms에서 한글 제목 찾기
    String? korean;
    for (final s in synonyms) {
      final str = s as String;
      if (_hangulRegex.hasMatch(str)) {
        korean = str;
        break;
      }
    }

    return AnilistMedia(
      id: json['id'] as int,
      titleRomaji: title?['romaji'] as String? ?? '',
      titleNative: title?['native'] as String?,
      titleEnglish: title?['english'] as String?,
      titleKorean: korean,
      coverImageUrl: coverImage?['large'] as String?,
      status: json['status'] as String?,
      nextAiringEpisode: nextAiring?['episode'] as int?,
      nextAiringAt: nextAiring?['airingAt'] as int?,
    );
  }
}

/// 방영 스케줄 항목
class AnilistAiringSchedule {
  final int airingAt; // Unix timestamp (seconds)
  final int episode;

  const AnilistAiringSchedule({
    required this.airingAt,
    required this.episode,
  });

  DateTime get airingDateTime =>
      DateTime.fromMillisecondsSinceEpoch(airingAt * 1000);

  factory AnilistAiringSchedule.fromJson(Map<String, dynamic> json) {
    return AnilistAiringSchedule(
      airingAt: json['airingAt'] as int,
      episode: json['episode'] as int,
    );
  }
}

class AnilistService {
  static const _endpoint = 'https://graphql.anilist.co';

  /// 로컬 한국어 검색용 캐시 (트렌딩/방영중/이전 검색 결과 누적)
  static final Map<int, AnilistMedia> _mediaCache = {};

  static final _hangulRegex = RegExp(r'[\uAC00-\uD7AF]');

  static const _searchQuery = r'''
query ($search: String) {
  Page(perPage: 15) {
    media(search: $search, type: ANIME, sort: SEARCH_MATCH) {
      id
      title { romaji native english }
      synonyms
      coverImage { large }
      status
      nextAiringEpisode { airingAt episode }
    }
  }
}
''';

  static const _trendingQuery = r'''
query {
  Page(perPage: 50) {
    media(type: ANIME, sort: TRENDING_DESC) {
      id
      title { romaji native english }
      synonyms
      coverImage { large }
      status
      nextAiringEpisode { airingAt episode }
    }
  }
}
''';

  static const _currentlyAiringQuery = r'''
query ($page: Int) {
  Page(perPage: 50, page: $page) {
    media(type: ANIME, status: RELEASING, sort: POPULARITY_DESC) {
      id
      title { romaji native english }
      synonyms
      coverImage { large }
      status
      nextAiringEpisode { airingAt episode }
    }
  }
}
''';

  static const _airingScheduleQuery = r'''
query ($mediaId: Int) {
  Media(id: $mediaId) {
    airingSchedule(notYetAired: true, perPage: 25) {
      nodes { airingAt episode }
    }
  }
}
''';

  /// 캐시에 추가
  void _addToCache(List<AnilistMedia> list) {
    for (final media in list) {
      _mediaCache[media.id] = media;
    }
  }

  /// 캐시에서 한국어 부분매칭 검색
  List<AnilistMedia> _searchCacheKorean(String query) {
    final q = query.toLowerCase();
    return _mediaCache.values.where((media) {
      final korean = media.titleKorean?.toLowerCase() ?? '';
      final english = media.titleEnglish?.toLowerCase() ?? '';
      final native_ = media.titleNative?.toLowerCase() ?? '';
      final romaji = media.titleRomaji.toLowerCase();
      return korean.contains(q) ||
          english.contains(q) ||
          native_.contains(q) ||
          romaji.contains(q);
    }).toList();
  }

  /// 트렌딩 애니 (인기순)
  Future<List<AnilistMedia>> getTrending() async {
    final results = await _fetchMediaList(_trendingQuery, {});
    _addToCache(results);
    return results;
  }

  /// 현재 방영 중인 애니 (인기순)
  Future<List<AnilistMedia>> getCurrentlyAiring({int page = 1}) async {
    final results =
        await _fetchMediaList(_currentlyAiringQuery, {'page': page});
    _addToCache(results);
    return results;
  }

  /// 작품 검색 (AniList API + 한국어 캐시 폴백)
  Future<List<AnilistMedia>> searchAnime(String query) async {
    if (query.trim().isEmpty) return [];
    final trimmed = query.trim();
    final apiResults =
        await _fetchMediaList(_searchQuery, {'search': trimmed});
    _addToCache(apiResults);

    // API 결과가 충분하면 그대로 반환
    if (apiResults.isNotEmpty) return apiResults;

    // API 결과 없음 → 캐시에서 한국어/영어/romaji 부분매칭
    final cacheResults = _searchCacheKorean(trimmed);
    return cacheResults;
  }

  /// 방영 스케줄 조회 (아직 방영 안 된 에피소드만)
  Future<List<AnilistAiringSchedule>> getAiringSchedule(int mediaId) async {
    final response = await _post(_airingScheduleQuery, {'mediaId': mediaId});
    final nodes = response['data']?['Media']?['airingSchedule']?['nodes']
            as List<dynamic>? ??
        [];
    return nodes
        .map((n) =>
            AnilistAiringSchedule.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  // -- Internal helpers --

  Future<Map<String, dynamic>> _post(
      String query, Map<String, dynamic> variables) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'query': query, 'variables': variables}),
    );

    if (response.statusCode != 200) {
      throw Exception('AniList API error: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<AnilistMedia>> _fetchMediaList(
      String query, Map<String, dynamic> variables) async {
    final json = await _post(query, variables);
    final mediaList =
        json['data']?['Page']?['media'] as List<dynamic>? ?? [];
    return mediaList
        .map((m) => AnilistMedia.fromJson(m as Map<String, dynamic>))
        .toList();
  }
}

// -- Riverpod Providers --

final trendingAnimeProvider =
    FutureProvider.autoDispose<List<AnilistMedia>>((ref) async {
  final service = ref.read(anilistServiceProvider);
  return service.getTrending();
});

final airingAnimeProvider =
    FutureProvider.autoDispose<List<AnilistMedia>>((ref) async {
  final service = ref.read(anilistServiceProvider);
  return service.getCurrentlyAiring();
});

/// 특정 작품의 방영 스케줄 (externalId = AniList media ID)
final workAiringScheduleProvider =
    FutureProvider.autoDispose.family<List<AnilistAiringSchedule>, String>(
  (ref, externalId) async {
    final mediaId = int.tryParse(externalId);
    if (mediaId == null) return [];
    final service = ref.read(anilistServiceProvider);
    return service.getAiringSchedule(mediaId);
  },
);
