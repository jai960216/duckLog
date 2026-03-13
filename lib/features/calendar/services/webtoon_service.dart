import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/supabase_config.dart';
import '../../../shared/utils/http_retry.dart';

final webtoonServiceProvider = Provider<WebtoonService>((ref) {
  return WebtoonService();
});

/// 한국 웹툰 데이터
class WebtoonData {
  final String id;
  final String title;
  final String provider; // NAVER, KAKAO, KAKAO_PAGE
  final List<String> updateDays; // MON, TUE, ...
  final String? thumbnailUrl;
  final List<String> authors;
  final bool isEnd;
  final bool isFree;
  final bool isUpdated;
  final String url;

  const WebtoonData({
    required this.id,
    required this.title,
    required this.provider,
    required this.updateDays,
    this.thumbnailUrl,
    required this.authors,
    required this.isEnd,
    required this.isFree,
    required this.isUpdated,
    required this.url,
  });

  String get displayTitle => title;

  String get updateDaysKorean {
    const dayMap = {
      'MON': '월요일',
      'TUE': '화요일',
      'WED': '수요일',
      'THU': '목요일',
      'FRI': '금요일',
      'SAT': '토요일',
      'SUN': '일요일',
    };
    return updateDays.map((d) => dayMap[d] ?? d).join(', ');
  }

  String get providerKorean {
    return switch (provider) {
      'NAVER' => '네이버',
      'KAKAO' => '카카오',
      'KAKAO_PAGE' => '카카오페이지',
      _ => provider,
    };
  }

  factory WebtoonData.fromJson(Map<String, dynamic> json) {
    final thumbnails = json['thumbnail'] as List<dynamic>? ?? [];
    return WebtoonData(
      id: json['id'] as String,
      title: json['title'] as String,
      provider: json['provider'] as String,
      updateDays: (json['updateDays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      thumbnailUrl: thumbnails.isNotEmpty ? thumbnails.first as String : null,
      authors: (json['authors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isEnd: json['isEnd'] as bool? ?? false,
      isFree: json['isFree'] as bool? ?? true,
      isUpdated: json['isUpdated'] as bool? ?? false,
      url: json['url'] as String? ?? '',
    );
  }
}

class WebtoonService {
  static const _httpTimeout = Duration(seconds: 30);

  bool get isConfigured => SupabaseConfig.isConfigured;

  String get _endpoint => '${SupabaseConfig.url}/functions/v1';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'apikey': SupabaseConfig.anonKey,
      };

  Future<http.Response> _getWithRetry(Uri uri) async {
    return HttpRetry.get(uri, headers: _headers, timeout: _httpTimeout);
  }

  /// 웹툰 검색
  Future<List<WebtoonData>> searchWebtoons(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('$_endpoint/webtoons').replace(
      queryParameters: {
        'keyword': query.trim(),
        'perPage': '30',
      },
    );

    final response = await _getWithRetry(uri);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final webtoons = json['webtoons'] as List<dynamic>? ?? [];
    return webtoons
        .map((w) => WebtoonData.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  /// 오늘 업데이트된 웹툰 (인기)
  Future<List<WebtoonData>> getTrendingWebtoons() async {
    final uri = Uri.parse('$_endpoint/webtoons').replace(
      queryParameters: {
        'isUpdated': 'true',
        'perPage': '50',
      },
    );

    final response = await _getWithRetry(uri);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final webtoons = json['webtoons'] as List<dynamic>? ?? [];
    return webtoons
        .map((w) => WebtoonData.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  /// 제목으로 검색 후 ID 매칭하여 웹툰 조회
  Future<WebtoonData?> findWebtoon(String title, String id) async {
    try {
      final results = await searchWebtoons(title);
      // ID 정확 매칭 우선
      for (final w in results) {
        if (w.id == id) return w;
      }
      // 제목 정확 매칭
      for (final w in results) {
        if (w.title == title) return w;
      }
      // 첫 번째 결과 fallback
      return results.firstOrNull;
    } catch (_) {}
    return null;
  }

  /// 특정 요일 웹툰
  Future<List<WebtoonData>> getWebtoonsByDay(String day) async {
    final uri = Uri.parse('$_endpoint/webtoons').replace(
      queryParameters: {
        'updateDay': day,
        'perPage': '100',
      },
    );

    final response = await _getWithRetry(uri);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final webtoons = json['webtoons'] as List<dynamic>? ?? [];
    return webtoons
        .map((w) => WebtoonData.fromJson(w as Map<String, dynamic>))
        .toList();
  }
}

// -- Riverpod Providers --

final trendingWebtoonProvider =
    FutureProvider.autoDispose<List<WebtoonData>>((ref) async {
  final service = ref.read(webtoonServiceProvider);
  if (!service.isConfigured) return [];
  return service.getTrendingWebtoons();
});

final webtoonSearchProvider =
    FutureProvider.autoDispose.family<List<WebtoonData>, String>(
  (ref, query) async {
    final service = ref.read(webtoonServiceProvider);
    if (!service.isConfigured || query.isEmpty) return [];
    return service.searchWebtoons(query);
  },
);

/// 웹툰 (title, externalId) → updateDays 조회 (캐시)
final webtoonUpdateDaysProvider =
    FutureProvider.autoDispose.family<List<String>, ({String title, String id})>(
  (ref, params) async {
    final service = ref.read(webtoonServiceProvider);
    if (!service.isConfigured) return [];
    final webtoon = await service.findWebtoon(params.title, params.id);
    return webtoon?.updateDays ?? [];
  },
);

final weekdayWebtoonProvider =
    FutureProvider.autoDispose.family<List<WebtoonData>, String>(
  (ref, day) async {
    final service = ref.read(webtoonServiceProvider);
    if (!service.isConfigured) return [];
    return service.getWebtoonsByDay(day);
  },
);
