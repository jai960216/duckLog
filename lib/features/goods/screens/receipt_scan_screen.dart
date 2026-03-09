import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../shared/models/goods.dart';
import '../../../shared/models/receipt.dart';
import '../../../shared/widgets/widgets.dart';
import '../services/receipt_service.dart';

enum _ScanState { idle, result }

class ReceiptScanScreen extends ConsumerStatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  ConsumerState<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends ConsumerState<ReceiptScanScreen> {
  XFile? _photo;
  Uint8List? _photoBytes;
  _ScanState _state = _ScanState.idle;

  // Extracted data fields
  final _storeNameController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _memoController = TextEditingController();
  DateTime? _purchasedAt;
  // New metadata fields
  String? _purchaseChannel;
  String? _expenseType;
  String? _category;

  @override
  void dispose() {
    _storeNameController.dispose();
    _totalAmountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1080,
      imageQuality: 90,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _photo = picked;
        _photoBytes = bytes;
        _state = _ScanState.result;
        _purchasedAt = DateTime.now();
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 90,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _photo = picked;
        _photoBytes = bytes;
        _state = _ScanState.result;
        _purchasedAt = DateTime.now();
      });
    }
  }

  Future<void> _saveAsReceipt() async {
    final service = ref.read(receiptServiceProvider);

    try {
      // Upload receipt photo to private bucket with signed URL
      String? photoUrl;
      if (_photoBytes != null && _photo != null) {
        photoUrl = await service.uploadReceiptPhoto(_photoBytes!, _photo!.name);
      }

      if (photoUrl == null) {
        if (mounted) {
          DuckSnackBar.info(context, '영수증 사진이 필요해요.');
        }
        return;
      }

      final amount =
          int.tryParse(_totalAmountController.text.replaceAll(',', ''));

      // Save as receipt (NOT goods)
      await service.createReceipt(
        photoUrl: photoUrl,
        totalAmount: amount,
        storeName: _storeNameController.text.isNotEmpty
            ? _storeNameController.text
            : null,
        purchasedAt: _purchasedAt,
        category: _category,
        purchaseChannel: _purchaseChannel,
        expenseType: _expenseType,
        memo: _memoController.text.isNotEmpty ? _memoController.text : null,
      );

      if (mounted) {
        DuckSnackBar.success(context, '영수증이 저장되었어요!');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        DuckSnackBar.error(context, '저장에 실패했어요: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('영수증 보관'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: switch (_state) {
        _ScanState.idle => _buildIdleState(),
        _ScanState.result => _buildResultState(),
      },
    );
  }

  Widget _buildIdleState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Duck with magnifying glass
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: DuckColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: DuckColors.outline, width: 3),
              ),
              child: const Center(
                child: Text('🔍🐥', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '영수증 사진을 찍거나\n갤러리에서 선택해요!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: DuckColors.textSub,
                  ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: DuckButton(
                text: '카메라로 촬영',
                icon: PhosphorIconsBold.camera,
                onPressed: _takePhoto,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: DuckButton(
                text: '갤러리에서 선택',
                icon: PhosphorIconsBold.images,
                isOutlined: true,
                onPressed: _pickPhoto,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipRow({
    required String label,
    required List<String> values,
    required String? selected,
    required String Function(String) labelBuilder,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: values
                .map((v) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DuckChip(
                        label: labelBuilder(v),
                        selected: selected == v,
                        onTap: () => onChanged(selected == v ? null : v),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildResultState() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Receipt image preview
        if (_photoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _photoBytes!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 20),

        Text(
          '영수증 정보를 입력해주세요',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),

        // 매장명
        DuckTextField(
          label: '매장명',
          hint: '매장 이름',
          controller: _storeNameController,
        ),
        const SizedBox(height: 16),

        // 총 금액
        DuckTextField(
          label: '총 금액',
          hint: '0',
          controller: _totalAmountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          prefix: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(PhosphorIconsBold.currencyKrw, size: 18),
          ),
        ),
        const SizedBox(height: 20),

        // 구매 채널
        _buildChipRow(
          label: '구매 채널',
          values: Receipt.purchaseChannels,
          selected: _purchaseChannel,
          labelBuilder: Receipt.purchaseChannelLabel,
          onChanged: (v) => setState(() => _purchaseChannel = v),
        ),
        const SizedBox(height: 16),

        // 지출 유형
        _buildChipRow(
          label: '지출 유형',
          values: Receipt.expenseTypes,
          selected: _expenseType,
          labelBuilder: Receipt.expenseTypeLabel,
          onChanged: (v) => setState(() => _expenseType = v),
        ),
        const SizedBox(height: 16),

        // 굿즈 카테고리 (지출 유형이 'goods'일 때만)
        if (_expenseType == 'goods') ...[
          _buildChipRow(
            label: '굿즈 카테고리',
            values: Goods.categories,
            selected: _category,
            labelBuilder: Goods.categoryLabel,
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 16),
        ],

        // 메모
        DuckTextField(
          label: '메모',
          hint: '자유롭게 메모를 남겨보세요',
          controller: _memoController,
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: DuckButton(
            text: '영수증 저장',
            onPressed: _saveAsReceipt,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: DuckButton(
            text: '다시 촬영',
            isOutlined: true,
            onPressed: () {
              setState(() {
                _photo = null;
                _photoBytes = null;
                _state = _ScanState.idle;
                _purchaseChannel = null;
                _expenseType = null;
                _category = null;
                _memoController.clear();
              });
            },
          ),
        ),
      ],
    );
  }
}
