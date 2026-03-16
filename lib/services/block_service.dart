import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final blockServiceProvider = Provider((ref) => BlockService());

final blockedUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.read(blockServiceProvider).getBlockedUserIds();
});

class BlockService {
  final _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<void> blockUser(String targetUserId) async {
    if (_userId == null) throw Exception('Not authenticated');
    if (_userId == targetUserId) throw Exception('Cannot block yourself');

    await _client.from('blocks').upsert({
      'blocker_id': _userId,
      'blocked_id': targetUserId,
    });

    // 차단 시 기존 친구 관계도 삭제
    await _client.from('friendships').delete().or(
      'and(requester_id.eq.$_userId,receiver_id.eq.$targetUserId),'
      'and(requester_id.eq.$targetUserId,receiver_id.eq.$_userId)',
    );
  }

  Future<void> unblockUser(String targetUserId) async {
    if (_userId == null) throw Exception('Not authenticated');

    await _client
        .from('blocks')
        .delete()
        .eq('blocker_id', _userId!)
        .eq('blocked_id', targetUserId);
  }

  Future<bool> isBlocked(String targetUserId) async {
    if (_userId == null) return false;

    final result = await _client
        .from('blocks')
        .select('id')
        .eq('blocker_id', _userId!)
        .eq('blocked_id', targetUserId)
        .maybeSingle();

    return result != null;
  }

  Future<Set<String>> getBlockedUserIds() async {
    if (_userId == null) return {};

    final result = await _client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', _userId!);

    return (result as List).map((r) => r['blocked_id'] as String).toSet();
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    if (_userId == null) return [];

    final result = await _client.rpc('get_blocked_users');

    return List<Map<String, dynamic>>.from(result);
  }
}
