/// Pro 여부에 따른 이미지 압축 설정
class ImageQualitySettings {
  final double maxWidth;
  final int quality;

  const ImageQualitySettings({required this.maxWidth, required this.quality});

  static const free = ImageQualitySettings(
    maxWidth: 1080,
    quality: 85,
  );

  static const pro = ImageQualitySettings(
    maxWidth: 2048,
    quality: 95,
  );

  static ImageQualitySettings fromPro(bool isPro) => isPro ? pro : free;
}
