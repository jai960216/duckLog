import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';

class OcrCatalogService {
  final SupabaseClient _client;

  OcrCatalogService(this._client);

  /// 이미지를 Supabase Edge Function으로 전송하여 아이템 이름 목록 추출
  /// 현재는 stub 구현 — 실제 GPT-4o Vision 연동은 Edge Function 배포 필요
  Future<List<String>> extractItemsFromImage(Uint8List imageBytes) async {
    try {
      final response = await _client.functions.invoke(
        'extract-catalog-items',
        body: {
          'image': imageBytes.toList(),
        },
      );

      if (response.status != 200) {
        throw Exception('OCR 처리 실패: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      final items = data['items'] as List;
      return items.map((e) => e as String).toList();
    } catch (e) {
      // Edge Function이 아직 배포되지 않은 경우 stub 데이터 반환
      if (e.toString().contains('FunctionException') ||
          e.toString().contains('404') ||
          e.toString().contains('Failed host lookup')) {
        throw Exception(
          'OCR 기능을 사용하려면 Supabase Edge Function 설정이 필요해요.\n'
          '직접 입력으로 아이템을 추가해주세요.',
        );
      }
      rethrow;
    }
  }
}

// ── Provider ──

final ocrCatalogServiceProvider = Provider<OcrCatalogService>((ref) {
  return OcrCatalogService(ref.read(supabaseClientProvider));
});
