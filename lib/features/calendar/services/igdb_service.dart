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

  const IgdbGame({
    required this.id,
    required this.name,
    this.coverUrl,
    this.releaseDate,
    this.releaseDateHuman,
    this.rating,
    this.hypes,
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

    return IgdbGame(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      coverUrl: coverUrl,
      releaseDate: releaseDate,
      releaseDateHuman: releaseDateHuman,
      rating: (json['rating'] as num?)?.toDouble(),
      hypes: json['hypes'] as int?,
    );
  }
}

class IgdbService {
  static const _tokenEndpoint = 'https://id.twitch.tv/oauth2/token';
  static const _apiEndpoint = 'https://api.igdb.com/v4';

  String? _accessToken;
  DateTime? _tokenExpiry;

  bool get isConfigured => IgdbConfig.isConfigured;

  /// Twitch OAuth2 토큰 발급 (client_credentials)
  Future<String> _getToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    final response = await http.post(
      Uri.parse(
        '$_tokenEndpoint?client_id=${IgdbConfig.clientId}'
        '&client_secret=${IgdbConfig.clientSecret}'
        '&grant_type=client_credentials',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Twitch 인증 실패: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = json['access_token'] as String;
    _tokenExpiry = DateTime.now()
        .add(Duration(seconds: json['expires_in'] as int));
    return _accessToken!;
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
    );

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
      'release_dates.human,release_dates.date,rating;'
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
      'release_dates.human,hypes;'
      ' where first_release_date > $nowUnix & hypes > 0;'
      ' sort hypes desc;'
      ' limit 20;',
    );

    return results
        .map((g) => IgdbGame.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  /// 출시 예정 게임
  Future<List<IgdbGame>> getUpcomingGames() async {
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final results = await _query(
      'games',
      'fields name,cover.image_id,first_release_date,'
      'release_dates.human,release_dates.date;'
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
