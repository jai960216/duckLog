class CatalogItem {
  final String id;
  final String catalogId;
  final String? characterId;
  final String name;
  final String? description;
  final String? photoUrl;
  final String? category;
  final int sortOrder;
  final DateTime createdAt;

  // Transient: collection status
  final bool isCollected;
  final DateTime? collectedAt;

  const CatalogItem({
    required this.id,
    required this.catalogId,
    this.characterId,
    required this.name,
    this.description,
    this.photoUrl,
    this.category,
    this.sortOrder = 0,
    required this.createdAt,
    this.isCollected = false,
    this.collectedAt,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: json['id'] as String,
      catalogId: json['catalog_id'] as String,
      characterId: json['character_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      photoUrl: json['photo_url'] as String?,
      category: json['category'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'catalog_id': catalogId,
      'character_id': characterId,
      'name': name,
      'description': description,
      'photo_url': photoUrl,
      'category': category,
      'sort_order': sortOrder,
    };
  }

  CatalogItem copyWith({
    String? characterId,
    bool clearCharacterId = false,
    String? name,
    String? description,
    String? photoUrl,
    String? category,
    bool clearCategory = false,
    int? sortOrder,
    bool? isCollected,
    DateTime? collectedAt,
  }) {
    return CatalogItem(
      id: id,
      catalogId: catalogId,
      characterId: clearCharacterId ? null : (characterId ?? this.characterId),
      name: name ?? this.name,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      category: clearCategory ? null : (category ?? this.category),
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      isCollected: isCollected ?? this.isCollected,
      collectedAt: collectedAt ?? this.collectedAt,
    );
  }
}
