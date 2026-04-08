import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/catalog_character.dart';
import '../../../shared/models/catalog_item.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/utils/constants.dart';
import '../../../shared/utils/image_quality.dart';
import '../../../shared/utils/profanity_filter.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/services/auth_service.dart';
import '../../goods/services/goods_service.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/widgets/pro_upsell_dialog.dart';
import '../services/catalog_service.dart';
import '../widgets/catalog_item_tile.dart';
import '../widgets/catalog_setup_form.dart';
import '../widgets/character_group_section.dart';
import 'catalog_export_screen.dart';
import 'catalog_item_form_screen.dart';
import 'card_type_select_screen.dart';

class CatalogDetailScreen extends ConsumerStatefulWidget {
  final String catalogId;
  /// 다른 유저의 도감을 볼 때 소유자 ID를 전달 (null이면 내 도감)
  final String? ownerUserId;

  const CatalogDetailScreen({
    super.key,
    required this.catalogId,
    this.ownerUserId,
  });

  @override
  ConsumerState<CatalogDetailScreen> createState() =>
      _CatalogDetailScreenState();
}

class _CatalogDetailScreenState extends ConsumerState<CatalogDetailScreen> {
  bool _changed = false;
  bool _isPicking = false;

  void _invalidateAll() {
    if (widget.ownerUserId != null) {
      ref.invalidate(catalogItemsForUserProvider(
          (catalogId: widget.catalogId, userId: widget.ownerUserId!)));
      ref.invalidate(catalogGroupedItemsForUserProvider(
          (catalogId: widget.catalogId, userId: widget.ownerUserId!)));
    } else {
      ref.invalidate(catalogItemsProvider(widget.catalogId));
      ref.invalidate(catalogGroupedItemsProvider(widget.catalogId));
    }
    if (mounted) setState(() => _changed = true);
  }

  /// 비소유자: 아이템 사진 크게 보기
  void _showItemPreview(CatalogItem item) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.6,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: item.photoUrl != null
                        ? Image.network(
                            item.photoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => _previewPlaceholder(),
                          )
                        : _previewPlaceholder(),
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: Colors.transparent,
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewPlaceholder() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: DuckColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(PhosphorIconsBold.image,
            size: 48, color: DuckColors.textSub),
      ),
    );
  }

  /// 아이템 탭 → 통합 옵션 시트
  void _onItemTap(CatalogItem item) {
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: DuckColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 수집 관련
            if (!item.isCollected) ...[
              if (item.photoUrl != null && item.photoUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(PhosphorIconsBold.checkCircle,
                      color: DuckColors.primary),
                  title: const Text('수집 확정'),
                  subtitle: const Text('현재 사진으로 수집 완료 처리해요'),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final service = ref.read(catalogServiceProvider);
                    await service.toggleCollection(
                        widget.catalogId, item.id);
                    _invalidateAll();
                    if (mounted) {
                      DuckSnackBar.success(context, '수집 완료!');
                    }
                  },
                ),
              ListTile(
                leading: const Icon(PhosphorIconsBold.camera),
                title: Text(item.photoUrl != null && item.photoUrl!.isNotEmpty
                    ? '사진 변경 후 수집'
                    : '사진 추가 후 수집'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickPhotoAndCollect(item);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(PhosphorIconsBold.camera),
                title: const Text('사진 변경'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickPhotoAndCollect(item);
                },
              ),
              ListTile(
                leading: const Icon(PhosphorIconsBold.x,
                    color: DuckColors.textSub),
                title: const Text('수집 해제'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final service = ref.read(catalogServiceProvider);
                  await service.toggleCollection(
                      widget.catalogId, item.id);
                  _invalidateAll();
                },
              ),
            ],
            const Divider(height: 1),
            // 편집/삭제
            ListTile(
              leading: const Icon(PhosphorIconsBold.pencil),
              title: const Text('편집'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _editItem(item.id);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.trash,
                  color: DuckColors.error),
              title: const Text('삭제',
                  style: TextStyle(color: DuckColors.error)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _deleteItem(item.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 사진 선택 → 업로드 → 수집 처리
  Future<void> _pickPhotoAndCollect(CatalogItem item) async {
    if (_isPicking) return;
    _isPicking = true;

    try {
      final picker = ImagePicker();
      final iq = ImageQualitySettings.fromPro(
          ref.read(isProProvider).valueOrNull ?? false);
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: iq.maxWidth,
        imageQuality: iq.quality,
      );
      if (picked == null) return;

      if (mounted) {
        DuckSnackBar.info(context, '사진 업로드 중...');
      }

      final service = ref.read(catalogServiceProvider);
      final bytes = await picked.readAsBytes();
      final photoUrl = await service.uploadPhoto(bytes, picked.name);

      await service.updateItem(item.id, {'photo_url': photoUrl});

      if (!item.isCollected) {
        await service.toggleCollection(widget.catalogId, item.id);
      }

      if (mounted) {
        DuckSnackBar.success(context, '수집 완료!');
      }
      _invalidateAll();
    } on PhotoLimitExceededException {
      if (mounted) {
        ProUpsellDialog.show(context, feature: '무료 플랜에서는 사진을 ${AppConstants.freePhotoLimit}장까지 업로드할 수 있어요.');
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '업로드에 실패했어요');
      }
    } finally {
      _isPicking = false;
    }
  }

  Future<void> _addItem({String? characterId, String? category}) async {
    // 카드 도감이면 카드 종류 선택 화면으로 이동
    if (category == 'card') {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              CardTypeSelectScreen(catalogId: widget.catalogId),
        ),
      );
      if (result == true) {
        _invalidateAll();
      }
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CatalogItemFormScreen(
          catalogId: widget.catalogId,
          characterId: characterId,
        ),
      ),
    );
    if (result == true) {
      _invalidateAll();
    }
  }

  Future<void> _editCatalog() async {
    final service = ref.read(catalogServiceProvider);
    final characters = await service.getCharacters(widget.catalogId);
    if (!mounted) return;
    await _editCharacterCatalog(characters);
  }

  void _exportAsImage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CatalogExportScreen(catalogId: widget.catalogId),
      ),
    );
  }

  Future<void> _editCharacterCatalog(
      List<CatalogCharacter> characters) async {
    final service = ref.read(catalogServiceProvider);
    final catalog = await service.getCatalogById(widget.catalogId);
    if (!mounted) return;

    // Get items for each character
    final items = await service.getItems(widget.catalogId);
    if (!mounted) return;

    // Build CharacterSetupData from existing data (with IDs for in-place update)
    final charSetupList = characters.map((ch) {
      final charItems = items
          .where((i) => i.characterId == ch.id)
          .map((i) => ItemSetupData(id: i.id, name: i.name, category: i.category))
          .toList();
      return CharacterSetupData(
        id: ch.id,
        name: ch.name,
        photoUrl: ch.photoUrl,
        externalId: ch.externalId,
        items: charItems,
      );
    }).toList();

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CharacterCatalogEditScreen(
          catalogId: widget.catalogId,
          initialName: catalog.name,
          initialCategories: catalog.categories,
          initialWorkTag: catalog.workTag,
          initialCoverUrl: catalog.coverUrl,
          initialCoverFitX: catalog.coverFitX,
          initialCoverFitY: catalog.coverFitY,
          initialCoverScale: catalog.coverScale,
          initialVisibility: catalog.visibility,
          characters: charSetupList,
        ),
      ),
    );
    if (result == true) {
      ref.invalidate(catalogItemsProvider(widget.catalogId));
      ref.invalidate(catalogGroupedItemsProvider(widget.catalogId));
      ref.invalidate(catalogCharactersProvider(widget.catalogId));
      setState(() => _changed = true);
    }
  }

  Future<void> _deleteCatalog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('도감 삭제'),
        content: const Text('이 도감을 삭제하시겠어요?\n포함된 아이템과 수집 기록이 모두 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: DuckColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(catalogServiceProvider);
      await service.deleteCatalog(widget.catalogId);
      ref.invalidate(myCatalogsProvider);
      ref.invalidate(publicCatalogsProvider);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _editItem(String itemId) async {
    final service = ref.read(catalogServiceProvider);
    final items = await service.getItems(widget.catalogId);
    final item = items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;
    if (!mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CatalogItemFormScreen(
          catalogId: widget.catalogId,
          existingItem: item,
          characterId: item.characterId,
        ),
      ),
    );
    if (result == true) {
      ref.invalidate(catalogItemsProvider(widget.catalogId));
      ref.invalidate(catalogGroupedItemsProvider(widget.catalogId));
      setState(() => _changed = true);
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('아이템 삭제'),
        content: const Text('이 아이템을 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: DuckColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(catalogServiceProvider);
      await service.deleteItem(itemId);
      ref.invalidate(catalogItemsProvider(widget.catalogId));
      ref.invalidate(catalogGroupedItemsProvider(widget.catalogId));
      if (!mounted) return;
      setState(() => _changed = true);
    }
  }

  void _showCharacterOptions(CatalogCharacter ch) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: DuckColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.pencil),
              title: const Text('이름 수정'),
              onTap: () {
                Navigator.pop(context);
                _renameCharacter(ch);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.trash,
                  color: DuckColors.error),
              title: const Text('삭제',
                  style: TextStyle(color: DuckColors.error)),
              subtitle: const Text('아이템은 미분류로 이동됩니다'),
              onTap: () {
                Navigator.pop(context);
                _deleteCharacter(ch);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameCharacter(CatalogCharacter ch) async {
    final nameController = TextEditingController(text: ch.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐릭터 이름 수정'),
        content: TextField(
          controller: nameController,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, nameController.text.trim()),
            child: const Text('수정'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 300), nameController.dispose);

    if (result != null && result.isNotEmpty) {
      if (ProfanityFilter.containsProfanity(result)) {
        if (mounted) DuckSnackBar.error(context, '부적절한 표현이 포함되어 있어요');
        return;
      }
      final service = ref.read(catalogServiceProvider);
      await service.updateCharacter(ch.id, {'name': result});
      ref.invalidate(catalogGroupedItemsProvider(widget.catalogId));
      ref.invalidate(catalogCharactersProvider(widget.catalogId));
      if (mounted) setState(() => _changed = true);
    }
  }

  Future<void> _deleteCharacter(CatalogCharacter ch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐릭터 삭제'),
        content: Text('${ch.name}을(를) 삭제하시겠어요?\n아이템은 미분류로 이동됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: DuckColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(catalogServiceProvider);
      await service.deleteCharacter(ch.id);
      ref.invalidate(catalogGroupedItemsProvider(widget.catalogId));
      ref.invalidate(catalogCharactersProvider(widget.catalogId));
      if (!mounted) return;
      setState(() => _changed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 소유자 ID가 있으면 해당 유저의 수집 상태를 조회하는 프로바이더 사용
    final asyncGrouped = widget.ownerUserId != null
        ? ref.watch(catalogGroupedItemsForUserProvider(
            (catalogId: widget.catalogId, userId: widget.ownerUserId!)))
        : ref.watch(catalogGroupedItemsProvider(widget.catalogId));
    final currentUser = ref.watch(currentUserProvider);

    return FutureBuilder(
      future:
          ref.read(catalogServiceProvider).getCatalogById(widget.catalogId),
      builder: (context, snapshot) {
        final catalog = snapshot.data;
        final isOwner = catalog != null &&
            currentUser != null &&
            catalog.userId == currentUser.id;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop && _changed) {
              // Parent will see result=true
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(catalog?.name ?? '도감'),
              leading: IconButton(
                icon: const Icon(PhosphorIconsBold.caretLeft),
                onPressed: () => Navigator.of(context).pop(_changed),
              ),
              actions: [
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: const Icon(PhosphorIconsBold.dotsThreeVertical),
                    onSelected: (value) {
                      if (value == 'add') _addItem(category: catalog.categories.isNotEmpty ? catalog.categories.first : null);
                      if (value == 'edit') _editCatalog();
                      if (value == 'export') _exportAsImage();
                      if (value == 'delete') _deleteCatalog();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'add',
                        child: Row(
                          children: [
                            const Icon(PhosphorIconsBold.plus, size: 18),
                            const SizedBox(width: 8),
                            Text(catalog.categories.contains('card')
                                ? '카드 추가'
                                : '아이템 추가'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(PhosphorIconsBold.pencil, size: 18),
                            SizedBox(width: 8),
                            Text('편집'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(PhosphorIconsBold.export, size: 18),
                            SizedBox(width: 8),
                            Text('이미지로 내보내기'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(PhosphorIconsBold.trash,
                                size: 18, color: DuckColors.error),
                            SizedBox(width: 8),
                            Text('삭제',
                                style: TextStyle(color: DuckColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            body: asyncGrouped.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류가 발생했어요: $e')),
              data: (grouped) {
                final hasCharacters = grouped.characters.isNotEmpty;
                final allItems = <dynamic>[
                  ...grouped.characters.expand((c) => c.items),
                  ...grouped.ungrouped,
                ];
                final collected = allItems
                    .where((i) => (i as dynamic).isCollected == true)
                    .length;
                final total = allItems.length;
                final pct =
                    total > 0 ? (collected / total * 100).toInt() : 0;

                return CustomScrollView(
                  slivers: [
                    // Header: info + progress
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (catalog?.description != null &&
                                catalog!.description!.isNotEmpty) ...[
                              Text(
                                catalog.description!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: DuckColors.textSub,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Tags
                            if ((catalog?.categories.isNotEmpty ?? false) ||
                                catalog?.workTag != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    ...?catalog?.categories.map((cat) =>
                                      DuckChip(
                                        label: Goods.categoryLabel(cat),
                                      ),
                                    ),
                                    if (catalog?.workTag != null)
                                      DuckChip(
                                          label: catalog!.workTag!),
                                  ],
                                ),
                              ),

                            // Progress bar
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: DuckColors.surface,
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                    children: [
                                      const Text(
                                        '수집 현황',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '$collected/$total ($pct%)',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              DuckColors.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    child:
                                        LinearProgressIndicator(
                                      value: total > 0
                                          ? collected / total
                                          : 0,
                                      backgroundColor: DuckColors
                                          .textLight
                                          .withValues(alpha: 0.3),
                                      valueColor:
                                          const AlwaysStoppedAnimation<
                                                  Color>(
                                              DuckColors.primary),
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    // Character groups OR flat grid
                    if (hasCharacters) ...[
                      // Character group sections
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final ch = grouped.characters[index];
                            return CharacterGroupSection(
                              character: ch,
                              isOwner: isOwner,
                              initiallyExpanded: index == 0,
                              onItemTap: isOwner ? _onItemTap : _showItemPreview,
                              onAddItem: isOwner
                                  ? () =>
                                      _addItem(characterId: ch.id)
                                  : null,
                              onLongPress: isOwner
                                  ? () =>
                                      _showCharacterOptions(ch)
                                  : null,
                            );
                          },
                          childCount: grouped.characters.length,
                        ),
                      ),

                      // Ungrouped items section
                      if (grouped.ungrouped.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                20, 16, 20, 8),
                            child: Text(
                              '미분류 (${grouped.ungrouped.length})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: DuckColors.textSub,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.75,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item =
                                    grouped.ungrouped[index];
                                return CatalogItemTile(
                                  item: item,
                                  onTap: isOwner
                                      ? () => _onItemTap(item)
                                      : () => _showItemPreview(item),
                                );
                              },
                              childCount:
                                  grouped.ungrouped.length,
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      // Flat grid for non-character catalogs
                      if (grouped.ungrouped.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              '아직 아이템이 없어요',
                              style: TextStyle(
                                fontSize: 14,
                                color: DuckColors.textSub,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.75,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item =
                                    grouped.ungrouped[index];
                                return CatalogItemTile(
                                  item: item,
                                  onTap: isOwner
                                      ? () => _onItemTap(item)
                                      : () => _showItemPreview(item),
                                );
                              },
                              childCount:
                                  grouped.ungrouped.length,
                            ),
                          ),
                        ),
                    ],

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

}

/// 캐릭터 기반 도감 편집 화면
class _CharacterCatalogEditScreen extends ConsumerStatefulWidget {
  final String catalogId;
  final String? initialName;
  final List<String> initialCategories;
  final String? initialWorkTag;
  final String? initialCoverUrl;
  final double initialCoverFitX;
  final double initialCoverFitY;
  final double initialCoverScale;
  final String initialVisibility;
  final List<CharacterSetupData> characters;

  const _CharacterCatalogEditScreen({
    required this.catalogId,
    this.initialName,
    this.initialCategories = const [],
    this.initialWorkTag,
    this.initialCoverUrl,
    this.initialCoverFitX = 0.5,
    this.initialCoverFitY = 0.5,
    this.initialCoverScale = 1.0,
    this.initialVisibility = 'private',
    required this.characters,
  });

  @override
  ConsumerState<_CharacterCatalogEditScreen> createState() =>
      _CharacterCatalogEditScreenState();
}

class _CharacterCatalogEditScreenState
    extends ConsumerState<_CharacterCatalogEditScreen> {
  bool _isLoading = false;

  Future<void> _onSubmit({
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
    setState(() => _isLoading = true);
    try {
      final service = ref.read(catalogServiceProvider);
      final subService = ref.read(subscriptionServiceProvider);

      // Upload cover if new photo selected
      String? finalCoverUrl = coverUrl;
      if (newCoverPhoto != null) {
        final bytes = await newCoverPhoto.readAsBytes();
        finalCoverUrl =
            await service.uploadPhoto(bytes, newCoverPhoto.name);
      }

      // 1. Update catalog metadata
      await service.updateCatalog(widget.catalogId, {
        'name': name,
        'category': categories.isNotEmpty ? categories.join(',') : null,
        'work_tag': workTag,
        'cover_url': finalCoverUrl,
        'cover_fit_x': coverFitX,
        'cover_fit_y': coverFitY,
        'cover_scale': coverScale,
        'visibility': visibility,
      });

      // 2. Get existing characters & items (한 번만 조회)
      final existingChars =
          await service.getCharacters(widget.catalogId);
      final allExistingItems =
          await service.getItems(widget.catalogId);

      // 3. Delete characters removed from the form
      final formCharIds = characters
          .where((c) => c.id != null)
          .map((c) => c.id!)
          .toSet();

      for (final ch in existingChars) {
        if (!formCharIds.contains(ch.id)) {
          await service.deleteCharacter(ch.id);
        }
      }

      // 4. Snapshot the desired order
      final orderedChars = List<CharacterSetupData>.of(characters);
      // 5. Update/create characters and items
      for (int ci = 0; ci < orderedChars.length; ci++) {
        final charData = orderedChars[ci];

        if (charData.id != null) {
          // ── Existing character: update name + sort_order + photo ──
          String? charPhotoUrl = charData.photoUrl;
          if (charData.newPhotoFile != null) {
            final photoBytes = await charData.newPhotoFile!.readAsBytes();
            charPhotoUrl = await service.uploadPhoto(
                photoBytes, charData.newPhotoFile!.name);
          }
          await service.updateCharacter(charData.id!, {
            'name': charData.name,
            'sort_order': ci,
            'photo_url': charPhotoUrl,
          });

          // Filter items for this character from the pre-fetched list
          final existingItems = allExistingItems
              .where((i) => i.characterId == charData.id)
              .toList();

          // Remove items deleted in the form
          final formItemIds = charData.items
              .where((i) => i.id != null)
              .map((i) => i.id!)
              .toSet();
          for (final item in existingItems) {
            if (!formItemIds.contains(item.id)) {
              await service.deleteItem(item.id);
            }
          }

          // Update existing / create new items
          for (int ii = 0; ii < charData.items.length; ii++) {
            final itemData = charData.items[ii];
            final itemName = itemData.name.trim();
            if (itemName.isEmpty) continue;

            if (itemData.id != null) {
              await service.updateItem(itemData.id!, {
                'name': itemName,
                'category': itemData.category,
                'sort_order': ii,
              });
            } else {
              await service.addItem(
                catalogId: widget.catalogId,
                characterId: charData.id,
                name: itemName,
                category: itemData.category,
                sortOrder: ii,
                subscriptionService: subService,
              );
            }
          }
        } else {
          // ── New character ──
          String? newCharPhotoUrl = charData.photoUrl;
          if (charData.newPhotoFile != null) {
            final photoBytes = await charData.newPhotoFile!.readAsBytes();
            newCharPhotoUrl = await service.uploadPhoto(
                photoBytes, charData.newPhotoFile!.name);
          }
          final ch = await service.addCharacter(
            catalogId: widget.catalogId,
            name: charData.name,
            photoUrl: newCharPhotoUrl,
            externalId: charData.externalId,
            sortOrder: ci,
          );

          for (int ii = 0; ii < charData.items.length; ii++) {
            final itemData = charData.items[ii];
            final itemName = itemData.name.trim();
            if (itemName.isNotEmpty) {
              await service.addItem(
                catalogId: widget.catalogId,
                characterId: ch.id,
                name: itemName,
                category: itemData.category,
                sortOrder: ii,
                subscriptionService: subService,
              );
            }
          }
        }
      }

      // 6. Force invalidate providers before popping
      ref.invalidate(catalogGroupedItemsProvider(widget.catalogId));
      ref.invalidate(catalogCharactersProvider(widget.catalogId));
      ref.invalidate(catalogItemsProvider(widget.catalogId));

      if (mounted) Navigator.of(context).pop(true);
    } on PhotoLimitExceededException {
      if (mounted) {
        ProUpsellDialog.show(context, feature: '무료 플랜에서는 사진을 ${AppConstants.freePhotoLimit}장까지 업로드할 수 있어요.');
      }
    } on CatalogItemLimitExceededException {
      if (mounted) {
        ProUpsellDialog.show(context, feature: '무료 플랜에서는 도감당 아이템을 ${AppConstants.freeCatalogItemLimit}개까지 추가할 수 있어요.');
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '수정에 실패했어요');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('도감 수정'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CatalogSetupForm(
        initialName: widget.initialName,
        initialCategories: widget.initialCategories,
        initialWorkTag: widget.initialWorkTag,
        initialCoverUrl: widget.initialCoverUrl,
        initialCoverFitX: widget.initialCoverFitX,
        initialCoverFitY: widget.initialCoverFitY,
        initialCoverScale: widget.initialCoverScale,
        initialVisibility: widget.initialVisibility,
        characters: widget.characters,
        isEditing: true,
        hideCharacters: widget.initialCategories.contains('card'),
        isPro: ref.read(isProProvider).valueOrNull ?? false,
        isLoading: _isLoading,
        onSubmit: _onSubmit,
      ),
    );
  }
}
