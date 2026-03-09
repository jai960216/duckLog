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
  final List<String> genres;
  final int? episodes; // 애니 총 에피소드
  final int? chapters; // 만화 총 챕터
  final int? volumes;  // 만화 총 권수
  final String? format; // TV, MOVIE, OVA, ONA, SPECIAL, MANGA, NOVEL, ONE_SHOT
  final int? meanScore; // 평균 점수 (100점 만점)
  final String? season; // SPRING, SUMMER, FALL, WINTER
  final int? seasonYear;
  final List<String> studios;
  final String? siteUrl;
  final String? description;

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
    this.genres = const [],
    this.episodes,
    this.chapters,
    this.volumes,
    this.format,
    this.meanScore,
    this.season,
    this.seasonYear,
    this.studios = const [],
    this.siteUrl,
    this.description,
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

  String get statusKorean => switch (status) {
    'RELEASING' => '방영/연재 중',
    'FINISHED' => '완결',
    'NOT_YET_RELEASED' => '출시 예정',
    'CANCELLED' => '취소',
    'HIATUS' => '휴재',
    _ => status ?? '알 수 없음',
  };

  String get formatKorean => switch (format) {
    'TV' => 'TV 애니메이션',
    'TV_SHORT' => 'TV 단편',
    'MOVIE' => '극장판',
    'SPECIAL' => '스페셜',
    'OVA' => 'OVA',
    'ONA' => 'ONA',
    'MUSIC' => '뮤직',
    'MANGA' => '만화',
    'NOVEL' => '소설 (라이트노벨)',
    'ONE_SHOT' => '단편',
    _ => format ?? '',
  };

  String? get seasonKorean {
    if (season == null || seasonYear == null) return null;
    final s = switch (season) {
      'WINTER' => '겨울',
      'SPRING' => '봄',
      'SUMMER' => '여름',
      'FALL' => '가을',
      _ => season!,
    };
    return '$seasonYear년 $s';
  }

  factory AnilistMedia.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>?;
    final coverImage = json['coverImage'] as Map<String, dynamic>?;
    final nextAiring = json['nextAiringEpisode'] as Map<String, dynamic>?;
    final synonyms = json['synonyms'] as List<dynamic>? ?? [];

    // synonyms에서 한글 제목 찾기
    String? korean;
    for (final s in synonyms) {
      if (s is! String) continue;
      if (_hangulRegex.hasMatch(s)) {
        korean = s;
        break;
      }
    }

    // 스튜디오 추출
    final studioEdges = json['studios']?['edges'] as List<dynamic>? ?? [];
    final studioNames = studioEdges
        .where((e) => (e as Map<String, dynamic>)['isMain'] == true)
        .map((e) => (e['node'] as Map<String, dynamic>)['name'] as String)
        .toList();
    if (studioNames.isEmpty) {
      studioNames.addAll(
        studioEdges
            .map((e) => (e['node'] as Map<String, dynamic>)['name'] as String)
            .take(3),
      );
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
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      episodes: json['episodes'] as int?,
      chapters: json['chapters'] as int?,
      volumes: json['volumes'] as int?,
      format: json['format'] as String?,
      meanScore: json['meanScore'] as int?,
      season: json['season'] as String?,
      seasonYear: json['seasonYear'] as int?,
      studios: studioNames,
      siteUrl: json['siteUrl'] as String?,
      description: json['description'] as String?,
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

  static const _httpTimeout = Duration(seconds: 15);
  static const _maxCacheSize = 500;

  /// 로컬 한국어 검색용 캐시 (트렌딩/방영중/이전 검색 결과 누적)
  static final Map<int, AnilistMedia> _mediaCache = {};

  static const _mediaFields = '''
      id
      title { romaji native english }
      synonyms
      coverImage { large }
      status
      format
      genres
      episodes
      chapters
      volumes
      meanScore
      season
      seasonYear
      siteUrl
      description(asHtml: false)
      studios { edges { isMain node { name } } }
      nextAiringEpisode { airingAt episode }
  ''';

  static final _searchQuery = '''
query (\$search: String, \$type: MediaType) {
  Page(perPage: 15) {
    media(search: \$search, type: \$type, sort: SEARCH_MATCH) {
      $_mediaFields
    }
  }
}
''';

  static final _trendingQuery = '''
query (\$type: MediaType) {
  Page(perPage: 50) {
    media(type: \$type, sort: TRENDING_DESC) {
      $_mediaFields
    }
  }
}
''';

  static final _currentlyAiringQuery = '''
query (\$page: Int, \$type: MediaType, \$status: MediaStatus) {
  Page(perPage: 50, page: \$page) {
    media(type: \$type, status: \$status, sort: POPULARITY_DESC) {
      $_mediaFields
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

  /// 캐시에 추가 (최대 크기 제한)
  void _addToCache(List<AnilistMedia> list) {
    for (final media in list) {
      _mediaCache[media.id] = media;
    }
    // LRU는 아니지만, 오래된 항목부터 제거
    if (_mediaCache.length > _maxCacheSize) {
      final keysToRemove =
          _mediaCache.keys.take(_mediaCache.length - _maxCacheSize).toList();
      for (final key in keysToRemove) {
        _mediaCache.remove(key);
      }
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
    final results = await _fetchMediaList(_trendingQuery, {'type': 'ANIME'});
    _addToCache(results);
    return results;
  }

  /// 현재 방영 중인 애니 (인기순)
  Future<List<AnilistMedia>> getCurrentlyAiring({int page = 1}) async {
    final results = await _fetchMediaList(
        _currentlyAiringQuery, {'page': page, 'type': 'ANIME', 'status': 'RELEASING'});
    _addToCache(results);
    return results;
  }

  /// 작품 검색 (AniList API + 한국어 캐시 폴백)
  Future<List<AnilistMedia>> searchAnime(String query) async {
    if (query.trim().isEmpty) return [];
    final trimmed = query.trim();
    final apiResults =
        await _fetchMediaList(_searchQuery, {'search': trimmed, 'type': 'ANIME'});
    _addToCache(apiResults);

    // API 결과가 충분하면 그대로 반환
    if (apiResults.isNotEmpty) return apiResults;

    // API 결과 없음 → 캐시에서 한국어/영어/romaji 부분매칭
    final cacheResults = _searchCacheKorean(trimmed);
    return cacheResults;
  }

  /// 트렌딩 만화 (인기순)
  Future<List<AnilistMedia>> getTrendingManga() async {
    final results = await _fetchMediaList(_trendingQuery, {'type': 'MANGA'});
    _addToCache(results);
    return results;
  }

  /// 현재 연재 중인 만화 (인기순)
  Future<List<AnilistMedia>> getPublishingManga({int page = 1}) async {
    final results = await _fetchMediaList(
        _currentlyAiringQuery, {'page': page, 'type': 'MANGA', 'status': 'RELEASING'});
    _addToCache(results);
    return results;
  }

  /// 만화 검색 (AniList API + 한국어 캐시 폴백)
  Future<List<AnilistMedia>> searchManga(String query) async {
    if (query.trim().isEmpty) return [];
    final trimmed = query.trim();
    final apiResults =
        await _fetchMediaList(_searchQuery, {'search': trimmed, 'type': 'MANGA'});
    _addToCache(apiResults);

    if (apiResults.isNotEmpty) return apiResults;

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
    ).timeout(_httpTimeout);

    if (response.statusCode != 200) {
      throw Exception('AniList API error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // GraphQL은 HTTP 200이어도 errors 필드에 에러를 담아 반환
    final errors = json['errors'] as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final firstMsg =
          (errors.first as Map<String, dynamic>)['message'] ?? 'Unknown error';
      throw Exception('AniList: $firstMsg');
    }

    return json;
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

final trendingMangaProvider =
    FutureProvider.autoDispose<List<AnilistMedia>>((ref) async {
  final service = ref.read(anilistServiceProvider);
  return service.getTrendingManga();
});

final publishingMangaProvider =
    FutureProvider.autoDispose<List<AnilistMedia>>((ref) async {
  final service = ref.read(anilistServiceProvider);
  return service.getPublishingManga();
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
