class AppConstants {
  AppConstants._();

  static const String appName = 'DuckLog';
  static const String appNameKr = '덕로그';
  static const String appTagline = '내 덕질을 기록한다';

  // Webtoon API (korea-webtoon-api 자체 배포 URL)
  // https://github.com/HyeokjaeLee/korea-webtoon-api 를 클론하여 배포한 뒤 URL 변경
  static const String webtoonApiUrl = 'https://korea-webtoon-api-1.onrender.com';

  // Pagination
  static const int pageSize = 20;

  // Image compression
  static const int thumbnailWidth = 300;
  static const int detailImageWidth = 1080;
  static const int imageQuality = 85;

  // Storage limits
  static const int maxImageSizeMb = 10;
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png'];
}
