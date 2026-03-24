import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/catalog_item.dart';
import '../../../shared/utils/constants.dart';
import '../../../shared/utils/profanity_filter.dart';
import '../../../shared/widgets/widgets.dart';
import '../../goods/services/goods_service.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/widgets/pro_upsell_dialog.dart';
import '../services/catalog_service.dart';

class CatalogItemFormScreen extends ConsumerStatefulWidget {
  final String catalogId;
  final CatalogItem? existingItem;
  final String? characterId;

  const CatalogItemFormScreen({
    super.key,
    required this.catalogId,
    this.existingItem,
    this.characterId,
  });

  @override
  ConsumerState<CatalogItemFormScreen> createState() =>
      _CatalogItemFormScreenState();
}

class _CatalogItemFormScreenState extends ConsumerState<CatalogItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _photoUrl;
  XFile? _newPhoto;
  bool _isLoading = false;
  bool _quickAddMode = false;
  bool _hasAdded = false;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.existingItem!;
      _nameController.text = item.name;
      _descriptionController.text = item.description ?? '';
      _photoUrl = item.photoUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _newPhoto = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final desc = _descriptionController.text.trim();
    if (desc.isNotEmpty && ProfanityFilter.containsProfanity(desc)) {
      DuckSnackBar.error(context, '설명에 부적절한 표현이 포함되어 있어요');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(catalogServiceProvider);

      // Upload photo if new
      String? photoUrl = _photoUrl;
      if (_newPhoto != null) {
        final bytes = await _newPhoto!.readAsBytes();
        photoUrl = await service.uploadPhoto(bytes, _newPhoto!.name);
      }

      if (_isEditing) {
        await service.updateItem(widget.existingItem!.id, {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'photo_url': photoUrl,
        });
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final subService = ref.read(subscriptionServiceProvider);
        await service.addItem(
          catalogId: widget.catalogId,
          characterId: widget.characterId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          photoUrl: photoUrl,
          subscriptionService: subService,
        );

        _hasAdded = true;

        if (_quickAddMode) {
          // Reset for next item
          _nameController.clear();
          _descriptionController.clear();
          setState(() {
            _newPhoto = null;
            _photoUrl = null;
          });
          if (mounted) {
            DuckSnackBar.success(context, '아이템이 추가되었어요!');
          }
        } else {
          if (mounted) Navigator.of(context).pop(true);
        }
      }
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
        DuckSnackBar.error(context, '저장에 실패했어요');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _hasAdded) {
          // Result handled via _hasAdded
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? '아이템 수정' : '아이템 추가'),
          leading: IconButton(
            icon: const Icon(PhosphorIconsBold.x),
            onPressed: () => Navigator.of(context).pop(_hasAdded),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Quick add toggle (only for create mode)
              if (!_isEditing) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '빠른 추가 모드',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '저장 후 계속 아이템을 추가할 수 있어요',
                            style: TextStyle(
                              fontSize: 12,
                              color: DuckColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _quickAddMode,
                      onChanged: (v) => setState(() => _quickAddMode = v),
                      activeTrackColor: DuckColors.primary,
                    ),
                  ],
                ),
                const Divider(height: 24),
              ],

              // Photo
              _buildPhotoSection(),
              const SizedBox(height: 20),

              // Name
              DuckTextField(
                label: '아이템 이름',
                hint: '예: 탄지로 피규어 Vol.1',
                controller: _nameController,
                validator: (v) {
                if (v == null || v.trim().isEmpty) return '아이템 이름을 입력해주세요';
                return ProfanityFilter.validate(v);
              },
              ),
              const SizedBox(height: 16),

              // Description
              DuckTextField(
                label: '설명 (선택)',
                hint: '추가 정보가 있다면 적어주세요',
                controller: _descriptionController,
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Submit
              SizedBox(
                width: double.infinity,
                child: DuckButton(
                  text: _isEditing
                      ? '수정 완료'
                      : _quickAddMode
                          ? '추가하고 계속'
                          : '추가하기',
                  onPressed: _submit,
                  isLoading: _isLoading,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('사진 (선택)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _newPhoto != null
                ? FutureBuilder<List<int>>(
                    future: _newPhoto!.readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Image.memory(
                          snapshot.data! as dynamic,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        );
                      }
                      return _photoPlaceholder();
                    },
                  )
                : _photoUrl != null
                    ? Image.network(
                        _photoUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _photoPlaceholder(),
                      )
                    : _photoPlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
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
          Icon(PhosphorIconsBold.camera, size: 32, color: DuckColors.textSub),
          SizedBox(height: 8),
          Text(
            '탭하여 사진 추가',
            style: TextStyle(fontSize: 13, color: DuckColors.textSub),
          ),
        ],
      ),
    );
  }
}
