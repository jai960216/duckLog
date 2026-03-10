class GoogleAuthConfig {
  GoogleAuthConfig._();

  // ⚠️ 프로덕션 배포 전에 반드시 환경변수 또는 --dart-define으로 교체할 것!
  // 현재 값은 개발/테스트 전용 — git에 커밋된 시크릿은 rotate 필요
  //
  // Google Cloud Console에서 발급:
  // https://console.cloud.google.com/apis/credentials
  // 1. OAuth 2.0 클라이언트 ID → 웹 애플리케이션 → Client ID 복사
  // 2. 아래에 붙여넣기 (또는 --dart-define 사용)
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '***GOOGLE_CLIENT_ID_REMOVED***',
  );

  static bool get isConfigured =>
      webClientId.isNotEmpty &&
      webClientId != 'YOUR_GOOGLE_WEB_CLIENT_ID';
}
