import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/ocr_catalog_service.dart';
import '../services/catalog_service.dart';
import 'catalog_detail_screen.dart';

class OcrImportScreen extends ConsumerStatefulWidget {
  const OcrImportScreen({super.key});

  @override
  ConsumerState<OcrImportScreen> createState() => _OcrImportScreenState();
}

class _OcrImportScreenState extends ConsumerState<OcrImportScreen> {
  final _nameController = TextEditingController();
  String? _selectedCategory;
  final List<String> _items = [];
  final _itemAddController = TextEditingController();
  bool _isExtracting = false;
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _itemAddController.dispose();
    super.dispose();
  }

  bool _isPicking = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() {
        _isExtracting = true;
        _errorMessage = null;
      });

      try {
        final service = ref.read(ocrCatalogServiceProvider);
        final bytes = await picked.readAsBytes();
        final extracted = await service.extractItemsFromImage(bytes);
        setState(() {
          _items.addAll(extracted);
          _isExtracting = false;
        });
      } catch (e) {
        setState(() {
          _isExtracting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      _isPicking = false;
    }
  }

  void _addItem() {
    final text = _itemAddController.text.trim();
    if (text.isNotEmpty) {
      setState(() => _items.add(text));
      _itemAddController.clear();
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _editItem(int index) async {
    final controller = TextEditingController(text: _items[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('아이템 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '아이템 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() => _items[index] = result);
    }
  }

  Future<void> _createCatalog() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      DuckSnackBar.info(context, '도감 이름을 입력해주세요');
      return;
    }
    if (_items.isEmpty) {
      DuckSnackBar.info(context, '아이템을 1개 이상 추가해주세요');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final service = ref.read(catalogServiceProvider);
      final itemMaps = _items
          .map((name) => {'name': name} as Map<String, dynamic>)
          .toList();

      final catalog = await service.createCatalogWithItems(
        name: name,
        category: _selectedCategory,
        items: itemMaps,
      );

      if (mounted) {
        ref.invalidate(myCatalogsProvider);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CatalogDetailScreen(catalogId: catalog.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '도감 생성에 실패했어요: $e');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이미지에서 추출'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Image picker section
          _buildImageSection(),
          const SizedBox(height: 20),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DuckColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsBold.warning,
                      size: 18, color: DuckColors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          fontSize: 13, color: DuckColors.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Items list
          _buildItemsSection(),
          const SizedBox(height: 20),

          // Catalog info
          DuckTextField(
            label: '도감 이름',
            hint: '예: 귀멸의 칼날 피규어 체크리스트',
            controller: _nameController,
          ),
          const SizedBox(height: 16),

          // Category
          _buildCategorySelector(),
          const SizedBox(height: 28),

          // Create button
          SizedBox(
            width: double.infinity,
            child: DuckButton(
              text: '도감 만들기 (${_items.length}개)',
              onPressed: _items.isNotEmpty ? _createCatalog : null,
              isLoading: _isCreating,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    if (_isExtracting) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: DuckColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('이미지에서 아이템 추출 중...',
                style: TextStyle(fontSize: 13, color: DuckColors.textSub)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이미지 선택', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        const Text(
          '체크리스트나 목록이 담긴 이미지를 선택하면 자동으로 아이템을 추출해요',
          style: TextStyle(fontSize: 12, color: DuckColors.textSub),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _imagePickerButton(
                icon: PhosphorIconsBold.image,
                label: '갤러리',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _imagePickerButton(
                icon: PhosphorIconsBold.camera,
                label: '카메라',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _imagePickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: DuckColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DuckColors.textLight, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: DuckColors.textSub),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: DuckColors.textSub)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('아이템 목록 (${_items.length}개)',
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (_items.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _items.clear()),
                child: const Text('전체 삭제',
                    style: TextStyle(fontSize: 12, color: DuckColors.error)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Add item row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _itemAddController,
                decoration: const InputDecoration(
                  hintText: '아이템 직접 추가',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addItem(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addItem,
              icon: const Icon(PhosphorIconsBold.plusCircle,
                  color: DuckColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Item list
        if (_items.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: DuckColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  title: Text(_items[index],
                      style: const TextStyle(fontSize: 14)),
                  leading: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        fontSize: 12, color: DuckColors.textSub),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(PhosphorIconsBold.pencil,
                            size: 16, color: DuckColors.textSub),
                        onPressed: () => _editItem(index),
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: const Icon(PhosphorIconsBold.x,
                            size: 16, color: DuckColors.error),
                        onPressed: () => _removeItem(index),
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('카테고리', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
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
      ],
    );
  }
}
