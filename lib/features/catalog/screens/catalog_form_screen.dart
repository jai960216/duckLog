import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/catalog.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/utils/image_quality.dart';
import '../../../shared/utils/profanity_filter.dart';
import '../../../shared/utils/constants.dart';
import '../../subscription/services/subscription_service.dart';
import '../../../shared/widgets/widgets.dart';
import '../../goods/services/goods_service.dart';
import '../../subscription/widgets/pro_upsell_dialog.dart';
import '../services/catalog_service.dart';

class CatalogFormScreen extends ConsumerStatefulWidget {
  final Catalog? existingCatalog;

  const CatalogFormScreen({super.key, this.existingCatalog});

  @override
  ConsumerState<CatalogFormScreen> createState() => _CatalogFormScreenState();
}

class _CatalogFormScreenState extends ConsumerState<CatalogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _workTagController = TextEditingController();

  List<String> _selectedCategories = [];
  String _visibility = 'private';
  String? _coverUrl;
  XFile? _newCoverPhoto;
  double _coverFitX = 0.5;
  double _coverFitY = 0.5;
  double _coverScale = 1.0;
  double _baseScale = 1.0;
  Uint8List? _cachedCoverBytes;
  bool _isPicking = false;
  bool _isLoading = false;

  bool get _isEditing => widget.existingCatalog != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.existingCatalog!;
      _nameController.text = c.name;
      _descriptionController.text = c.description ?? '';
      _workTagController.text = c.workTag ?? '';
      _selectedCategories = List<String>.from(c.categories);
      _visibility = c.visibility;
      _coverUrl = c.coverUrl;
      _coverFitX = c.coverFitX;
      _coverFitY = c.coverFitY;
      _coverScale = c.coverScale;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _workTagController.dispose();
    super.dispose();
  }

  ImageQualitySettings get _iq => ImageQualitySettings.fromPro(
      ref.read(isProProvider).valueOrNull ?? false);

  Future<void> _pickCoverImage() async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _iq.maxWidth,
        imageQuality: _iq.quality,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _newCoverPhoto = picked;
          _cachedCoverBytes = bytes;
          _coverFitX = 0.5;
          _coverFitY = 0.5;
          _coverScale = 1.0;
        });
      }
    } finally {
      _isPicking = false;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // 추가 텍스트 필드 금칙어 검사
    final fieldsToCheck = {
      '설명': _descriptionController.text.trim(),
      '작품/콘텐츠': _workTagController.text.trim(),
    };
    for (final entry in fieldsToCheck.entries) {
      if (entry.value.isNotEmpty && ProfanityFilter.containsProfanity(entry.value)) {
        DuckSnackBar.error(context, '${entry.key}에 부적절한 표현이 포함되어 있어요');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(catalogServiceProvider);

      // Upload cover photo if new
      String? coverUrl = _coverUrl;
      if (_newCoverPhoto != null) {
        final bytes = await _newCoverPhoto!.readAsBytes();
        coverUrl = await service.uploadPhoto(bytes, _newCoverPhoto!.name);
      }

      if (_isEditing) {
        await service.updateCatalog(widget.existingCatalog!.id, {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'category': _selectedCategories.isNotEmpty ? _selectedCategories.join(',') : null,
          'work_tag': _workTagController.text.trim().isEmpty
              ? null
              : _workTagController.text.trim(),
          'cover_url': coverUrl,
          'cover_fit_x': _coverFitX,
          'cover_fit_y': _coverFitY,
          'cover_scale': _coverScale,
          'visibility': _visibility,
        });
      } else {
        await service.createCatalog(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          categories: _selectedCategories,
          workTag: _workTagController.text.trim().isEmpty
              ? null
              : _workTagController.text.trim(),
          coverUrl: coverUrl,
          coverFitX: _coverFitX,
          coverFitY: _coverFitY,
          coverScale: _coverScale,
          visibility: _visibility,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } on PhotoLimitExceededException {
      if (mounted) {
        ProUpsellDialog.show(context, feature: '무료 플랜에서는 사진을 ${AppConstants.freePhotoLimit}장까지 업로드할 수 있어요.');
      }
    } on CatalogLimitExceededException {
      if (mounted) {
        ProUpsellDialog.show(context, feature: '무료 플랜에서는 도감을 ${AppConstants.freeCatalogLimit}개까지 만들 수 있어요.');
      }
    } catch (e) {
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
        title: Text(_isEditing ? '도감 수정' : '도감 만들기'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            20 + MediaQuery.of(context).viewPadding.bottom,
          ),
          children: [
            // Cover image
            _buildCoverSection(),
            const SizedBox(height: 20),

            // Name
            DuckTextField(
              label: '도감 이름',
              hint: '예: 귀멸의 칼날 피규어 컬렉션',
              controller: _nameController,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '도감 이름을 입력해주세요';
                return ProfanityFilter.validate(v);
              },
            ),
            const SizedBox(height: 16),

            // Description
            DuckTextField(
              label: '설명',
              hint: '어떤 도감인지 설명해주세요',
              controller: _descriptionController,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Category
            _buildCategorySelector(),
            const SizedBox(height: 16),

            // Work tag
            DuckTextField(
              label: '작품/콘텐츠',
              hint: '예: 귀멸의 칼날, 블루 아카이브',
              controller: _workTagController,
            ),
            const SizedBox(height: 16),

            // Visibility
            _buildVisibilitySelector(),
            const SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              child: DuckButton(
                text: _isEditing ? '수정 완료' : '만들기',
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

  Widget _buildCoverSection() {
    final hasCover = _newCoverPhoto != null || _coverUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('커버 이미지', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (hasCover)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _coverUrl = null;
                    _newCoverPhoto = null;
                    _cachedCoverBytes = null;
                    _coverFitX = 0.5;
                    _coverFitY = 0.5;
                    _coverScale = 1.0;
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(PhosphorIconsBold.x,
                      size: 18, color: DuckColors.textSub),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_cachedCoverBytes != null)
          _buildCropGuideOverlay(
            Image.memory(
              _cachedCoverBytes!,
              fit: BoxFit.cover,
              alignment: Alignment(0, _coverFitY * 2 - 1),
              width: double.infinity,
              height: 280,
            ),
          )
        else if (_coverUrl != null)
          _buildCropGuideOverlay(
            Image.network(
              _coverUrl!,
              fit: BoxFit.cover,
              alignment: Alignment(0, _coverFitY * 2 - 1),
              width: double.infinity,
              height: 280,
              errorBuilder: (_, _, _) =>
                  _coverPlaceholder(),
            ),
          )
        else
          GestureDetector(
            onTap: _pickCoverImage,
            child: _coverPlaceholder(),
          ),
        if (hasCover) ...[
          const SizedBox(height: 6),
          const Center(
            child: Text(
              '드래그 또는 핀치하여 커버 영역을 조정할 수 있어요',
              style: TextStyle(fontSize: 12, color: DuckColors.textSub),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCropGuideOverlay(Widget imageWidget) {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Stack(
        children: [
          // 드래그/핀치 영역
          Positioned.fill(
            child: RawGestureDetector(
              gestures: {
                _EagerScaleGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        _EagerScaleGestureRecognizer>(
                  () => _EagerScaleGestureRecognizer(),
                  (instance) {
                    instance
                      ..onStart = (_) {
                        _baseScale = _coverScale;
                      }
                      ..onUpdate = (details) {
                        setState(() {
                          _coverScale =
                              (_baseScale * details.scale).clamp(1.0, 3.0);
                          _coverFitX = (_coverFitX -
                                  details.focalPointDelta.dx /
                                      (280 * _coverScale))
                              .clamp(0.0, 1.0);
                          _coverFitY = (_coverFitY -
                                  details.focalPointDelta.dy /
                                      (280 * _coverScale))
                              .clamp(0.0, 1.0);
                        });
                      };
                  },
                ),
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxTx =
                        constraints.maxWidth * (_coverScale - 1) / 2;
                    final tx = (1 - _coverFitX * 2) * maxTx;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..translate(tx, 0.0)
                            ..scale(_coverScale, _coverScale),
                          child: imageWidget,
                        ),
                        // Top dark overlay
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 80,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                        // Bottom dark overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 80,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                        // Center cover area border + label
                        Positioned(
                          top: 80,
                          left: 0,
                          right: 0,
                          height: 120,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '커버에 표시되는 영역',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // 이미지 변경 버튼 (RawGestureDetector 바깥)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(PhosphorIconsBold.camera,
                    size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: DuckColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DuckColors.textLight, width: 2),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIconsBold.image, size: 32, color: DuckColors.textSub),
          SizedBox(height: 8),
          Text(
            '탭하여 커버 이미지 추가',
            style: TextStyle(fontSize: 13, color: DuckColors.textSub),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('카테고리', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        const Text(
          '여러 개 선택할 수 있어요',
          style: TextStyle(fontSize: 12, color: DuckColors.textSub),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Goods.categories.map((cat) {
            final selected = _selectedCategories.contains(cat);
            return DuckChip(
              label: Goods.categoryLabel(cat),
              selected: selected,
              onTap: () => setState(() {
                if (selected) {
                  _selectedCategories.remove(cat);
                } else {
                  _selectedCategories.add(cat);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVisibilitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('공개 범위', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            _visibilityChip('public', '전체 공개', PhosphorIconsBold.globe),
            const SizedBox(width: 8),
            _visibilityChip('friends', '친구 공개', PhosphorIconsBold.users),
            const SizedBox(width: 8),
            _visibilityChip('private', '비공개', PhosphorIconsBold.lock),
          ],
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

class _EagerScaleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
