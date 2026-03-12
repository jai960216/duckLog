import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/catalog.dart';
import '../../../shared/models/catalog_character.dart';
import '../../../shared/models/catalog_item.dart';
import '../../auth/services/auth_service.dart';

final catalogServiceProvider = Provider<CatalogService>((ref) {
  return CatalogService(ref.read(supabaseClientProvider));
});

final myCatalogsProvider =
    FutureProvider.autoDispose<List<Catalog>>((ref) async {
  final service = ref.read(catalogServiceProvider);
  return await service.getMyCatalogs();
});

final publicCatalogsProvider =
    FutureProvider.autoDispose<List<Catalog>>((ref) async {
  final service = ref.read(catalogServiceProvider);
  return await service.getPublicCatalogs();
});

final catalogItemsProvider =
    FutureProvider.autoDispose.family<List<CatalogItem>, String>(
  (ref, catalogId) async {
    final service = ref.read(catalogServiceProvider);
    return await service.getItems(catalogId);
  },
);

final catalogCharactersProvider =
    FutureProvider.autoDispose.family<List<CatalogCharacter>, String>(
  (ref, catalogId) async {
    final service = ref.read(catalogServiceProvider);
    return await service.getCharacters(catalogId);
  },
);

final catalogGroupedItemsProvider = FutureProvider.autoDispose
    .family<({List<CatalogCharacter> characters, List<CatalogItem> ungrouped}), String>(
  (ref, catalogId) async {
    final service = ref.read(catalogServiceProvider);
    return await service.getGroupedItems(catalogId);
  },
);

/// 아이템 ID → (Catalog, CatalogItem, characterName?) 조회 (굿즈 상세에서 도감 링크 표시용)
final catalogForItemProvider = FutureProvider.autoDispose
    .family<(Catalog, CatalogItem, String?)?, String>(
  (ref, itemId) async {
    final service = ref.read(catalogServiceProvider);
    return await service.getCatalogForItem(itemId);
  },
);

class CatalogService {
  final SupabaseClient _client;

  CatalogService(this._client);

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.id;
  }

  // ── Catalog CRUD ──

  Future<Catalog> createCatalog({
    required String name,
    String? description,
    String? category,
    String? workTag,
    String? coverUrl,
    double coverFitY = 0.5,
    String visibility = 'private',
  }) async {
    final data = {
      'user_id': _userId,
      'name': name,
      'description': description,
      'category': category,
      'work_tag': workTag,
      'cover_url': coverUrl,
      'cover_fit_y': coverFitY,
      'visibility': visibility,
    };
    final response =
        await _client.from('catalogs').insert(data).select().single();
    return Catalog.fromJson(response);
  }

  Future<List<Catalog>> getMyCatalogs() async {
    final response = await _client
        .from('catalogs')
        .select()
        .eq('user_id', _userId)
        .order('updated_at', ascending: false);

    final catalogs = <Catalog>[];
    for (final row in response as List) {
      var catalog = Catalog.fromJson(row);
      final progress = await _getCatalogProgress(catalog.id);
      catalog = catalog.copyWith(
        totalItems: progress['total'],
        collectedItems: progress['collected'],
      );
      catalogs.add(catalog);
    }
    return catalogs;
  }

  Future<List<Catalog>> getPublicCatalogs() async {
    final response = await _client
        .from('catalogs')
        .select()
        .eq('visibility', 'public')
        .neq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(50);

    final catalogs = <Catalog>[];
    for (final row in response as List) {
      var catalog = Catalog.fromJson(row);
      final progress = await _getCatalogProgress(catalog.id);
      catalog = catalog.copyWith(
        totalItems: progress['total'],
        collectedItems: progress['collected'],
      );
      catalogs.add(catalog);
    }
    return catalogs;
  }

  Future<Catalog> getCatalogById(String id) async {
    final response =
        await _client.from('catalogs').select().eq('id', id).single();
    var catalog = Catalog.fromJson(response);
    final progress = await _getCatalogProgress(catalog.id);
    catalog = catalog.copyWith(
      totalItems: progress['total'],
      collectedItems: progress['collected'],
    );
    return catalog;
  }

  Future<Catalog> updateCatalog(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    final response = await _client
        .from('catalogs')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    // 공개 설정 변경 시 연결된 굿즈도 함께 변경
    if (updates.containsKey('visibility')) {
      final newVisibility = updates['visibility'] as String;
      final itemIds = await _client
          .from('catalog_items')
          .select('id')
          .eq('catalog_id', id);
      final ids = (itemIds as List).map((r) => r['id'] as String).toList();
      if (ids.isNotEmpty) {
        await _client
            .from('goods')
            .update({'visibility': newVisibility})
            .inFilter('catalog_item_id', ids);
      }
    }

    return Catalog.fromJson(response);
  }

  Future<void> deleteCatalog(String id) async {
    await _client.from('catalogs').delete().eq('id', id);
  }

  // ── Character CRUD ──

  Future<CatalogCharacter> addCharacter({
    required String catalogId,
    required String name,
    String? photoUrl,
    String? externalId,
    int sortOrder = 0,
  }) async {
    final data = {
      'catalog_id': catalogId,
      'name': name,
      'photo_url': photoUrl,
      'external_id': externalId,
      'sort_order': sortOrder,
    };
    final response = await _client
        .from('catalog_characters')
        .insert(data)
        .select()
        .single();
    await _client.from('catalogs').update(
      {'updated_at': DateTime.now().toIso8601String()},
    ).eq('id', catalogId);
    return CatalogCharacter.fromJson(response);
  }

  Future<List<CatalogCharacter>> getCharacters(String catalogId) async {
    try {
      final response = await _client
          .from('catalog_characters')
          .select()
          .eq('catalog_id', catalogId)
          .order('sort_order', ascending: true);
      final chars = (response as List)
          .map((row) => CatalogCharacter.fromJson(row))
          .toList();
      // Dart-side sort as safety net
      chars.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return chars;
    } on PostgrestException {
      // Table might not exist yet (migration not applied)
      return [];
    }
  }

  Future<CatalogCharacter> updateCharacter(
      String id, Map<String, dynamic> updates) async {
    final response = await _client
        .from('catalog_characters')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return CatalogCharacter.fromJson(response);
  }

  Future<void> deleteCharacter(String id) async {
    await _client.from('catalog_characters').delete().eq('id', id);
  }

  // ── Grouped Items ──

  Future<({List<CatalogCharacter> characters, List<CatalogItem> ungrouped})>
      getGroupedItems(String catalogId) async {
    final characters = await getCharacters(catalogId);
    final items = await getItems(catalogId);

    if (characters.isEmpty) {
      return (characters: <CatalogCharacter>[], ungrouped: items);
    }

    // Group items by character_id
    final charMap = <String, List<CatalogItem>>{};
    final ungrouped = <CatalogItem>[];

    for (final item in items) {
      if (item.characterId != null) {
        charMap.putIfAbsent(item.characterId!, () => []).add(item);
      } else {
        ungrouped.add(item);
      }
    }

    final groupedChars = characters.map((ch) {
      final charItems = charMap[ch.id] ?? [];
      final collected = charItems.where((i) => i.isCollected).length;
      return ch.copyWith(
        items: charItems,
        totalItems: charItems.length,
        collectedItems: collected,
      );
    }).toList();

    return (characters: groupedChars, ungrouped: ungrouped);
  }

  // ── Item CRUD ──

  Future<CatalogItem> addItem({
    required String catalogId,
    required String name,
    String? characterId,
    String? description,
    String? photoUrl,
    int sortOrder = 0,
  }) async {
    final data = {
      'catalog_id': catalogId,
      'character_id': characterId,
      'name': name,
      'description': description,
      'photo_url': photoUrl,
      'sort_order': sortOrder,
    };
    final response =
        await _client.from('catalog_items').insert(data).select().single();
    // Touch catalog updated_at
    await _client.from('catalogs').update(
      {'updated_at': DateTime.now().toIso8601String()},
    ).eq('id', catalogId);
    return CatalogItem.fromJson(response);
  }

  Future<List<CatalogItem>> getItems(String catalogId) async {
    final response = await _client
        .from('catalog_items')
        .select()
        .eq('catalog_id', catalogId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    // Get user's collection status for these items
    final collectionResponse = await _client
        .from('catalog_collections')
        .select('catalog_item_id, collected_at')
        .eq('user_id', _userId)
        .eq('catalog_id', catalogId);

    final collectedMap = <String, DateTime>{};
    for (final row in collectionResponse as List) {
      collectedMap[row['catalog_item_id'] as String] =
          DateTime.parse(row['collected_at'] as String);
    }

    return (response as List).map((row) {
      final item = CatalogItem.fromJson(row);
      final collectedAt = collectedMap[item.id];
      return item.copyWith(
        isCollected: collectedAt != null,
        collectedAt: collectedAt,
      );
    }).toList();
  }

  Future<CatalogItem> updateItem(
      String id, Map<String, dynamic> updates) async {
    final response = await _client
        .from('catalog_items')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return CatalogItem.fromJson(response);
  }

  Future<void> deleteItem(String id) async {
    await _client.from('catalog_items').delete().eq('id', id);
  }

  // ── Collection Toggle ──

  Future<bool> toggleCollection(String catalogId, String itemId) async {
    // Check if already collected
    final existing = await _client
        .from('catalog_collections')
        .select('id')
        .eq('user_id', _userId)
        .eq('catalog_item_id', itemId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('catalog_collections')
          .delete()
          .eq('id', existing['id'] as String);
      return false; // uncollected
    } else {
      await _client.from('catalog_collections').insert({
        'user_id': _userId,
        'catalog_id': catalogId,
        'catalog_item_id': itemId,
      });
      return true; // collected
    }
  }

  // ── Progress ──

  Future<Map<String, int>> _getCatalogProgress(String catalogId) async {
    final itemsResponse = await _client
        .from('catalog_items')
        .select('id')
        .eq('catalog_id', catalogId);
    final total = (itemsResponse as List).length;

    final collectedResponse = await _client
        .from('catalog_collections')
        .select('id')
        .eq('user_id', _userId)
        .eq('catalog_id', catalogId);
    final collected = (collectedResponse as List).length;

    return {'total': total, 'collected': collected};
  }

  // ── Batch Create ──

  /// 도감 생성 + 아이템 일괄 추가
  /// [items]는 각 아이템의 {name, description?, photo_url?} 맵 리스트
  Future<Catalog> createCatalogWithItems({
    required String name,
    String? description,
    String? category,
    String? workTag,
    String? coverUrl,
    double coverFitY = 0.5,
    String visibility = 'private',
    required List<Map<String, dynamic>> items,
  }) async {
    // 1. 도감 생성
    final catalog = await createCatalog(
      name: name,
      description: description,
      category: category,
      workTag: workTag,
      coverUrl: coverUrl,
      coverFitY: coverFitY,
      visibility: visibility,
    );

    // 2. 아이템 일괄 추가
    if (items.isNotEmpty) {
      final rows = items.asMap().entries.map((entry) {
        final item = entry.value;
        return {
          'catalog_id': catalog.id,
          'name': item['name'] as String,
          'description': item['description'] as String?,
          'photo_url': item['photo_url'] as String?,
          'sort_order': entry.key,
        };
      }).toList();

      await _client.from('catalog_items').insert(rows);
    }

    return catalog.copyWith(totalItems: items.length);
  }

  /// 도감 생성 + 캐릭터 + 아이템 일괄 추가
  /// [characters] 는 [{name, photoUrl?, externalId?, items: [{name, photoUrl?}]}]
  Future<Catalog> createCatalogWithCharacters({
    required String name,
    String? description,
    String? category,
    String? workTag,
    String? coverUrl,
    double coverFitY = 0.5,
    String visibility = 'private',
    required List<Map<String, dynamic>> characters,
  }) async {
    // 1. 도감 생성
    final catalog = await createCatalog(
      name: name,
      description: description,
      category: category,
      workTag: workTag,
      coverUrl: coverUrl,
      coverFitY: coverFitY,
      visibility: visibility,
    );

    int totalItems = 0;

    // 2. 캐릭터 batch insert — 테이블 없으면 flat items fallback
    try {
      for (int ci = 0; ci < characters.length; ci++) {
        final charData = characters[ci];
        final charResponse = await _client.from('catalog_characters').insert({
          'catalog_id': catalog.id,
          'name': charData['name'] as String,
          'photo_url': charData['photo_url'] as String?,
          'external_id': charData['external_id'] as String?,
          'sort_order': ci,
        }).select().single();

        final charId = charResponse['id'] as String;

        // 3. 아이템 batch insert per character
        final items =
            charData['items'] as List<Map<String, dynamic>>? ?? [];
        if (items.isNotEmpty) {
          final rows = items.asMap().entries.map((entry) {
            final item = entry.value;
            return {
              'catalog_id': catalog.id,
              'character_id': charId,
              'name': item['name'] as String,
              'photo_url': item['photo_url'] as String?,
              'sort_order': entry.key,
            };
          }).toList();
          await _client.from('catalog_items').insert(rows);
          totalItems += items.length;
        }
      }
    } on PostgrestException {
      // catalog_characters 테이블 미생성 → flat items로 fallback
      int sortIdx = 0;
      for (final charData in characters) {
        final items =
            charData['items'] as List<Map<String, dynamic>>? ?? [];
        for (final item in items) {
          final charName = charData['name'] as String;
          final itemName = item['name'] as String;
          await _client.from('catalog_items').insert({
            'catalog_id': catalog.id,
            'name': '$charName - $itemName',
            'photo_url': charData['photo_url'] as String?,
            'sort_order': sortIdx++,
          });
          totalItems++;
        }
      }
    }

    return catalog.copyWith(totalItems: totalItems);
  }

  // ── Goods ↔ Catalog Linking ──

  /// 멱등 수집: 이미 수집이면 무시
  Future<void> collectItem(String catalogId, String itemId) async {
    final existing = await _client
        .from('catalog_collections')
        .select('id')
        .eq('user_id', _userId)
        .eq('catalog_item_id', itemId)
        .maybeSingle();
    if (existing != null) return; // already collected
    await _client.from('catalog_collections').insert({
      'user_id': _userId,
      'catalog_id': catalogId,
      'catalog_item_id': itemId,
    });
  }

  /// 유저의 전체 도감→캐릭터→아이템 계층 조회 (피커용)
  Future<List<({Catalog catalog, List<CatalogCharacter> characters, List<CatalogItem> ungrouped})>>
      getMyItemsGrouped() async {
    final catalogs = await getMyCatalogs();
    final results =
        <({Catalog catalog, List<CatalogCharacter> characters, List<CatalogItem> ungrouped})>[];

    for (final catalog in catalogs) {
      final grouped = await getGroupedItems(catalog.id);
      results.add((
        catalog: catalog,
        characters: grouped.characters,
        ungrouped: grouped.ungrouped,
      ));
    }
    return results;
  }

  /// 아이템 사진 없으면 굿즈 사진으로 동기화
  Future<void> updateItemPhotoIfEmpty(String itemId, String photoUrl) async {
    final item = await _client
        .from('catalog_items')
        .select('photo_url')
        .eq('id', itemId)
        .maybeSingle();
    if (item == null) return;
    if (item['photo_url'] != null && (item['photo_url'] as String).isNotEmpty) {
      return; // already has photo
    }
    await _client
        .from('catalog_items')
        .update({'photo_url': photoUrl})
        .eq('id', itemId);
  }

  /// 아이템 ID로 도감+아이템+캐릭터명 정보 조회 (상세 표시용)
  Future<(Catalog, CatalogItem, String?)?> getCatalogForItem(String itemId) async {
    final itemRow = await _client
        .from('catalog_items')
        .select()
        .eq('id', itemId)
        .maybeSingle();
    if (itemRow == null) return null;
    final item = CatalogItem.fromJson(itemRow);

    final catalogRow = await _client
        .from('catalogs')
        .select()
        .eq('id', item.catalogId)
        .maybeSingle();
    if (catalogRow == null) return null;
    final catalog = Catalog.fromJson(catalogRow);

    // 캐릭터명 조회
    String? characterName;
    if (item.characterId != null) {
      final charRow = await _client
          .from('catalog_characters')
          .select('name')
          .eq('id', item.characterId!)
          .maybeSingle();
      characterName = charRow?['name'] as String?;
    }

    return (catalog, item, characterName);
  }

  // ── Photo Upload ──

  Future<String> uploadPhoto(Uint8List bytes, String fileName) async {
    final ext = fileName.split('.').last.toLowerCase();
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    final path = '$_userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from('catalog-photos').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    return _client.storage.from('catalog-photos').getPublicUrl(path);
  }
}
