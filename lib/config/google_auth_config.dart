class GoogleAuthConfig {
  GoogleAuthConfig._();

  static const String webClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static bool get isConfigured => webClientId.isNotEmpty;
}
