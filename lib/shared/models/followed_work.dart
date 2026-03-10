class FollowedWork {
  final String id;
  final String userId;
  final String workType; // anime / manga / webtoon / game
  final String externalId;
  final String title;
  final String? coverUrl;
  final bool notify;
  final List<String> updateDays; // 웹툰 연재 요일 (MON, TUE, ...)

  const FollowedWork({
    required this.id,
    required this.userId,
    required this.workType,
    required this.externalId,
    required this.title,
    this.coverUrl,
    this.notify = true,
    this.updateDays = const [],
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
      updateDays: json['update_days'] != null
          ? List<String>.from(json['update_days'] as List)
          : [],
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
      if (updateDays.isNotEmpty) 'update_days': updateDays,
    };
  }
}
