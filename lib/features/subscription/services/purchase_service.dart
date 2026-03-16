import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(ref.read(supabaseClientProvider));
});

class PurchaseService {
  final SupabaseClient _client;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  static const String proMonthlyId = 'ducklog_pro_monthly';
  static const String proYearlyId = 'ducklog_pro_yearly';
  static const Set<String> _productIds = {proMonthlyId, proYearlyId};

  PurchaseService(this._client);

  /// 구매 스트림 리스닝 시작
  void startListening() {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        if (kDebugMode) debugPrint('Purchase stream error: $error');
      },
    );
  }

  /// 리스닝 종료
  void dispose() {
    _subscription?.cancel();
  }

  /// 상품 정보 조회
  Future<List<ProductDetails>> getProducts() async {
    final available = await _iap.isAvailable();
    if (!available) return [];

    final response = await _iap.queryProductDetails(_productIds);
    if (response.error != null) {
      if (kDebugMode) debugPrint('Product query error: ${response.error}');
    }
    return response.productDetails;
  }

  /// 구매 실행
  Future<bool> purchase(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      if (kDebugMode) debugPrint('Purchase failed: $e');
      return false;
    }
  }

  /// 구매 복원
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// 구매 업데이트 처리
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndDeliver(purchase);
          break;
        case PurchaseStatus.error:
          if (kDebugMode) debugPrint('Purchase error: ${purchase.error}');
          break;
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// 서버에서 영수증 검증 후 구독 활성화
  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _client.functions.invoke(
        'verify-purchase',
        body: {
          'user_id': userId,
          'product_id': purchase.productID,
          'purchase_token': purchase.verificationData.serverVerificationData,
          'source': purchase.verificationData.source,
        },
      );

      if (response.status != 200) {
        if (kDebugMode) {
          debugPrint('Verification failed: ${response.data}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Verify error: $e');
    }
  }
}
