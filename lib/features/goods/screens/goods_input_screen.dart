import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/widgets/widgets.dart';
import '../../catalog/services/catalog_service.dart';
import '../services/goods_service.dart';
import '../widgets/catalog_item_picker.dart';

class GoodsInputScreen extends ConsumerStatefulWidget {
  final Goods? existingGoods; // null = create, non-null = edit

  const GoodsInputScreen({super.key, this.existingGoods});

  @override
  ConsumerState<GoodsInputScreen> createState() => _GoodsInputScreenState();
}

class _GoodsInputScreenState extends ConsumerState<GoodsInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _workTagController = TextEditingController();
  final _artistTagController = TextEditingController();
  final _purchasePlaceController = TextEditingController();
  final _memoController = TextEditingController();

  String? _selectedCategory;
  DateTime? _purchasedAt;
  String _visibility = 'public';
  final List<String> _photoUrls = [];
  final List<XFile> _newPhotos = [];
  bool _isLoading = false;

  // Catalog linking
  String? _linkedCatalogItemId;
  String? _linkedCatalogId;
  String? _linkedItemName;
  String? _linkedCatalogName;

  bool get _isEditing => widget.existingGoods != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final g = widget.existingGoods!;
      _nameController.text = g.name;
      _priceController.text = g.price?.toString() ?? '';
      _workTagController.text = g.workTag ?? '';
      _artistTagController.text = g.artistTag ?? '';
      _purchasePlaceController.text = g.purchasePlace ?? '';
      _memoController.text = g.memo ?? '';
      _selectedCategory = g.category;
      _purchasedAt = g.purchasedAt;
      _visibility = g.visibility;
      _photoUrls.addAll(g.photoUrls);
      if (g.catalogItemId != null) {
        _linkedCatalogItemId = g.catalogItemId;
        _loadLinkedCatalogInfo(g.catalogItemId!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _workTagController.dispose();
    _artistTagController.dispose();
    _purchasePlaceController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedCatalogInfo(String itemId) async {
    try {
      final catalogService = ref.read(catalogServiceProvider);
      final result = await catalogService.getCatalogForItem(itemId);
      if (result != null && mounted) {
        setState(() {
          _linkedCatalogId = result.$1.id;
          _linkedCatalogName = result.$1.name;
          _linkedItemName = result.$2.name;
          _visibility = result.$1.visibility;
          if (result.$1.category != null) {
            _selectedCategory = result.$1.category;
          }
          if (result.$1.workTag != null) {
            _workTagController.text = result.$1.workTag!;
          }
          if (result.$3 != null) {
            _artistTagController.text = result.$3!;
          }
        });
      }
    } catch (_) {
      // silently fail - info is cosmetic
    }
  }

  Future<void> _pickCatalogItem() async {
    final result = await showCatalogItemPicker(context);
    if (result != null && mounted) {
      setState(() {
        _linkedCatalogItemId = result.itemId;
        _linkedCatalogId = result.catalogId;
        _linkedItemName = result.itemName;
        _linkedCatalogName = result.catalogName;
        // 도감 공개범위 동기화
        _visibility = result.visibility;
        // 카테고리 동기화
        if (result.category != null) {
          _selectedCategory = result.category;
        }
        // 작품/콘텐츠 동기화
        if (result.workTag != null) {
          _workTagController.text = result.workTag!;
        }
        // 캐릭터명 동기화
        if (result.characterName != null) {
          _artistTagController.text = result.characterName!;
        }
      });
    }
  }

  void _clearCatalogLink() {
    setState(() {
      _linkedCatalogItemId = null;
      _linkedCatalogId = null;
      _linkedItemName = null;
      _linkedCatalogName = null;
      // 잠금 해제 → 유저가 다시 자유롭게 설정 가능
      _selectedCategory = null;
      _workTagController.clear();
      _artistTagController.clear();
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _newPhotos.add(picked));
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _newPhotos.add(picked));
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _purchasedAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: DuckColors.primary,
              onPrimary: DuckColors.outline,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _purchasedAt = date);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(goodsServiceProvider);

      // Upload new photos
      final uploadedUrls = <String>[];
      for (final photo in _newPhotos) {
        final bytes = await photo.readAsBytes();
        final url = await service.uploadPhoto(bytes, photo.name);
        uploadedUrls.add(url);
      }

      final allPhotoUrls = [..._photoUrls, ...uploadedUrls];
      final price = _priceController.text.isNotEmpty
          ? int.tryParse(_priceController.text.replaceAll(',', ''))
          : null;

      if (_isEditing) {
        await service.updateGoods(widget.existingGoods!.id, {
          'name': _nameController.text.trim(),
          'price': price,
          'category': _selectedCategory,
          'work_tag': _workTagController.text.trim().isEmpty
              ? null
              : _workTagController.text.trim(),
          'artist_tag': _artistTagController.text.trim().isEmpty
              ? null
              : _artistTagController.text.trim(),
          'photo_urls': allPhotoUrls,
          'purchased_at': _purchasedAt?.toIso8601String().split('T').first,
          'purchase_place': _purchasePlaceController.text.trim().isEmpty
              ? null
              : _purchasePlaceController.text.trim(),
          'memo': _memoController.text.trim().isEmpty
              ? null
              : _memoController.text.trim(),
          'visibility': _visibility,
          'catalog_item_id': _linkedCatalogItemId,
        });
      } else {
        await service.createGoods(
          name: _nameController.text.trim(),
          price: price,
          category: _selectedCategory,
          workTag: _workTagController.text.trim().isEmpty
              ? null
              : _workTagController.text.trim(),
          artistTag: _artistTagController.text.trim().isEmpty
              ? null
              : _artistTagController.text.trim(),
          photoUrls: allPhotoUrls,
          purchasedAt: _purchasedAt,
          purchasePlace: _purchasePlaceController.text.trim().isEmpty
              ? null
              : _purchasePlaceController.text.trim(),
          memo: _memoController.text.trim().isEmpty
              ? null
              : _memoController.text.trim(),
          visibility: _visibility,
          catalogItemId: _linkedCatalogItemId,
        );
      }

      // Auto-collect linked catalog item
      if (_linkedCatalogItemId != null && _linkedCatalogId != null) {
        try {
          final catalogService = ref.read(catalogServiceProvider);
          debugPrint('[GOODS] collectItem: catalogId=$_linkedCatalogId, itemId=$_linkedCatalogItemId');
          await catalogService.collectItem(
              _linkedCatalogId!, _linkedCatalogItemId!);
          debugPrint('[GOODS] collectItem success');
          // Sync photo if goods has photos
          if (allPhotoUrls.isNotEmpty) {
            await catalogService.updateItemPhotoIfEmpty(
                _linkedCatalogItemId!, allPhotoUrls.first);
          }
          // Invalidate catalog providers so progress updates
          ref.invalidate(myCatalogsProvider);
        } catch (e) {
          debugPrint('[GOODS] collectItem FAILED: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('저장에 실패했어요: $e');
      if (mounted) {
        DuckSnackBar.error(context, '저장에 실패했어요');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '굿즈 수정' : '굿즈 등록'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Photos
            _buildPhotoSection(),
            const SizedBox(height: 20),

            // Name
            DuckTextField(
              label: '품목명',
              hint: '어떤 굿즈인가요?',
              controller: _nameController,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '품목명을 입력해주세요' : null,
            ),
            const SizedBox(height: 16),

            // Price
            DuckTextField(
              label: '금액',
              hint: '0',
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefix: const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(PhosphorIconsBold.currencyKrw, size: 18),
              ),
            ),
            const SizedBox(height: 16),

            // Catalog link
            _buildCatalogLinkSection(),
            const SizedBox(height: 16),

            // Category
            _buildCategorySelector(),
            const SizedBox(height: 16),

            // Work tag
            DuckTextField(
              label: '작품/콘텐츠',
              hint: '예: 귀멸의 칼날, 블루 아카이브',
              controller: _workTagController,
              readOnly: _linkedCatalogItemId != null && _workTagController.text.isNotEmpty,
              suffix: _linkedCatalogItemId != null && _workTagController.text.isNotEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Tooltip(
                        message: '도감에서 수정해주세요',
                        child: Icon(PhosphorIconsBold.lock, size: 16, color: DuckColors.textLight),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),

            // Artist tag
            DuckTextField(
              label: '아티스트/캐릭터',
              hint: '예: 탄지로, 아리스',
              controller: _artistTagController,
              readOnly: _linkedCatalogItemId != null && _artistTagController.text.isNotEmpty,
              suffix: _linkedCatalogItemId != null && _artistTagController.text.isNotEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Tooltip(
                        message: '도감에서 수정해주세요',
                        child: Icon(PhosphorIconsBold.lock, size: 16, color: DuckColors.textLight),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),

            // Date
            _buildDatePicker(),
            const SizedBox(height: 16),

            // Purchase Place
            DuckTextField(
              label: '구매 장소',
              hint: '예: 애니메이트, 쿠팡, 일본 현지',
              controller: _purchasePlaceController,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(PhosphorIconsBold.mapPin, size: 18),
              ),
            ),
            const SizedBox(height: 16),

            // Memo
            DuckTextField(
              label: '메모',
              hint: '기록하고 싶은 내용이 있나요?',
              controller: _memoController,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Visibility
            _buildVisibilitySelector(),
            const SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              child: DuckButton(
                text: _isEditing ? '수정 완료' : '등록하기',
                onPressed: _submit,
                isLoading: _isLoading,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('사진', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add photo button
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(PhosphorIconsBold.camera),
                            title: const Text('카메라로 촬영'),
                            onTap: () {
                              Navigator.pop(context);
                              _takePhoto();
                            },
                          ),
                          ListTile(
                            leading: const Icon(PhosphorIconsBold.images),
                            title: const Text('갤러리에서 선택'),
                            onTap: () {
                              Navigator.pop(context);
                              _pickImage();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: DuckColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: DuckColors.textLight,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIconsBold.plus, color: DuckColors.textSub),
                      SizedBox(height: 4),
                      Text(
                        '사진 추가',
                        style: TextStyle(
                          fontSize: 11,
                          color: DuckColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Existing photos
              ..._photoUrls.map((url) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _photoUrls.remove(url)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: DuckColors.outline,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PhosphorIconsBold.x,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              // New photos (not uploaded yet) - show as FutureBuilder for XFile
              ..._newPhotos.map((xfile) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: FutureBuilder<Uint8List>(
                            future: xfile.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(
                                width: 100,
                                height: 100,
                                color: DuckColors.surface,
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _newPhotos.remove(xfile)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: DuckColors.outline,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PhosphorIconsBold.x,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final locked = _linkedCatalogItemId != null && _selectedCategory != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('카테고리', style: Theme.of(context).textTheme.titleSmall),
            if (locked) ...[
              const SizedBox(width: 8),
              const Text(
                '(도감 설정에 따라 자동 적용)',
                style: TextStyle(fontSize: 11, color: DuckColors.textLight),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        IgnorePointer(
          ignoring: locked,
          child: Opacity(
            opacity: locked ? 0.5 : 1.0,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Goods.categories.map((cat) {
                return DuckChip(
                  label: Goods.categoryLabel(cat),
                  selected: _selectedCategory == cat,
                  onTap: () => setState(() {
                    _selectedCategory = _selectedCategory == cat ? null : cat;
                  }),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('구매일', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: DuckColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DuckColors.surface, width: 2),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsBold.calendar,
                    size: 18, color: DuckColors.textSub),
                const SizedBox(width: 12),
                Text(
                  _purchasedAt != null
                      ? '${_purchasedAt!.year}.${_purchasedAt!.month.toString().padLeft(2, '0')}.${_purchasedAt!.day.toString().padLeft(2, '0')}'
                      : '날짜를 선택해주세요',
                  style: TextStyle(
                    color: _purchasedAt != null
                        ? DuckColors.text
                        : DuckColors.textLight,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('도감 연결', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (_linkedCatalogItemId != null &&
            _linkedCatalogName != null &&
            _linkedItemName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: DuckColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DuckColors.primary, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsBold.books,
                    size: 16, color: DuckColors.primaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$_linkedCatalogName > $_linkedItemName',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: _clearCatalogLink,
                  child: const Icon(PhosphorIconsBold.x,
                      size: 16, color: DuckColors.textSub),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: _pickCatalogItem,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: DuckColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DuckColors.surface, width: 2),
              ),
              child: const Row(
                children: [
                  Icon(PhosphorIconsBold.link,
                      size: 18, color: DuckColors.textSub),
                  SizedBox(width: 12),
                  Text(
                    '도감 아이템 연결',
                    style: TextStyle(
                      color: DuckColors.textLight,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVisibilitySelector() {
    final locked = _linkedCatalogItemId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('공개 범위', style: Theme.of(context).textTheme.titleSmall),
            if (locked) ...[
              const SizedBox(width: 8),
              const Text(
                '(도감 설정에 따라 자동 적용)',
                style: TextStyle(fontSize: 11, color: DuckColors.textLight),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        IgnorePointer(
          ignoring: locked,
          child: Opacity(
            opacity: locked ? 0.5 : 1.0,
            child: Row(
              children: [
                _visibilityChip('public', '전체 공개', PhosphorIconsBold.globe),
                const SizedBox(width: 8),
                _visibilityChip('friends', '친구 공개', PhosphorIconsBold.users),
                const SizedBox(width: 8),
                _visibilityChip('private', '비공개', PhosphorIconsBold.lock),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _visibilityChip(String value, String label, IconData icon) {
    final selected = _visibility == value;
    return GestureDetector(
      onTap: () => setState(() => _visibility = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? DuckColors.primaryLight : DuckColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? Border.all(color: DuckColors.primary, width: 2)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: DuckColors.text),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
