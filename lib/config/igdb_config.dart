class IgdbConfig {
  IgdbConfig._();

  static const String clientId = String.fromEnvironment('IGDB_CLIENT_ID');
  static const String clientSecret = String.fromEnvironment('IGDB_CLIENT_SECRET');

  static bool get isConfigured =>
      clientId.isNotEmpty && clientSecret.isNotEmpty;
}
