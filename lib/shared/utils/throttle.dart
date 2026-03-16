/// 클라이언트 사이드 액션 쓰로틀링
class ActionThrottle {
  static final Map<String, DateTime> _lastActions = {};

  /// 쓰로틀 체크. 허용되면 true, 차단되면 false.
  static bool allow(String actionKey, {Duration cooldown = const Duration(seconds: 2)}) {
    final now = DateTime.now();
    final last = _lastActions[actionKey];

    if (last != null && now.difference(last) < cooldown) {
      return false;
    }

    _lastActions[actionKey] = now;
    return true;
  }

  /// 좋아요 쓰로틀 (1초)
  static bool allowLike(String goodsId) {
    return allow('like_$goodsId', cooldown: const Duration(seconds: 1));
  }

  /// 친구 요청 쓰로틀 (5초)
  static bool allowFriendRequest(String userId) {
    return allow('friend_$userId', cooldown: const Duration(seconds: 5));
  }

  /// 신고 쓰로틀 (30초)
  static bool allowReport() {
    return allow('report', cooldown: const Duration(seconds: 30));
  }
}
