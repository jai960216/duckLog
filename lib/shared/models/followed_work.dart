class FollowedWork {
  final String id;
  final String userId;
  final String workType; // anime / manga / webtoon / game
  final String externalId;
  final String title;
  final String? coverUrl;
  final bool notify;

  const FollowedWork({
    required this.id,
    required this.userId,
    required this.workType,
    required this.externalId,
    required this.title,
    this.coverUrl,
    this.notify = true,
  });

  factory FollowedWork.fromJson(Map<String, dynamic> json) {
    return FollowedWork(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      workType: json['work_type'] as String,
      externalId: json['external_id'] as String,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String?,
      notify: json['notify'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'work_type': workType,
      'external_id': externalId,
      'title': title,
      'cover_url': coverUrl,
      'notify': notify,
    };
  }
}
