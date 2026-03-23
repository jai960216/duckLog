import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/utils/constants.dart';
import '../../auth/services/auth_service.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(ref.read(supabaseClientProvider));
});

final subscriptionProvider =
    FutureProvider.autoDispose<Subscription>((ref) async {
  final service = ref.read(subscriptionServiceProvider);
  return await service.getSubscription();
});

final isProProvider = FutureProvider.autoDispose<bool>((ref) async {
  final sub = await ref.watch(subscriptionProvider.future);
  return sub.isPro;
});

final photoUsageProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.read(subscriptionServiceProvider);
  return await service.getPhotoUsage();
});

final catalogCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.read(subscriptionServiceProvider);
  return await service.getCatalogCount();
});

class SubscriptionService {
  final SupabaseClient _client;

  SubscriptionService(this._client);

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.id;
  }

  Future<Subscription> getSubscription() async {
    final response = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) {
      return Subscription.free(_userId);
    }
    return Subscription.fromJson(response);
  }

  Future<int> getPhotoUsage() async {
    final result = await _client.rpc('get_photo_usage');
    return (result as int?) ?? 0;
  }

  Future<int> getCatalogCount() async {
    final response = await _client
        .from('catalogs')
        .select('id')
        .eq('user_id', _userId);
    return (response as List).length;
  }

  Future<bool> checkCanUploadPhoto() async {
    final sub = await getSubscription();
    if (sub.isPro) return true;

    final usage = await getPhotoUsage();
    return usage < AppConstants.freePhotoLimit;
  }

  Future<bool> checkCanCreateCatalog() async {
    final sub = await getSubscription();
    if (sub.isPro) return true;

    final count = await getCatalogCount();
    return count < AppConstants.freeCatalogLimit;
  }

  Future<int> getCatalogItemCount(String catalogId) async {
    final response = await _client
        .from('catalog_items')
        .select('id')
        .eq('catalog_id', catalogId);
    return (response as List).length;
  }

  Future<bool> checkCanAddCatalogItem(String catalogId) async {
    final sub = await getSubscription();
    if (sub.isPro) return true;

    final count = await getCatalogItemCount(catalogId);
    return count < AppConstants.freeCatalogItemLimit;
  }

  Future<void> cancelSubscription() async {
    await _client
        .from('subscriptions')
        .delete()
        .eq('user_id', _userId);
  }

  Future<void> incrementPhotoUsage() async {
    await _client.rpc('increment_photo_usage');
  }
}
