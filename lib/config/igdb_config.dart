class IgdbConfig {
  IgdbConfig._();

  // Twitch Developer Console에서 발급:
  // https://dev.twitch.tv/console/apps
  // 1. 앱 등록 → Client ID, Client Secret 복사
  // 2. 아래에 붙여넣기
  static const String clientId = '***IGDB_CLIENT_ID_REMOVED***';
  static const String clientSecret = '***IGDB_CLIENT_SECRET_REMOVED***';

  static bool get isConfigured =>
      clientId != 'YOUR_TWITCH_CLIENT_ID' &&
      clientSecret != 'YOUR_TWITCH_CLIENT_SECRET';
}
