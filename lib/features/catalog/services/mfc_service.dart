import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ── Model ──

class MfcFigure {
  final int id;
  final String name;
  final String? imageUrl;
  final String? category;

  const MfcFigure({
    required this.id,
    required this.name,
    this.imageUrl,
    this.category,
  });

  factory MfcFigure.fromJson(Map<String, dynamic> json) {
    return MfcFigure(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      imageUrl: json['image'] as String? ?? json['image_url'] as String?,
      category: json['category'] as String?,
    );
  }
}

// ── Service ──

class MfcService {
  static const _baseUrl = 'https://api.tenji.moe';

  /// MFC 유저 컬렉션 가져오기
  /// status: 0=위시리스트, 1=주문중, 2=소유중, 3=이전소유
  Future<List<MfcFigure>> getCollection(String username, {int status = 2, int page = 1}) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/v1/collection/${Uri.encodeComponent(username)}?status=$status&page=$page',
      );
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 404) {
        throw Exception('유저 "$username"을 찾을 수 없어요. MFC 유저네임을 확인해주세요.');
      }
      if (response.statusCode != 200) {
        throw Exception('MFC API 오류 (${response.statusCode}). 서버가 불안정할 수 있어요.');
      }
      final data = jsonDecode(response.body);
      List list;
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('data')) {
        list = data['data'] as List;
      } else if (data is Map && data.containsKey('items')) {
        list = data['items'] as List;
      } else {
        list = [];
      }
      return list
          .map((e) => MfcFigure.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Exception catch (e) {
      if (e.toString().contains('MFC API') ||
          e.toString().contains('유저')) {
        rethrow;
      }
      throw Exception(
        'MFC 서버에 연결할 수 없어요.\n'
        '비공식 API라 간헐적으로 작동하지 않을 수 있어요.\n'
        '잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// 개별 아이템 조회
  Future<MfcFigure> getItem(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl/v1/item/$id');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        throw Exception('아이템을 불러올 수 없어요: ${response.statusCode}');
      }
      return MfcFigure.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      if (e.toString().contains('아이템')) rethrow;
      throw Exception('MFC 서버에 연결할 수 없어요.');
    }
  }
}

// ── Providers ──

final mfcServiceProvider = Provider<MfcService>((ref) {
  return MfcService();
});

final mfcCollectionProvider =
    FutureProvider.autoDispose.family<List<MfcFigure>, String>(
  (ref, username) async {
    if (username.isEmpty) return [];
    final service = ref.read(mfcServiceProvider);
    return await service.getCollection(username);
  },
);
