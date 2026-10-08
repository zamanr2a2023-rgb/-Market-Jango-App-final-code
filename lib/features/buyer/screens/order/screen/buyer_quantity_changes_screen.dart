import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/utils/image_controller.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/buyer/screens/order/data/buyer_quantity_changes_api.dart';
import 'package:market_jango/features/buyer/screens/order/model/buyer_quantity_change_models.dart';
import 'package:market_jango/features/buyer/screens/order/provider/buyer_quantity_changes_provider.dart';
import 'package:market_jango/features/buyer/screens/wallet/provider/buyer_wallet_provider.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';

/// Pending vendor quantity reductions — buyer accept flow.
class BuyerQuantityChangesScreen extends ConsumerStatefulWidget {
  const BuyerQuantityChangesScreen({super.key});

  static const routeName = '/buyer/quantity-changes';

  @override
  ConsumerState<BuyerQuantityChangesScreen> createState() =>
      _BuyerQuantityChangesScreenState();
}

class _BuyerQuantityChangesScreenState
    extends ConsumerState<BuyerQuantityChangesScreen> {
  final Set<int> _acceptingIds = {};

  Future<void> _refresh() async {
    ref.invalidate(buyerPendingQuantityChangesProvider);
    ref.invalidate(buyerPendingQuantityChangesCountProvider);
    await ref.read(buyerPendingQuantityChangesProvider.future);
  }

  Future<void> _accept(BuyerQuantityChangeRequestItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept quantity change?'),
        content: Text(
          'Order ${item.orderNumber.isEmpty ? "#${item.invoiceItemId}" : item.orderNumber}: '
          'quantity ${item.currentQuantity} → ${item.proposedQuantity}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _acceptingIds.add(item.id));
    try {
      final result = await BuyerQuantityChangesApi.instance.accept(
        invoiceItemId: item.invoiceItemId,
        requestId: item.id,
      );
      if (!mounted) return;
      final walletMsg = result.autoRefund?.walletCreditMessage();
      GlobalSnackbar.show(
        context,
        title: 'Accepted',
        message: walletMsg ?? 'Quantity updated.',
        type: CustomSnackType.success,
      );
      ref.invalidate(buyerWalletOverviewProvider);
      ref.invalidate(buyerWalletTransactionsProvider);
      await _refresh();
    } catch (e) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Could not accept',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _acceptingIds.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(buyerQuantityChangesPageProvider);
    final async = ref.watch(buyerPendingQuantityChangesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AllColor.white,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: const CustomBackButton(),
        ),
        title: Text(
          'Quantity approvals',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: AllColor.black,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.w),
          children: [
            Text(
              'Vendors may request a lower quantity. Accept to update your order and receive any refund to your wallet.',
              style: TextStyle(fontSize: 13.sp, color: AllColor.grey500, height: 1.35),
            ),
            SizedBox(height: 16.h),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(e.toString()),
              data: (payload) {
                final p = payload.page;
                if (p.items.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.h),
                    child: Center(
                      child: Text(
                        'No pending quantity changes.',
                        style: TextStyle(color: AllColor.grey500, fontSize: 14.sp),
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...p.items.map(
                      (item) => _QuantityChangeCard(
                        item: item,
                        busy: _acceptingIds.contains(item.id),
                        onAccept: () => _accept(item),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: page <= 1
                              ? null
                              : () {
                                  ref
                                          .read(
                                            buyerQuantityChangesPageProvider
                                                .notifier,
                                          )
                                          .state =
                                      page - 1;
                                },
                          child: const Text('Prev'),
                        ),
                        Text('$page / ${p.lastPage}'),
                        TextButton(
                          onPressed: page >= p.lastPage
                              ? null
                              : () {
                                  ref
                                          .read(
                                            buyerQuantityChangesPageProvider
                                                .notifier,
                                          )
                                          .state =
                                      page + 1;
                                },
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityChangeCard extends StatelessWidget {
  const _QuantityChangeCard({
    required this.item,
    required this.busy,
    required this.onAccept,
  });

  final BuyerQuantityChangeRequestItem item;
  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final img = item.productImage?.trim() ?? '';
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: AllColor.grey200),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: SizedBox(
                    width: 56.w,
                    height: 56.w,
                    child: img.isNotEmpty
                        ? FirstTimeShimmerImage(
                            imageUrl: img,
                            fit: BoxFit.cover,
                          )
                        : ColoredBox(
                            color: AllColor.grey100,
                            child: Icon(Icons.inventory_2_outlined, color: AllColor.grey),
                          ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName.isNotEmpty
                            ? item.productName
                            : 'Line #${item.invoiceItemId}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                        ),
                      ),
                      if (item.orderNumber.isNotEmpty)
                        Text(
                          'Order ${item.orderNumber}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AllColor.grey500,
                          ),
                        ),
                      SizedBox(height: 4.h),
                      Text(
                        'Qty ${item.currentQuantity} → ${item.proposedQuantity}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AllColor.loginButtomColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.reason.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                'Reason: ${item.reason}',
                style: TextStyle(fontSize: 12.sp, color: AllColor.black87),
              ),
            ],
            if (item.requestedByName != null) ...[
              SizedBox(height: 4.h),
              Text(
                'Requested by ${item.requestedByName}',
                style: TextStyle(fontSize: 12.sp, color: AllColor.grey500),
              ),
            ],
            if (item.refundPreview != null && item.refundPreview! > 0) ...[
              SizedBox(height: 4.h),
              Text(
                'Estimated refund: ${item.refundPreview!.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12.sp, color: AllColor.grey500),
              ),
            ],
            SizedBox(height: 12.h),
            FilledButton(
              onPressed: busy ? null : onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: AllColor.loginButtomColor,
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: busy
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Accept'),
            ),
          ],
        ),
      ),
    );
  }
}
