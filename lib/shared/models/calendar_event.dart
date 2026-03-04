class CalendarEvent {
  final String id;
  final String workType; // anime / game
  final String externalId;
  final String title;
  final String eventType; // airing / release
  final DateTime eventDate;
  final int? episodeNumber;
  final DateTime syncedAt;

  const CalendarEvent({
    required this.id,
    required this.workType,
    required this.externalId,
    required this.title,
    required this.eventType,
    required this.eventDate,
    this.episodeNumber,
    required this.syncedAt,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      workType: json['work_type'] as String,
      externalId: json['external_id'] as String,
      title: json['title'] as String,
      eventType: json['event_type'] as String,
      eventDate: DateTime.parse(json['event_date'] as String),
      episodeNumber: json['episode_number'] as int?,
      syncedAt: DateTime.parse(json['synced_at'] as String),
    );
  }

  String get displayTitle {
    if (eventType == 'airing' && episodeNumber != null) {
      return '$title $episodeNumber화';
    }
    return title;
  }

  bool get isAnime => workType == 'anime';
  bool get isGame => workType == 'game';
}
