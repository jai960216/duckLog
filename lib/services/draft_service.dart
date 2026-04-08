import 'package:hive_flutter/hive_flutter.dart';

class DraftService {
  static const _boxName = 'goods_draft';

  static Future<Box> _openBox() => Hive.openBox(_boxName);

  static Future<void> saveDraft({
    required String name,
    String? price,
    String? category,
    String? workTag,
    String? artistTag,
    String? purchasePlace,
    String? memo,
    String? purchasedAt,
    String? visibility,
    String? catalogItemId,
    String? catalogId,
    String? catalogItemName,
    String? catalogName,
  }) async {
    final box = await _openBox();
    await box.putAll({
      'name': name,
      'price': price ?? '',
      'category': category ?? '',
      'workTag': workTag ?? '',
      'artistTag': artistTag ?? '',
      'purchasePlace': purchasePlace ?? '',
      'memo': memo ?? '',
      'purchasedAt': purchasedAt ?? '',
      'visibility': visibility ?? 'public',
      'catalogItemId': catalogItemId ?? '',
      'catalogId': catalogId ?? '',
      'catalogItemName': catalogItemName ?? '',
      'catalogName': catalogName ?? '',
      'savedAt': DateTime.now().toIso8601String(),
      'completed': false,
    });
  }

  static Future<Map<String, dynamic>?> loadDraft() async {
    final box = await _openBox();
    final name = box.get('name', defaultValue: '') as String;
    if (name.isEmpty) return null;
    return {
      'name': name,
      'price': box.get('price', defaultValue: '') as String,
      'category': box.get('category', defaultValue: '') as String,
      'workTag': box.get('workTag', defaultValue: '') as String,
      'artistTag': box.get('artistTag', defaultValue: '') as String,
      'purchasePlace': box.get('purchasePlace', defaultValue: '') as String,
      'memo': box.get('memo', defaultValue: '') as String,
      'purchasedAt': box.get('purchasedAt', defaultValue: '') as String,
      'visibility': box.get('visibility', defaultValue: 'public') as String,
      'catalogItemId': box.get('catalogItemId', defaultValue: '') as String,
      'catalogId': box.get('catalogId', defaultValue: '') as String,
      'catalogItemName': box.get('catalogItemName', defaultValue: '') as String,
      'catalogName': box.get('catalogName', defaultValue: '') as String,
    };
  }

  static Future<bool> hasDraft() async {
    final box = await _openBox();
    final name = box.get('name', defaultValue: '') as String;
    return name.isNotEmpty;
  }

  /// 등록 완료 후 호출 — draft 데이터는 유지하되 완료 플래그만 세움
  static Future<void> markCompleted() async {
    final box = await _openBox();
    await box.put('completed', true);
  }

  /// draft가 등록 완료된 굿즈인지 여부
  static Future<bool> isCompleted() async {
    final box = await _openBox();
    return box.get('completed', defaultValue: false) as bool;
  }

  static Future<void> clearDraft() async {
    final box = await _openBox();
    await box.clear();
  }
}
