import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ── Models ──

class AnilistWork {
  final int id;
  final String titleRomaji;
  final String? titleNative;
  final String? titleEnglish;
  final String? titleKorean;
  final String? coverImageUrl;
  final String type; // 'ANIME' or 'MANGA'

  const AnilistWork({
    required this.id,
    required this.titleRomaji,
    this.titleNative,
    this.titleEnglish,
    this.titleKorean,
    this.coverImageUrl,
    required this.type,
  });

  static final _hangulRegex = RegExp(r'[\uAC00-\uD7AF]');

  String get displayTitle =>
      titleKorean ?? titleEnglish ?? titleNative ?? titleRomaji;

  String? get subtitle {
    final main = displayTitle;
    if (main == titleKorean) return titleEnglish ?? titleNative ?? titleRomaji;
    if (main == titleEnglish) return titleNative ?? titleRomaji;
    if (main == titleNative) return titleRomaji;
    return null;
  }

  factory AnilistWork.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>?;
    final coverImage = json['coverImage'] as Map<String, dynamic>?;
    final synonyms = json['synonyms'] as List<dynamic>? ?? [];

    String? korean;
    for (final s in synonyms) {
      final str = s as String;
      if (_hangulRegex.hasMatch(str)) {
        korean = str;
        break;
      }
    }

    return AnilistWork(
      id: json['id'] as int,
      titleRomaji: title?['romaji'] as String? ?? '',
      titleNative: title?['native'] as String?,
      titleEnglish: title?['english'] as String?,
      titleKorean: korean,
      coverImageUrl: coverImage?['large'] as String?,
      type: json['type'] as String? ?? 'ANIME',
    );
  }
}

class AnilistCharacter {
  final int id;
  final String name;
  final String? nativeName;
  final String? koreanName;
  final String? imageUrl;
  final String role; // 'MAIN', 'SUPPORTING', 'BACKGROUND'

  static final _hangulRegex = RegExp(r'[\uAC00-\uD7AF]');

  const AnilistCharacter({
    required this.id,
    required this.name,
    this.nativeName,
    this.koreanName,
    this.imageUrl,
    required this.role,
  });

  String get displayName => koreanName ?? nativeName ?? name;

  String get roleLabel {
    switch (role) {
      case 'MAIN':
        return '주연';
      case 'SUPPORTING':
        return '조연';
      case 'BACKGROUND':
        return '단역';
      default:
        return role;
    }
  }

  factory AnilistCharacter.fromJson(Map<String, dynamic> json) {
    final edge = json;
    final node = edge['node'] as Map<String, dynamic>;
    final nameData = node['name'] as Map<String, dynamic>?;
    final image = node['image'] as Map<String, dynamic>?;
    final alternatives = nameData?['alternative'] as List<dynamic>? ?? [];

    // Extract Korean name from alternative names
    String? korean;
    for (final alt in alternatives) {
      final str = alt as String;
      if (_hangulRegex.hasMatch(str)) {
        korean = str;
        break;
      }
    }

    return AnilistCharacter(
      id: node['id'] as int,
      name: nameData?['full'] as String? ?? '',
      nativeName: nameData?['native'] as String?,
      koreanName: korean,
      imageUrl: image?['large'] as String?,
      role: edge['role'] as String? ?? 'SUPPORTING',
    );
  }
}

// ── Service ──

class AnilistFigureService {
  static const _endpoint = 'https://graphql.anilist.co';

  static const _searchQuery = r'''
query ($search: String, $type: MediaType) {
  Page(perPage: 20) {
    media(search: $search, type: $type, sort: SEARCH_MATCH) {
      id
      type
      title { romaji native english }
      synonyms
      coverImage { large }
    }
  }
}
''';

  static const _trendingQuery = r'''
query ($type: MediaType) {
  Page(perPage: 30) {
    media(type: $type, sort: TRENDING_DESC) {
      id
      type
      title { romaji native english }
      synonyms
      coverImage { large }
    }
  }
}
''';

  static const _charactersQuery = r'''
query ($mediaId: Int, $page: Int) {
  Media(id: $mediaId) {
    characters(sort: [ROLE, FAVOURITES_DESC], page: $page, perPage: 25) {
      pageInfo {
        total
        hasNextPage
      }
      edges {
        role
        node {
          id
          name { full native alternative }
          image { large }
        }
      }
    }
  }
}
''';

  Future<List<AnilistWork>> searchWorks(String query,
      {String type = 'ANIME'}) async {
    if (query.trim().isEmpty) return [];
    final json = await _post(_searchQuery, {
      'search': query.trim(),
      'type': type,
    });
    final mediaList =
        json['data']?['Page']?['media'] as List<dynamic>? ?? [];
    return mediaList
        .map((m) => AnilistWork.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<AnilistWork>> getTrending({String type = 'ANIME'}) async {
    final json = await _post(_trendingQuery, {'type': type});
    final mediaList =
        json['data']?['Page']?['media'] as List<dynamic>? ?? [];
    return mediaList
        .map((m) => AnilistWork.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<AnilistCharacter>> getCharacters(int mediaId,
      {int page = 1}) async {
    final json = await _post(_charactersQuery, {
      'mediaId': mediaId,
      'page': page,
    });
    final edges = json['data']?['Media']?['characters']?['edges']
            as List<dynamic>? ??
        [];
    return edges
        .map((e) => AnilistCharacter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> hasMoreCharacters(int mediaId, int page) async {
    final json = await _post(_charactersQuery, {
      'mediaId': mediaId,
      'page': page,
    });
    return json['data']?['Media']?['characters']?['pageInfo']
            ?['hasNextPage'] as bool? ??
        false;
  }

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
      throw Exception('AniList API 오류: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

// ── Providers ──

final anilistFigureServiceProvider = Provider<AnilistFigureService>((ref) {
  return AnilistFigureService();
});

final anilistWorkSearchProvider =
    FutureProvider.autoDispose.family<List<AnilistWork>, ({String query, String type})>(
  (ref, params) async {
    final service = ref.read(anilistFigureServiceProvider);
    if (params.query.isEmpty) {
      return service.getTrending(type: params.type);
    }
    return service.searchWorks(params.query, type: params.type);
  },
);

final anilistCharactersProvider =
    FutureProvider.autoDispose.family<List<AnilistCharacter>, int>(
  (ref, mediaId) async {
    final service = ref.read(anilistFigureServiceProvider);
    // Fetch first 3 pages (up to 75 characters)
    final allChars = <AnilistCharacter>[];
    for (int page = 1; page <= 3; page++) {
      final chars = await service.getCharacters(mediaId, page: page);
      allChars.addAll(chars);
      if (chars.length < 25) break;
    }
    return allChars;
  },
);
