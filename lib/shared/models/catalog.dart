class Catalog {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String? category;
  final String? workTag;
  final String? coverUrl;
  final double coverFitY;
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
    this.category,
    this.workTag,
    this.coverUrl,
    this.coverFitY = 0.5,
    this.visibility = 'private',
    required this.createdAt,
    required this.updatedAt,
    this.totalItems = 0,
    this.collectedItems = 0,
  });

  double get completionRate =>
      totalItems > 0 ? collectedItems / totalItems : 0.0;

  bool get isOwner => false; // Set externally via copyWith

  factory Catalog.fromJson(Map<String, dynamic> json) {
    return Catalog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      workTag: json['work_tag'] as String?,
      coverUrl: json['cover_url'] as String?,
      coverFitY: (json['cover_fit_y'] as num?)?.toDouble() ?? 0.5,
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
      'category': category,
      'work_tag': workTag,
      'cover_url': coverUrl,
      'cover_fit_y': coverFitY,
      'visibility': visibility,
    };
  }

  Catalog copyWith({
    String? name,
    String? description,
    String? category,
    String? workTag,
    String? coverUrl,
    double? coverFitY,
    String? visibility,
    int? totalItems,
    int? collectedItems,
  }) {
    return Catalog(
      id: id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      workTag: workTag ?? this.workTag,
      coverUrl: coverUrl ?? this.coverUrl,
      coverFitY: coverFitY ?? this.coverFitY,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt,
      updatedAt: updatedAt,
      totalItems: totalItems ?? this.totalItems,
      collectedItems: collectedItems ?? this.collectedItems,
    );
  }
}
