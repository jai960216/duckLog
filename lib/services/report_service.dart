import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final reportServiceProvider = Provider((ref) => ReportService());

class ReportResult {
  final bool alreadyReported;
  final bool autoSuspended;

  ReportResult({required this.alreadyReported, required this.autoSuspended});
}

class ReportService {
  final _client = Supabase.instance.client;

  /// 이미 신고한 유저인지 확인
  Future<bool> hasAlreadyReported(String reportedUserId) async {
    final result = await _client.rpc(
      'check_report_exists',
      params: {'p_reported_user_id': reportedUserId},
    );
    return result as bool? ?? false;
  }

  /// 유저/굿즈 신고 (자동 차단 + 자동 정지 포함)
  Future<ReportResult> reportAndBlock({
    required String reportedUserId,
    String? reportedGoodsId,
    required String reason,
    String? description,
  }) async {
    final result = await _client.rpc(
      'report_and_block',
      params: {
        'p_reported_user_id': reportedUserId,
        'p_reported_goods_id': reportedGoodsId,
        'p_reason': reason,
        'p_description': description,
      },
    );

    final data = result as Map<String, dynamic>;
    return ReportResult(
      alreadyReported: data['already_reported'] as bool? ?? false,
      autoSuspended: data['auto_suspended'] as bool? ?? false,
    );
  }
}

class ReportReasons {
  static const inappropriate = 'inappropriate';
  static const spam = 'spam';
  static const harassment = 'harassment';
  static const impersonation = 'impersonation';
  static const other = 'other';

  static const Map<String, String> labels = {
    inappropriate: '부적절한 콘텐츠',
    spam: '스팸/광고',
    harassment: '괴롭힘/욕설',
    impersonation: '사칭',
    other: '기타',
  };
}
