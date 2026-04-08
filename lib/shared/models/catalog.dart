class Catalog {
  final String id;
  final String userId;
  final String name;
  final String? description;
  /// 다중 카테고리 (DB에는 콤마구분 문자열로 저장)
  final List<String> categories;
  final String? workTag;
  final String? coverUrl;
  final double coverFitX;
  final double coverFitY;
  final double coverScale;
  final String visibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Transient: progress from joins
  final int totalItems;
  final int collectedItems;

  const Catalog({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.categories = const [],
    this.workTag,
    this.coverUrl,
    this.coverFitX = 0.5,
    this.coverFitY = 0.5,
    this.coverScale = 1.0,
    this.visibility = 'private',
    required this.createdAt,
    required this.updatedAt,
    this.totalItems = 0,
    this.collectedItems = 0,
  });

  double get completionRate =>
      totalItems > 0 ? collectedItems / totalItems : 0.0;

  bool get isOwner => false; // Set externally via copyWith

  /// 하위 호환: 단일 카테고리가 필요한 곳에서 첫 번째 값 반환
  String? get category => categories.isNotEmpty ? categories.first : null;

  /// DB 저장용 콤마구분 문자열
  String? get categoryString =>
      categories.isNotEmpty ? categories.join(',') : null;

  /// 콤마구분 문자열 → List<String>
  static List<String> _parseCategories(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').where((s) => s.isNotEmpty).toList();
  }

  factory Catalog.fromJson(Map<String, dynamic> json) {
    return Catalog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      categories: _parseCategories(json['category'] as String?),
      workTag: json['work_tag'] as String?,
      coverUrl: json['cover_url'] as String?,
      coverFitX: (json['cover_fit_x'] as num?)?.toDouble() ?? 0.5,
      coverFitY: (json['cover_fit_y'] as num?)?.toDouble() ?? 0.5,
      coverScale: (json['cover_scale'] as num?)?.toDouble() ?? 1.0,
      visibility: json['visibility'] as String? ?? 'private',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'description': description,
      'category': categoryString,
      'work_tag': workTag,
      'cover_url': coverUrl,
      'cover_fit_x': coverFitX,
      'cover_fit_y': coverFitY,
      'cover_scale': coverScale,
      'visibility': visibility,
    };
  }

  Catalog copyWith({
    String? name,
    String? description,
    List<String>? categories,
    String? workTag,
    String? coverUrl,
    double? coverFitX,
    double? coverFitY,
    double? coverScale,
    String? visibility,
    int? totalItems,
    int? collectedItems,
  }) {
    return Catalog(
      id: id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      workTag: workTag ?? this.workTag,
      coverUrl: coverUrl ?? this.coverUrl,
      coverFitX: coverFitX ?? this.coverFitX,
      coverFitY: coverFitY ?? this.coverFitY,
      coverScale: coverScale ?? this.coverScale,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt,
      updatedAt: updatedAt,
      totalItems: totalItems ?? this.totalItems,
      collectedItems: collectedItems ?? this.collectedItems,
    );
  }
}
