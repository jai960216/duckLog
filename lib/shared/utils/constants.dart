class AppConstants {
  AppConstants._();

  static const String appName = 'DuckLog';
  static const String appNameKr = '덕로그';
  static const String appTagline = '내 덕질을 기록한다';

  // Pagination
  static const int pageSize = 20;

  // Image compression — Free
  static const int thumbnailWidth = 300;
  static const int detailImageWidth = 1080;
  static const int imageQuality = 85;

  // Image compression — Pro
  static const int proDetailImageWidth = 2048;
  static const int proImageQuality = 95;

  // Storage limits
  static const int maxImageSizeMb = 10;
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png'];

  // Free tier limits
  static const int freePhotoLimit = 50;
  static const int freeCatalogLimit = 3;
  static const int freeCatalogItemLimit = 30;
}
