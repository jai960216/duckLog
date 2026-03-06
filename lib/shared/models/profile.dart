class Profile {
  final String id;
  final String nickname;
  final String friendCode;
  final String? avatarUrl;
  final String? bio;
  final Map<String, String> snsLinks;
  final bool isPublic;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.nickname,
    required this.friendCode,
    this.avatarUrl,
    this.bio,
    this.snsLinks = const {},
    this.isPublic = true,
    required this.createdAt,
  });

  /// 닉네임#코드 형태의 태그
  String get displayTag => '$nickname#$friendCode';

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      friendCode: json['friend_code'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      snsLinks: json['sns_links'] != null
          ? (json['sns_links'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )
          : {},
      isPublic: json['is_public'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'friend_code': friendCode,
      'avatar_url': avatarUrl,
      'bio': bio,
      'sns_links': snsLinks,
      'is_public': isPublic,
    };
  }

  Profile copyWith({
    String? nickname,
    String? friendCode,
    String? avatarUrl,
    String? bio,
    Map<String, String>? snsLinks,
    bool? isPublic,
  }) {
    return Profile(
      id: id,
      nickname: nickname ?? this.nickname,
      friendCode: friendCode ?? this.friendCode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      snsLinks: snsLinks ?? this.snsLinks,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt,
    );
  }
}
