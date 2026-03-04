class Goods {
  final String id;
  final String userId;
  final String name;
  final int? price;
  final String? category;
  final String? workTag;
  final String? artistTag;
  final List<String> photoUrls;
  final DateTime? purchasedAt;
  final String? memo;
  final String visibility;
  final DateTime createdAt;

  // Transient: like count from joins
  final int likeCount;
  final bool isLikedByMe;

  const Goods({
    required this.id,
    required this.userId,
    required this.name,
    this.price,
    this.category,
    this.workTag,
    this.artistTag,
    this.photoUrls = const [],
    this.purchasedAt,
    this.memo,
    this.visibility = 'public',
    required this.createdAt,
    this.likeCount = 0,
    this.isLikedByMe = false,
  });

  factory Goods.fromJson(Map<String, dynamic> json) {
    return Goods(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      price: json['price'] as int?,
      category: json['category'] as String?,
      workTag: json['work_tag'] as String?,
      artistTag: json['artist_tag'] as String?,
      photoUrls: json['photo_urls'] != null
          ? List<String>.from(json['photo_urls'] as List)
          : [],
      purchasedAt: json['purchased_at'] != null
          ? DateTime.parse(json['purchased_at'] as String)
          : null,
      memo: json['memo'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      createdAt: DateTime.parse(json['created_at'] as String),
      likeCount: json['like_count'] as int? ?? 0,
      isLikedByMe: json['is_liked_by_me'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'price': price,
      'category': category,
      'work_tag': workTag,
      'artist_tag': artistTag,
      'photo_urls': photoUrls,
      'purchased_at': purchasedAt?.toIso8601String().split('T').first,
      'memo': memo,
      'visibility': visibility,
    };
  }

  Goods copyWith({
    String? name,
    int? price,
    String? category,
    String? workTag,
    String? artistTag,
    List<String>? photoUrls,
    DateTime? purchasedAt,
    String? memo,
    String? visibility,
  }) {
    return Goods(
      id: id,
      userId: userId,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      workTag: workTag ?? this.workTag,
      artistTag: artistTag ?? this.artistTag,
      photoUrls: photoUrls ?? this.photoUrls,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      memo: memo ?? this.memo,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt,
      likeCount: likeCount,
      isLikedByMe: isLikedByMe,
    );
  }

  static const List<String> categories = [
    'figure',
    'photocard',
    'acrylic',
    'album',
    'poster',
    'plush',
    'keyring',
    'stationery',
    'clothing',
    'badge',
    'other',
  ];

  static String categoryLabel(String category) {
    switch (category) {
      case 'figure':
        return '피규어';
      case 'photocard':
        return '포토카드';
      case 'acrylic':
        return '아크릴';
      case 'album':
        return '앨범';
      case 'poster':
        return '포스터';
      case 'plush':
        return '인형';
      case 'keyring':
        return '키링';
      case 'stationery':
        return '문구';
      case 'clothing':
        return '의류';
      case 'badge':
        return '뱃지';
      case 'other':
        return '기타';
      default:
        return category;
    }
  }
}
