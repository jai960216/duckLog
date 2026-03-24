import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import 'subscription_service.dart';

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(ref.read(supabaseClientProvider), ref);
});

class PurchaseService {
  final SupabaseClient _client;
  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// 검증 성공/실패 콜백 (UI 알림용, optional)
  void Function(bool success)? onVerificationComplete;

  static const String proMonthlyId = 'ducklog_pro_monthly';
  static const String proYearlyId = 'ducklog_pro_yearly';
  static const Set<String> _productIds = {proMonthlyId, proYearlyId};

  PurchaseService(this._client, this._ref);

  /// 구매 스트림 리스닝 시작 (항상 기존 구독 취소 후 재생성)
  void startListening() {
    _subscription?.cancel();
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
    _subscription = null;
  }

  /// 완전 초기화 (로그아웃 시 사용)
  void reset() {
    _subscription?.cancel();
    _subscription = null;
    onVerificationComplete = null;
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
      if (kDebugMode) debugPrint('Purchase status: ${purchase.status.name}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndDeliver(purchase);
          break;
        case PurchaseStatus.error:
          if (kDebugMode) debugPrint('Purchase error: ${purchase.error?.message}');
          break;
        case PurchaseStatus.pending:
          break;
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
      // 세션 갱신 시도
      try {
        await _client.auth.refreshSession();
      } catch (_) {}

      if (_client.auth.currentUser == null) {
        if (kDebugMode) debugPrint('Verify skipped: not logged in');
        return;
      }

      if (kDebugMode) {
        debugPrint('Verifying purchase: ${purchase.productID}');
        debugPrint('Purchase status: ${purchase.status}');
        debugPrint('Token: ${purchase.verificationData.serverVerificationData.substring(0, 20)}...');
      }

      final response = await _client.functions.invoke(
        'verify-purchase',
        body: {
          'product_id': purchase.productID,
          'purchase_token': purchase.verificationData.serverVerificationData,
        },
      );

      if (kDebugMode) {
        debugPrint('Verify response status: ${response.status}');
        debugPrint('Verify response data: ${response.data}');
      }

      if (response.status == 200) {
        // Always invalidate providers regardless of callback
        _ref.invalidate(subscriptionProvider);
        _ref.invalidate(isProProvider);
        onVerificationComplete?.call(true);
      } else {
        if (kDebugMode) debugPrint('Verify failed: ${response.data}');
        onVerificationComplete?.call(false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Verify error: $e');
      onVerificationComplete?.call(false);
    }
  }
}
