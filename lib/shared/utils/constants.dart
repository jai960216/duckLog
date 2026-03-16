class AppConstants {
  AppConstants._();

  static const String appName = 'DuckLog';
  static const String appNameKr = '덕로그';
  static const String appTagline = '내 덕질을 기록한다';

  // Pagination
  static const int pageSize = 20;

  // Image compression
  static const int thumbnailWidth = 300;
  static const int detailImageWidth = 1080;
  static const int imageQuality = 85;

  // Storage limits
  static const int maxImageSizeMb = 10;
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png'];

  // Free tier limits
  static const int freePhotoLimit = 50;
  static const int freeCatalogLimit = 3;
}
