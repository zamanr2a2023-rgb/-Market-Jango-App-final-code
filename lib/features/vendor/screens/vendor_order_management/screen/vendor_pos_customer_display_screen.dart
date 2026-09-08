import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_pos_display_model.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/provider/vendor_pos_display_provider.dart';

/// Customer-facing POS display (STEP_04).
///
/// - Without [invoiceId]: mirrors the live walk-in cart session (same device).
/// - With [invoiceId]: polls `GET /api/vendor/manual-orders/{id}/pos-display`.
class VendorPosCustomerDisplayScreen extends ConsumerWidget {
  const VendorPosCustomerDisplayScreen({super.key, this.invoiceId});

  final int? invoiceId;

  static const routeName = '/vendor/pos-customer-display';
  static String routePathForInvoice(int id) =>
      '/vendor/pos-customer-display?invoiceId=$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = invoiceId ?? 0;
    if (id > 0) {
      final async = ref.watch(vendorPosDisplayRemoteProvider(id));
      return Scaffold(
        backgroundColor: AllColor.black,
        body: SafeArea(
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            error: (e, _) => _ErrorBody(
              message: e.toString().replaceFirst('Exception: ', ''),
              onRetry: () => ref.invalidate(vendorPosDisplayRemoteProvider(id)),
            ),
            data: (d) => _DisplayBody(data: d),
          ),
        ),
      );
    }

    final session = ref.watch(vendorPosCartSessionProvider);
    return Scaffold(
      backgroundColor: AllColor.black,
      body: SafeArea(
        child: _DisplayBody(data: session.toDisplayData()),
      ),
    );
  }
}

class _DisplayBody extends StatelessWidget {
  const _DisplayBody({required this.data});

  final VendorPosDisplayData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            data.vendorName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AllColor.white,
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (data.orderNumber != null && data.orderNumber!.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              data.orderNumber!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AllColor.grey300,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          SizedBox(height: 16.h),
          Divider(color: AllColor.grey500.withValues(alpha: 0.5)),
          Expanded(
            child: data.items.isEmpty
                ? Center(
                    child: Text(
                      'Waiting for items…',
                      style: TextStyle(
                        color: AllColor.grey300,
                        fontSize: 18.sp,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: data.items.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (_, i) {
                      final line = data.items[i];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              line.name,
                              style: TextStyle(
                                color: AllColor.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '×${line.quantity}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AllColor.grey300,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              line.lineTotal.toStringAsFixed(2),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: AllColor.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Divider(color: AllColor.grey500.withValues(alpha: 0.5)),
          SizedBox(height: 8.h),
          Row(
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  color: AllColor.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                data.total.toStringAsFixed(2),
                style: TextStyle(
                  color: AllColor.loginButtomColor,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            data.source == 'api' ? 'Live order' : 'Live cart',
            textAlign: TextAlign.center,
            style: TextStyle(color: AllColor.grey500, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AllColor.white, fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AllColor.loginButtomColor,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
