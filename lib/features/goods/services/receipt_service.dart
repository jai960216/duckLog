import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/receipt.dart';
import '../../auth/services/auth_service.dart';
import '../../subscription/services/subscription_service.dart';
import 'goods_service.dart';

final receiptServiceProvider = Provider<ReceiptService>((ref) {
  return ReceiptService(ref.read(supabaseClientProvider));
});

final receiptFilterProvider = StateProvider<ReceiptFilter>((ref) {
  return const ReceiptFilter();
});

final receiptListProvider =
    FutureProvider.autoDispose<List<Receipt>>((ref) async {
  final service = ref.read(receiptServiceProvider);
  final filter = ref.watch(receiptFilterProvider);
  return await service.getReceipts(filter: filter);
});

class ReceiptFilter {
  final String? category;
  final String? purchaseChannel;
  final String? expenseType;
  final String? searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;

  const ReceiptFilter({
    this.category,
    this.purchaseChannel,
    this.expenseType,
    this.searchQuery,
    this.startDate,
    this.endDate,
  });

  bool get hasActiveFilters =>
      category != null ||
      purchaseChannel != null ||
      expenseType != null ||
      (searchQuery != null && searchQuery!.isNotEmpty) ||
      startDate != null ||
      endDate != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptFilter &&
          category == other.category &&
          purchaseChannel == other.purchaseChannel &&
          expenseType == other.expenseType &&
          searchQuery == other.searchQuery &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(
      category, purchaseChannel, expenseType, searchQuery, startDate, endDate);

  ReceiptFilter copyWith({
    String? category,
    String? purchaseChannel,
    String? expenseType,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    bool clearCategory = false,
    bool clearPurchaseChannel = false,
    bool clearExpenseType = false,
    bool clearSearchQuery = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return ReceiptFilter(
      category: clearCategory ? null : (category ?? this.category),
      purchaseChannel: clearPurchaseChannel
          ? null
          : (purchaseChannel ?? this.purchaseChannel),
      expenseType:
          clearExpenseType ? null : (expenseType ?? this.expenseType),
      searchQuery:
          clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }
}

class ReceiptService {
  final SupabaseClient _client;

  ReceiptService(this._client);

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.id;
  }

  /// Upload receipt photo to private bucket and return signed URL
  Future<String> uploadReceiptPhoto(Uint8List bytes, String fileName,
      {SubscriptionService? subscriptionService}) async {
    // Check photo upload limit for free users
    final subService = subscriptionService ?? SubscriptionService(_client);
    final canUpload = await subService.checkCanUploadPhoto();
    if (!canUpload) {
      throw PhotoLimitExceededException();
    }

    final ext = fileName.split('.').last;
    final path = '$_userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from('receipt-photos').uploadBinary(path, bytes);

    // Increment photo usage counter
    await subService.incrementPhotoUsage();

    // Private bucket → use signed URL (valid for 1 year)
    final signedUrl = await _client.storage
        .from('receipt-photos')
        .createSignedUrl(path, 60 * 60 * 24 * 365);

    return signedUrl;
  }

  /// Create a receipt record
  Future<Receipt> createReceipt({
    required String photoUrl,
    Map<String, dynamic>? extractedData,
    int? totalAmount,
    String? storeName,
    DateTime? purchasedAt,
    String? category,
    String? purchaseChannel,
    String? expenseType,
    String? memo,
  }) async {
    final data = {
      'user_id': _userId,
      'photo_url': photoUrl,
      'extracted_data': extractedData,
      'total_amount': totalAmount,
      'store_name': storeName,
      'purchased_at': purchasedAt?.toIso8601String().split('T').first,
      'is_processed': false,
      if (category != null) 'category': category,
      if (purchaseChannel != null) 'purchase_channel': purchaseChannel,
      if (expenseType != null) 'expense_type': expenseType,
      if (memo != null) 'memo': memo,
    };

    final response =
        await _client.from('receipts').insert(data).select().single();
    return Receipt.fromJson(response);
  }

  /// Get all receipts for current user, newest first, with optional filters
  Future<List<Receipt>> getReceipts({ReceiptFilter? filter}) async {
    var query = _client.from('receipts').select().eq('user_id', _userId);

    if (filter != null) {
      if (filter.category != null) {
        query = query.eq('category', filter.category!);
      }
      if (filter.purchaseChannel != null) {
        query = query.eq('purchase_channel', filter.purchaseChannel!);
      }
      if (filter.expenseType != null) {
        query = query.eq('expense_type', filter.expenseType!);
      }
      if (filter.startDate != null) {
        query = query.gte('purchased_at',
            filter.startDate!.toIso8601String().split('T').first);
      }
      if (filter.endDate != null) {
        query = query.lte('purchased_at',
            filter.endDate!.toIso8601String().split('T').first);
      }
      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        // Escape PostgREST special characters in search query
        final escaped = filter.searchQuery!
            .replaceAll(r'\', r'\\')
            .replaceAll('%', r'\%')
            .replaceAll('_', r'\_')
            .replaceAll(',', r'\,')
            .replaceAll('(', r'\(')
            .replaceAll(')', r'\)');
        final q = '%$escaped%';
        query = query.or('store_name.ilike.$q,memo.ilike.$q');
      }
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List).map((e) => Receipt.fromJson(e)).toList();
  }

  /// Get a single receipt by ID
  Future<Receipt> getReceiptById(String id) async {
    final response =
        await _client.from('receipts').select().eq('id', id).single();
    return Receipt.fromJson(response);
  }

  /// Extract storage path from a signed URL
  String? _extractSignedStoragePath(String url, String bucket) {
    // Signed URL format: .../storage/v1/object/sign/<bucket>/<path>?token=...
    final marker = '/storage/v1/object/sign/$bucket/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    final pathWithQuery = url.substring(idx + marker.length);
    final qIdx = pathWithQuery.indexOf('?');
    return qIdx == -1 ? pathWithQuery : pathWithQuery.substring(0, qIdx);
  }

  /// Delete a receipt
  Future<void> deleteReceipt(String id) async {
    // Fetch receipt to get photo_url before deleting
    try {
      final receipt = await getReceiptById(id);
      final storagePath =
          _extractSignedStoragePath(receipt.photoUrl, 'receipt-photos');
      if (storagePath != null) {
        await _client.storage.from('receipt-photos').remove([storagePath]);
      }
    } catch (_) {
      // If fetching receipt or deleting photo fails, still proceed with DB deletion
    }
    await _client.from('receipts').delete().eq('id', id);
  }
}
