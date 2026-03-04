import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/followed_work.dart';
import '../../../shared/models/calendar_event.dart';
import '../../auth/services/auth_service.dart';

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
  }) async {
    final externalId = _slugify(title);
    final data = {
      'user_id': _userId,
      'work_type': workType,
      'external_id': externalId,
      'title': title,
      'cover_url': coverUrl,
      'notify': true,
    };

    final response = await _client
        .from('followed_works')
        .upsert(data, onConflict: 'user_id,work_type,external_id')
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
