import 'dart:async';
import 'package:http/http.dart' as http;

/// 5xx 서버 에러 시 지수 백오프로 재시도하는 HTTP 헬퍼
class HttpRetry {
  static const _maxRetries = 2;
  static const _baseDelay = Duration(seconds: 2);

  /// GET 요청 + 재시도 (5xx 에러 또는 타임아웃 시)
  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(uri, headers: headers).timeout(timeout);
        if (response.statusCode < 500 || attempt == _maxRetries) {
          return response;
        }
        await Future.delayed(_baseDelay * (attempt + 1));
      } on TimeoutException {
        if (attempt == _maxRetries) rethrow;
        await Future.delayed(_baseDelay * (attempt + 1));
      }
    }
    // unreachable
    throw TimeoutException('요청 시간이 초과되었어요.');
  }

  /// POST 요청 + 재시도 (5xx 에러 또는 타임아웃 시)
  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http
            .post(uri, headers: headers, body: body)
            .timeout(timeout);
        if (response.statusCode < 500 || attempt == _maxRetries) {
          return response;
        }
        await Future.delayed(_baseDelay * (attempt + 1));
      } on TimeoutException {
        if (attempt == _maxRetries) rethrow;
        await Future.delayed(_baseDelay * (attempt + 1));
      }
    }
    throw TimeoutException('요청 시간이 초과되었어요.');
  }
}
