class Profile {
  final String id;
  final String nickname;
  final String? avatarUrl;
  final String? bio;
  final Map<String, String> snsLinks;
  final bool isPublic;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.bio,
    this.snsLinks = const {},
    this.isPublic = true,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      snsLinks: json['sns_links'] != null
          ? Map<String, String>.from(json['sns_links'] as Map)
          : {},
      isPublic: json['is_public'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'bio': bio,
      'sns_links': snsLinks,
      'is_public': isPublic,
    };
  }

  Profile copyWith({
    String? nickname,
    String? avatarUrl,
    String? bio,
    Map<String, String>? snsLinks,
    bool? isPublic,
  }) {
    return Profile(
      id: id,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      snsLinks: snsLinks ?? this.snsLinks,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt,
    );
  }
}
