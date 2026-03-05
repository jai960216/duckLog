import 'catalog_item.dart';

class CatalogCharacter {
  final String id;
  final String catalogId;
  final String name;
  final String? photoUrl;
  final String? externalId;
  final int sortOrder;
  final DateTime createdAt;

  // Transient: items grouped under this character
  final List<CatalogItem> items;
  final int totalItems;
  final int collectedItems;

  const CatalogCharacter({
    required this.id,
    required this.catalogId,
    required this.name,
    this.photoUrl,
    this.externalId,
    this.sortOrder = 0,
    required this.createdAt,
    this.items = const [],
    this.totalItems = 0,
    this.collectedItems = 0,
  });

  factory CatalogCharacter.fromJson(Map<String, dynamic> json) {
    return CatalogCharacter(
      id: json['id'] as String,
      catalogId: json['catalog_id'] as String,
      name: json['name'] as String,
      photoUrl: json['photo_url'] as String?,
      externalId: json['external_id'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'catalog_id': catalogId,
      'name': name,
      'photo_url': photoUrl,
      'external_id': externalId,
      'sort_order': sortOrder,
    };
  }

  CatalogCharacter copyWith({
    String? name,
    String? photoUrl,
    String? externalId,
    int? sortOrder,
    List<CatalogItem>? items,
    int? totalItems,
    int? collectedItems,
  }) {
    return CatalogCharacter(
      id: id,
      catalogId: catalogId,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      externalId: externalId ?? this.externalId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      items: items ?? this.items,
      totalItems: totalItems ?? this.totalItems,
      collectedItems: collectedItems ?? this.collectedItems,
    );
  }
}
