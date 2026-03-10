import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/followed_work.dart';
import '../../../shared/models/calendar_event.dart';
import '../../auth/services/auth_service.dart';
import 'anilist_service.dart';
import 'igdb_service.dart';
import 'webtoon_service.dart';

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService(ref.read(supabaseClientProvider));
});

final followedWorksProvider =
    FutureProvider.autoDispose<List<FollowedWork>>((ref) async {
  try {
    final service = ref.read(calendarServiceProvider);
    return await service.getFollowedWorks();
  } catch (e) {
    return [];
  }
});

// key: "yyyy-MM"
final monthEventsProvider =
    FutureProvider.autoDispose.family<List<CalendarEvent>, String>(
  (ref, monthKey) async {
    try {
      final parts = monthKey.split('-');
      final month = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      final service = ref.read(calendarServiceProvider);
      return await service.getEventsForMonth(month);
    } catch (e) {
      return [];
    }
  },
);

// Events for a specific work
final workEventsProvider =
    FutureProvider.autoDispose.family<List<CalendarEvent>, String>(
  (ref, externalId) async {
    try {
      final service = ref.read(calendarServiceProvider);
      return await service.getEventsForWork(externalId);
    } catch (e) {
      return [];
    }
  },
);

/// 캘린더 표시용 일정 (애니 방영 + 만화 + 웹툰 + 게임 출시)
class AiringEntry {
  final String title;
  final String workType; // anime, manga, webtoon, or game
  final String externalId;
  final int? episode;
  final DateTime airingDate;
  final String eventType; // airing, update, or release

  const AiringEntry({
    required this.title,
    required this.workType,
    required this.externalId,
    this.episode,
    required this.airingDate,
    required this.eventType,
  });

  String get displayTitle {
    if (eventType == 'airing' && episode != null) return '$title $episode화';
    if (eventType == 'update') return '$title 업데이트';
    if (eventType == 'release') return '$title 출시';
    return title;
  }

  bool get isAnime => workType == 'anime';
  bool get isManga => workType == 'manga';
  bool get isWebtoon => workType == 'webtoon';
  bool get isGame => workType == 'game';
  bool get isCustom => workType == 'custom';
}

/// 팔로우한 작품의 일정 (애니 방영 + 게임 출시, 월별)
final monthAiringScheduleProvider =
    FutureProvider.autoDispose.family<List<AiringEntry>, String>(
  (ref, monthKey) async {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    List<FollowedWork> followedWorks;
    try {
      followedWorks = await ref.watch(followedWorksProvider.future);
    } catch (_) {
      return [];
    }

    final anilistService = ref.read(anilistServiceProvider);
    final calendarService = ref.read(calendarServiceProvider);
    final entries = <AiringEntry>[];

    // 작품 분류
    final animeWorks = followedWorks.where((w) => w.workType == 'anime').toList();
    final gameWorks = followedWorks.where((w) => w.workType == 'game').toList();
    final webtoonWorks = followedWorks.where((w) => w.workType == 'webtoon').toList();

    // ── 애니: AniList 방영 스케줄 (병렬 호출) ──
    final animeFutures = animeWorks.map((work) async {
      final mediaId = int.tryParse(work.externalId);
      if (mediaId == null) return <AiringEntry>[];
      try {
        final schedules = await anilistService.getAiringSchedule(mediaId);
        return schedules
            .where((s) {
              final date = s.airingDateTime;
              return !date.isBefore(startDate) && !date.isAfter(endDate);
            })
            .map((s) => AiringEntry(
                  title: work.title,
                  workType: work.workType,
                  externalId: work.externalId,
                  episode: s.episode,
                  airingDate: s.airingDateTime,
                  eventType: 'airing',
                ))
            .toList();
      } catch (_) {
        return <AiringEntry>[];
      }
    });

    // ── 웹툰: updateDays 패턴 → 해당 월의 구체적 날짜 변환 ──
    final webtoonEntries = <AiringEntry>[];
    const dayToWeekday = {
      'MON': DateTime.monday,
      'TUE': DateTime.tuesday,
      'WED': DateTime.wednesday,
      'THU': DateTime.thursday,
      'FRI': DateTime.friday,
      'SAT': DateTime.saturday,
      'SUN': DateTime.sunday,
    };

    // DB의 updateDays가 비어있으면 웹툰 API에서 조회
    final webtoonService = ref.read(webtoonServiceProvider);
    for (final work in webtoonWorks) {
      var days = work.updateDays;
      if (days.isEmpty && webtoonService.isConfigured) {
        try {
          days = await ref.watch(webtoonUpdateDaysProvider(
              (title: work.title, id: work.externalId)).future);
        } catch (_) {}
      }

      for (final day in days) {
        final weekday = dayToWeekday[day];
        if (weekday == null) continue;
        // 해당 월의 첫 번째 해당 요일 찾기
        var date = startDate;
        while (date.weekday != weekday) {
          date = date.add(const Duration(days: 1));
        }
        // 해당 월의 모든 해당 요일에 엔트리 생성
        while (!date.isAfter(endDate)) {
          webtoonEntries.add(AiringEntry(
            title: work.title,
            workType: 'webtoon',
            externalId: work.externalId,
            airingDate: date,
            eventType: 'update',
          ));
          date = date.add(const Duration(days: 7));
        }
      }
    }

    // ── 게임: IGDB API에서 출시일 조회 (병렬 호출) ──
    final igdbService = ref.read(igdbServiceProvider);
    final gameFutures = gameWorks.map((work) async {
      try {
        // IGDB API에서 출시일 직접 조회
        DateTime? releaseDate;
        if (igdbService.isConfigured) {
          try {
            releaseDate = await ref.watch(gameReleaseDateProvider(
                (title: work.title, id: work.externalId)).future);
          } catch (_) {}
        }

        // DB calendar_events 폴백
        if (releaseDate == null) {
          try {
            final events =
                await calendarService.getEventsForWork(work.externalId);
            return events
                .where((e) {
                  final date = e.eventDate;
                  return !date.isBefore(startDate) && !date.isAfter(endDate);
                })
                .map((e) => AiringEntry(
                      title: work.title,
                      workType: work.workType,
                      externalId: work.externalId,
                      airingDate: e.eventDate,
                      eventType: e.eventType,
                    ))
                .toList();
          } catch (_) {}
          return <AiringEntry>[];
        }

        // 출시일이 해당 월에 포함되면 엔트리 추가
        if (!releaseDate.isBefore(startDate) && !releaseDate.isAfter(endDate)) {
          return [
            AiringEntry(
              title: work.title,
              workType: 'game',
              externalId: work.externalId,
              airingDate: releaseDate,
              eventType: 'release',
            ),
          ];
        }
        return <AiringEntry>[];
      } catch (_) {
        return <AiringEntry>[];
      }
    });

    final results = await Future.wait([...animeFutures, ...gameFutures]);
    for (final list in results) {
      entries.addAll(list);
    }
    entries.addAll(webtoonEntries);

    // ── 커스텀 이벤트: calendar_events에서 workType='custom' 조회 ──
    try {
      final customEvents = await calendarService.getCustomEventsForMonth(
        DateTime(year, month, 1),
      );
      entries.addAll(customEvents.map((e) => AiringEntry(
            title: e.title,
            workType: 'custom',
            externalId: e.externalId,
            airingDate: e.eventDate,
            eventType: 'custom',
          )));
    } catch (_) {}

    entries.sort((a, b) => a.airingDate.compareTo(b.airingDate));
    return entries;
  },
);

class CalendarService {
  final SupabaseClient _client;

  CalendarService(this._client);

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.id;
  }

  // Follow a work
  Future<FollowedWork> followWork({
    required String workType,
    required String title,
    String? coverUrl,
    String? externalId,
    List<String> updateDays = const [],
  }) async {
    final effectiveExternalId = externalId ?? _slugify(title);
    final baseData = {
      'user_id': _userId,
      'work_type': workType,
      'external_id': effectiveExternalId,
      'title': title,
      'cover_url': coverUrl,
      'notify': true,
    };

    // update_days 컬럼이 있으면 포함, 없으면 재시도
    if (updateDays.isNotEmpty) {
      try {
        final data = {...baseData, 'update_days': updateDays};
        final response = await _client
            .from('followed_works')
            .upsert(data, onConflict: 'user_id,work_type,external_id')
            .select()
            .single();
        return FollowedWork.fromJson(response);
      } catch (_) {
        // update_days 컬럼이 없을 수 있음 — 컬럼 없이 재시도
      }
    }

    final response = await _client
        .from('followed_works')
        .upsert(baseData, onConflict: 'user_id,work_type,external_id')
        .select()
        .single();
    return FollowedWork.fromJson(response);
  }

  // Unfollow a work
  Future<void> unfollowWork(String id) async {
    await _client.from('followed_works').delete().eq('id', id);
  }

  // Get all followed works for current user
  Future<List<FollowedWork>> getFollowedWorks() async {
    final response = await _client
        .from('followed_works')
        .select()
        .eq('user_id', _userId)
        .order('title');

    return (response as List).map((e) => FollowedWork.fromJson(e)).toList();
  }

  // Check if a work is followed
  Future<bool> isFollowing(String workType, String externalId) async {
    final response = await _client
        .from('followed_works')
        .select('id')
        .eq('user_id', _userId)
        .eq('work_type', workType)
        .eq('external_id', externalId)
        .maybeSingle();
    return response != null;
  }

  // Get events for a month, filtered to followed works only
  Future<List<CalendarEvent>> getEventsForMonth(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    // Get followed works' external_ids
    final followedWorks = await getFollowedWorks();
    if (followedWorks.isEmpty) return [];

    final externalIds = followedWorks.map((w) => w.externalId).toList();

    final response = await _client
        .from('calendar_events')
        .select()
        .inFilter('external_id', externalIds)
        .gte('event_date', startDate.toIso8601String().split('T').first)
        .lte('event_date', endDate.toIso8601String().split('T').first)
        .order('event_date');

    return (response as List).map((e) => CalendarEvent.fromJson(e)).toList();
  }

  // Get events for a specific work
  Future<List<CalendarEvent>> getEventsForWork(String externalId) async {
    final response = await _client
        .from('calendar_events')
        .select()
        .eq('external_id', externalId)
        .order('event_date');

    return (response as List).map((e) => CalendarEvent.fromJson(e)).toList();
  }

  // Add a calendar event manually
  Future<CalendarEvent> addEvent({
    required String workType,
    required String externalId,
    required String title,
    required String eventType,
    required DateTime eventDate,
    int? episodeNumber,
  }) async {
    final data = {
      'work_type': workType,
      'external_id': externalId,
      'title': title,
      'event_type': eventType,
      'event_date': eventDate.toIso8601String().split('T').first,
      'episode_number': episodeNumber,
      'synced_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('calendar_events')
        .upsert(data,
            onConflict: 'work_type,external_id,event_date,episode_number')
        .select()
        .single();
    return CalendarEvent.fromJson(response);
  }

  // Add a custom calendar event (not tied to a followed work)
  Future<CalendarEvent> addCustomEvent({
    required String title,
    required DateTime eventDate,
  }) async {
    final externalId = 'custom_${_userId}_${DateTime.now().millisecondsSinceEpoch}';
    return addEvent(
      workType: 'custom',
      externalId: externalId,
      title: title,
      eventType: 'custom',
      eventDate: eventDate,
    );
  }

  // Get custom events for a month
  Future<List<CalendarEvent>> getCustomEventsForMonth(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    final response = await _client
        .from('calendar_events')
        .select()
        .eq('work_type', 'custom')
        .like('external_id', 'custom_${_userId}_%')
        .gte('event_date', startDate.toIso8601String().split('T').first)
        .lte('event_date', endDate.toIso8601String().split('T').first)
        .order('event_date');

    return (response as List).map((e) => CalendarEvent.fromJson(e)).toList();
  }

  // Delete a calendar event
  Future<void> deleteEvent(String id) async {
    await _client.from('calendar_events').delete().eq('id', id);
  }

  // Slugify title for external_id
  String _slugify(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s가-힣ぁ-んァ-ヶ一-龥-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }
}
