class IgdbConfig {
  IgdbConfig._();

  // ⚠️ 프로덕션 배포 전에 반드시 환경변수 또는 --dart-define으로 교체할 것!
  // 현재 값은 개발/테스트 전용 — git에 커밋된 시크릿은 rotate 필요
  //
  // Twitch Developer Console에서 발급:
  // https://dev.twitch.tv/console/apps
  // 1. 앱 등록 → Client ID, Client Secret 복사
  // 2. 아래에 붙여넣기 (또는 --dart-define 사용)
  static const String clientId = String.fromEnvironment(
    'IGDB_CLIENT_ID',
    defaultValue: '***IGDB_CLIENT_ID_REMOVED***',
  );
  static const String clientSecret = String.fromEnvironment(
    'IGDB_CLIENT_SECRET',
    defaultValue: '***IGDB_CLIENT_SECRET_REMOVED***',
  );

  static bool get isConfigured =>
      clientId.isNotEmpty &&
      clientSecret.isNotEmpty &&
      clientId != 'YOUR_TWITCH_CLIENT_ID' &&
      clientSecret != 'YOUR_TWITCH_CLIENT_SECRET';
}
