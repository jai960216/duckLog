import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/friendship.dart';
import '../../../shared/models/profile.dart';
import '../../auth/services/auth_service.dart';

final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService(ref.read(supabaseClientProvider));
});

final friendsProvider = FutureProvider.autoDispose<List<Friendship>>((ref) async {
  final service = ref.read(friendServiceProvider);
  return await service.getFriends();
});

final receivedRequestsProvider =
    FutureProvider.autoDispose<List<Friendship>>((ref) async {
  final service = ref.read(friendServiceProvider);
  return await service.getReceivedRequests();
});

final sentRequestsProvider =
    FutureProvider.autoDispose<List<Friendship>>((ref) async {
  final service = ref.read(friendServiceProvider);
  return await service.getSentRequests();
});

final relationshipProvider =
    FutureProvider.autoDispose.family<Friendship?, String>((ref, userId) async {
  final service = ref.read(friendServiceProvider);
  return await service.getRelationship(userId);
});

final pendingCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.read(friendServiceProvider);
  return await service.getPendingCount();
});

/// Exception: 에러 메시지에 "Exception:" 접두어가 붙는 것을 방지
class FriendException implements Exception {
  final String message;
  const FriendException(this.message);

  @override
  String toString() => message;
}

class FriendService {
  final SupabaseClient _client;

  FriendService(this._client);

  String? get currentUserId => _client.auth.currentUser?.id;

  String? get _userId => currentUserId;

  /// 친구 요청 전송
  /// - 이미 관계가 존재하면 중복 요청 방지
  /// - 상대가 이미 나에게 보낸 pending 요청이 있으면 바로 accepted 처리
  Future<void> sendRequest(String receiverId) async {
    if (_userId == null) throw FriendException('로그인이 필요해요');
    if (receiverId == _userId) throw FriendException('자기 자신에게 요청할 수 없어요');

    // 내가 이미 보낸 요청이 있는지 확인
    final existing = await _client
        .from('friendships')
        .select()
        .eq('requester_id', _userId!)
        .eq('receiver_id', receiverId)
        .maybeSingle();

    if (existing != null) {
      final status = existing['status'] as String?;
      if (status == 'accepted') {
        throw FriendException('이미 친구예요');
      }
      throw FriendException('이미 요청을 보냈어요');
    }

    // 상대가 먼저 나에게 보낸 요청이 있는지 확인
    final reverse = await _client
        .from('friendships')
        .select()
        .eq('requester_id', receiverId)
        .eq('receiver_id', _userId!)
        .maybeSingle();

    if (reverse != null) {
      final status = reverse['status'] as String?;
      if (status == 'accepted') {
        throw FriendException('이미 친구예요');
      }
      // 상대의 pending 요청 → 바로 수락 처리
      await _client
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', reverse['id']);
      return;
    }

    // 신규 요청
    await _client.from('friendships').insert({
      'requester_id': _userId,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  /// 요청 수락
  Future<void> acceptRequest(String friendshipId) async {
    await _client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
  }

  /// 요청 거절 (행 삭제 — 상대가 재요청 가능하도록)
  Future<void> rejectRequest(String friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  /// 친구 삭제 또는 보낸 요청 취소
  Future<void> removeFriendship(String friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  /// accepted 친구 목록 (양방향)
  Future<List<Friendship>> getFriends() async {
    if (_userId == null) return [];

    // 1) 내가 requester인 경우 → receiver profile join
    final asRequester = await _client
        .from('friendships')
        .select('*, receiver:profiles!friendships_receiver_id_fkey(*)')
        .eq('requester_id', _userId!)
        .eq('status', 'accepted')
        .order('created_at', ascending: false);

    // 2) 내가 receiver인 경우 → requester profile join
    final asReceiver = await _client
        .from('friendships')
        .select('*, requester:profiles!friendships_requester_id_fkey(*)')
        .eq('receiver_id', _userId!)
        .eq('status', 'accepted')
        .order('created_at', ascending: false);

    final list = <Friendship>[];
    for (final row in asRequester as List) {
      list.add(Friendship.fromJson(row));
    }
    for (final row in asReceiver as List) {
      list.add(Friendship.fromJson(row));
    }
    return list;
  }

  /// 받은 pending 요청
  Future<List<Friendship>> getReceivedRequests() async {
    if (_userId == null) return [];

    final response = await _client
        .from('friendships')
        .select('*, requester:profiles!friendships_requester_id_fkey(*)')
        .eq('receiver_id', _userId!)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => Friendship.fromJson(row))
        .toList();
  }

  /// 보낸 pending 요청
  Future<List<Friendship>> getSentRequests() async {
    if (_userId == null) return [];

    final response = await _client
        .from('friendships')
        .select('*, receiver:profiles!friendships_receiver_id_fkey(*)')
        .eq('requester_id', _userId!)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => Friendship.fromJson(row))
        .toList();
  }

  /// 특정 유저와의 관계 조회
  Future<Friendship?> getRelationship(String otherUserId) async {
    if (_userId == null) return null;

    // 내가 보낸 요청
    final sent = await _client
        .from('friendships')
        .select()
        .eq('requester_id', _userId!)
        .eq('receiver_id', otherUserId)
        .maybeSingle();

    if (sent != null) return Friendship.fromJson(sent);

    // 상대가 보낸 요청
    final received = await _client
        .from('friendships')
        .select()
        .eq('requester_id', otherUserId)
        .eq('receiver_id', _userId!)
        .maybeSingle();

    if (received != null) return Friendship.fromJson(received);

    return null;
  }

  /// 친구 코드로 프로필 검색
  Future<Profile?> searchByFriendCode(String code) async {
    final cleanCode = code.toLowerCase().trim();
    if (cleanCode.isEmpty) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('friend_code', cleanCode)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromJson(response);
  }

  /// 받은 pending 요청 수 (뱃지용)
  Future<int> getPendingCount() async {
    if (_userId == null) return 0;

    final response = await _client
        .from('friendships')
        .select('id')
        .eq('receiver_id', _userId!)
        .eq('status', 'pending');

    return (response as List).length;
  }
}
