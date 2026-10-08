import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:market_jango/features/buyer/screens/order/data/buyer_quantity_changes_api.dart';
import 'package:market_jango/features/buyer/screens/order/model/buyer_quantity_change_models.dart';

final buyerQuantityChangesPageProvider = StateProvider<int>((ref) => 1);

final buyerPendingQuantityChangesProvider =
    FutureProvider.autoDispose<BuyerPendingQuantityChangesPayload>((ref) async {
  final page = ref.watch(buyerQuantityChangesPageProvider);
  return BuyerQuantityChangesApi.instance.fetchPending(page: page);
});

/// First-page total for badges (orders / profile).
final buyerPendingQuantityChangesCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final payload = await BuyerQuantityChangesApi.instance.fetchPending(page: 1);
  return payload.page.total;
});
