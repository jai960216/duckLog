import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../shared/utils/constants.dart';
import '../../../shared/widgets/widgets.dart';
import '../../goods/services/goods_service.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/widgets/pro_upsell_dialog.dart';
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
    required List<String> categories,
    required String? workTag,
    required String visibility,
    required List<CharacterSetupData> characters,
    required String? coverUrl,
    required XFile? newCoverPhoto,
    required double coverFitX,
    required double coverFitY,
    required double coverScale,
  }) async {
    try {
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
              .map((i) => {'name': i.name, 'category': i.category})
              .toList(),
        });
      }

      final catalog = await service.createCatalogWithCharacters(
        name: name,
        categories: categories,
        workTag: workTag,
        coverUrl: finalCoverUrl,
        coverFitX: coverFitX,
        coverFitY: coverFitY,
        coverScale: coverScale,
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
    } on PhotoLimitExceededException {
      if (mounted) {
        ProUpsellDialog.show(context, feature: '무료 플랜에서는 사진을 ${AppConstants.freePhotoLimit}장까지 업로드할 수 있어요.');
      }
    } on CatalogItemLimitExceededException {
      if (mounted) {
        ProUpsellDialog.show(context, feature: '무료 플랜에서는 도감당 아이템을 ${AppConstants.freeCatalogItemLimit}개까지 추가할 수 있어요.');
      }
    } on CatalogLimitExceededException {
      if (mounted) {
        ProUpsellDialog.show(context, feature: '무료 플랜에서는 도감을 ${AppConstants.freeCatalogLimit}개까지 만들 수 있어요.');
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '도감 생성에 실패했어요: $e');
      }
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
        isPro: ref.read(isProProvider).valueOrNull ?? false,
        onSubmit: _createCatalog,
      ),
    );
  }
}
