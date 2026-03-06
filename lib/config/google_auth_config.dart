class GoogleAuthConfig {
  GoogleAuthConfig._();

  // ⚠️ 빌드 시 --dart-define으로 전달할 것!
  //
  // Google Cloud Console에서 발급:
  // https://console.cloud.google.com/apis/credentials
  // 1. OAuth 2.0 클라이언트 ID → 웹 애플리케이션 → Client ID 복사
  // 2. 빌드 명령어:
  //    flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isConfigured =>
      webClientId.isNotEmpty &&
      webClientId != 'YOUR_GOOGLE_WEB_CLIENT_ID';
}
