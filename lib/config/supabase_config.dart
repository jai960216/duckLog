class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  // Storage bucket names
  static const String goodsPhotoBucket = 'goods-photos';
  static const String receiptPhotoBucket = 'receipt-photos';
  static const String avatarBucket = 'avatars';
}
