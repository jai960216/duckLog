import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/igdb_config.dart';

final igdbServiceProvider = Provider<IgdbService>((ref) {
  return IgdbService();
});

/// IGDB 게임 검색 결과
class IgdbGame {
  final int id;
  final String name;
  final String? coverUrl;
  final DateTime? releaseDate;
  final String? releaseDateHuman; // "Mar 28, 2026" 등
  final double? rating;
  final int? hypes; // 출시 전 관심도
  final List<String> genres;
  final List<String> platforms;
  final String? summary;
  final String? url; // IGDB 페이지 URL

  const IgdbGame({
    required this.id,
    required this.name,
    this.coverUrl,
    this.releaseDate,
    this.releaseDateHuman,
    this.rating,
    this.hypes,
    this.genres = const [],
    this.platforms = const [],
    this.summary,
    this.url,
  });

  factory IgdbGame.fromJson(Map<String, dynamic> json) {
    // 커버 이미지: image_id → URL 변환
    String? coverUrl;
    final cover = json['cover'] as Map<String, dynamic>?;
    if (cover != null && cover['image_id'] != null) {
      coverUrl =
          'https://images.igdb.com/igdb/image/upload/t_cover_big/${cover['image_id']}.jpg';
    }

    // 출시일
    DateTime? releaseDate;
    final firstRelease = json['first_release_date'] as int?;
    if (firstRelease != null) {
      releaseDate =
          DateTime.fromMillisecondsSinceEpoch(firstRelease * 1000);
    }

    // 출시일 텍스트 (release_dates 배열의 첫 항목)
    String? releaseDateHuman;
    final releaseDates = json['release_dates'] as List<dynamic>?;
    if (releaseDates != null && releaseDates.isNotEmpty) {
      releaseDateHuman =
          (releaseDates.first as Map<String, dynamic>)['human'] as String?;
    }

    // 장르
    final genreList = json['genres'] as List<dynamic>? ?? [];
    final genres = genreList
        .map((g) => (g as Map<String, dynamic>)['name'] as String)
        .toList();

    // 플랫폼
    final platformList = json['platforms'] as List<dynamic>? ?? [];
    final platforms = platformList
        .map((p) => (p as Map<String, dynamic>)['name'] as String)
        .toList();

    return IgdbGame(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      coverUrl: coverUrl,
      releaseDate: releaseDate,
      releaseDateHuman: releaseDateHuman,
      rating: (json['rating'] as num?)?.toDouble(),
      hypes: json['hypes'] as int?,
      genres: genres,
      platforms: platforms,
      summary: json['summary'] as String?,
      url: json['url'] as String?,
    );
  }
}

class IgdbCharacter {
  final int id;
  final String name;
  final String? imageUrl;

  const IgdbCharacter({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  factory IgdbCharacter.fromJson(Map<String, dynamic> json) {
    String? imageUrl;
    final mugShot = json['mug_shot'] as Map<String, dynamic>?;
    if (mugShot != null && mugShot['image_id'] != null) {
      imageUrl =
          'https://images.igdb.com/igdb/image/upload/t_thumb/${mugShot['image_id']}.jpg';
    }
    return IgdbCharacter(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      imageUrl: imageUrl,
    );
  }
}

class IgdbService {
  static const _tokenEndpoint = 'https://id.twitch.tv/oauth2/token';
  static const _apiEndpoint = 'https://api.igdb.com/v4';
  static const _httpTimeout = Duration(seconds: 15);
  static const _tokenMargin = Duration(seconds: 60);

  String? _accessToken;
  DateTime? _tokenExpiry;
  Completer<String>? _tokenCompleter; // 동시 요청 방지

  bool get isConfigured => IgdbConfig.isConfigured;

  /// Twitch OAuth2 토큰 발급 (client_credentials)
  /// 동시에 여러 요청이 들어와도 한 번만 토큰 발급
  Future<String> _getToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    // 이미 토큰 발급 진행 중이면 결과 대기
    if (_tokenCompleter != null) {
      return _tokenCompleter!.future;
    }

    _tokenCompleter = Completer<String>();
    try {
      final response = await http.post(
        Uri.parse(
          '$_tokenEndpoint?client_id=${IgdbConfig.clientId}'
          '&client_secret=${IgdbConfig.clientSecret}'
          '&grant_type=client_credentials',
        ),
      ).timeout(_httpTimeout);

      if (response.statusCode != 200) {
        throw Exception('Twitch 인증 실패: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = json['access_token'] as String;
      // 만료 전 마진을 두어 네트워크 지연으로 인한 만료 방지
      _tokenExpiry = DateTime.now()
          .add(Duration(seconds: json['expires_in'] as int))
          .subtract(_tokenMargin);
      _tokenCompleter!.complete(_accessToken!);
      return _accessToken!;
    } catch (e) {
      _accessToken = null;
      _tokenExpiry = null;
      _tokenCompleter!.completeError(e);
      rethrow;
    } finally {
      _tokenCompleter = null;
    }
  }

  /// IGDB API 호출
  Future<List<dynamic>> _query(String endpoint, String body) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_apiEndpoint/$endpoint'),
      headers: {
        'Client-ID': IgdbConfig.clientId,
        'Authorization': 'Bearer $token',
      },
      body: body,
    ).timeout(_httpTimeout);

    if (response.statusCode != 200) {
      throw Exception('IGDB API error: ${response.statusCode}');
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  /// 게임 검색
  Future<List<IgdbGame>> searchGames(String query) async {
    if (query.trim().isEmpty) return [];

    final escaped = query.trim().replaceAll('"', '\\"');
    final results = await _query(
      'games',
      'search "$escaped";'
      ' fields name,cover.image_id,first_release_date,'
      'release_dates.human,release_dates.date,rating,'
      'genres.name,platforms.name,summary,url;'
      ' limit 10;',
    );

    return results
        .map((g) => IgdbGame.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  /// 출시 예정 중 관심도 높은 게임 (hypes 기준)
  Future<List<IgdbGame>> getPopularGames() async {
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final results = await _query(
      'games',
      'fields name,cover.image_id,first_release_date,'
      'release_dates.human,hypes,'
      'genres.name,platforms.name,summary,url;'
      ' where first_release_date > $nowUnix & hypes > 0;'
      ' sort hypes desc;'
      ' limit 20;',
    );

    return results
        .map((g) => IgdbGame.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  /// 게임 캐릭터 조회
  Future<List<IgdbCharacter>> getCharacters(int gameId) async {
    final results = await _query(
      'characters',
      'fields name,mug_shot.image_id;'
      ' where games = [$gameId];'
      ' limit 50;',
    );
    return results
        .map((c) => IgdbCharacter.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// 출시 예정 게임
  Future<List<IgdbGame>> getUpcomingGames() async {
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final results = await _query(
      'games',
      'fields name,cover.image_id,first_release_date,'
      'release_dates.human,release_dates.date,'
      'genres.name,platforms.name,summary,url;'
      ' where first_release_date > $nowUnix & hypes > 5;'
      ' sort first_release_date asc;'
      ' limit 20;',
    );

    return results
        .map((g) => IgdbGame.fromJson(g as Map<String, dynamic>))
        .toList();
  }
}

// -- Riverpod Providers --

final igdbGameSearchProvider =
    FutureProvider.autoDispose.family<List<IgdbGame>, String>(
  (ref, query) async {
    final service = ref.read(igdbServiceProvider);
    if (!service.isConfigured) return [];
    if (query.isEmpty) return service.getPopularGames();
    return service.searchGames(query);
  },
);

final igdbCharactersProvider =
    FutureProvider.autoDispose.family<List<IgdbCharacter>, int>(
  (ref, gameId) async {
    final service = ref.read(igdbServiceProvider);
    return service.getCharacters(gameId);
  },
);

final popularGamesProvider =
    FutureProvider.autoDispose<List<IgdbGame>>((ref) async {
  final service = ref.read(igdbServiceProvider);
  if (!service.isConfigured) return [];
  return service.getPopularGames();
});

final upcomingGamesProvider =
    FutureProvider.autoDispose<List<IgdbGame>>((ref) async {
  final service = ref.read(igdbServiceProvider);
  if (!service.isConfigured) return [];
  return service.getUpcomingGames();
});
