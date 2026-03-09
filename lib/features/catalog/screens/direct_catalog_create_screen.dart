import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/catalog_service.dart';
import '../widgets/catalog_setup_form.dart';
import 'catalog_detail_screen.dart';

/// 직접 만들기 화면 — 작품 선택 없이 CatalogSetupForm 사용
class DirectCatalogCreateScreen extends ConsumerStatefulWidget {
  const DirectCatalogCreateScreen({super.key});

  @override
  ConsumerState<DirectCatalogCreateScreen> createState() =>
      _DirectCatalogCreateScreenState();
}

class _DirectCatalogCreateScreenState
    extends ConsumerState<DirectCatalogCreateScreen> {
  Future<void> _createCatalog({
    required String name,
    required String? category,
    required String? workTag,
    required String visibility,
    required List<CharacterSetupData> characters,
    required String? coverUrl,
    required XFile? newCoverPhoto,
    required double coverFitY,
  }) async {
    final service = ref.read(catalogServiceProvider);

    String? finalCoverUrl = coverUrl;
    if (newCoverPhoto != null) {
      final bytes = await newCoverPhoto.readAsBytes();
      finalCoverUrl = await service.uploadPhoto(bytes, newCoverPhoto.name);
    }

    // Upload character photos
    final charData = <Map<String, dynamic>>[];
    for (final c in characters) {
      String? photoUrl = c.photoUrl;
      if (c.newPhotoFile != null) {
        final bytes = await c.newPhotoFile!.readAsBytes();
        photoUrl = await service.uploadPhoto(bytes, c.newPhotoFile!.name);
      }
      charData.add({
        'name': c.name,
        'photo_url': photoUrl,
        'external_id': c.externalId,
        'items': c.items
            .where((i) => i.name.trim().isNotEmpty)
            .map((i) => {'name': i.name})
            .toList(),
      });
    }

    final catalog = await service.createCatalogWithCharacters(
      name: name,
      category: category,
      workTag: workTag,
      coverUrl: finalCoverUrl,
      coverFitY: coverFitY,
      visibility: visibility,
      characters: charData,
    );

    if (mounted) {
      ref.invalidate(myCatalogsProvider);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CatalogDetailScreen(catalogId: catalog.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('도감 만들기'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CatalogSetupForm(
        characters: const [],
        onSubmit: _createCatalog,
      ),
    );
  }
}
