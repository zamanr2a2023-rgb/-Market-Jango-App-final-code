import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/localization/Keys/buyer_kay.dart';
import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/core/widget/TupperTextAndBackButton.dart';
import 'package:market_jango/core/widget/sreeen_brackground.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/buyer/screens/billing/data/invoice_details_data.dart';
import 'package:market_jango/features/buyer/screens/billing/model/invoice_details_model.dart';
import 'package:market_jango/features/buyer/screens/billing/util/buyer_invoice_fulfillment.dart';
import 'package:market_jango/features/buyer/screens/order/data/buyer_orders_data.dart';
import 'package:market_jango/features/buyer/screens/order/util/buyer_mark_received_action.dart';
import 'package:market_jango/features/buyer/screens/billing/util/invoice_receipt_pdf.dart';
import 'package:market_jango/features/buyer/screens/refunds/data/buyer_refunds_api.dart';
import 'package:market_jango/features/buyer/screens/refunds/model/buyer_track_path_model.dart';
import 'package:market_jango/features/buyer/screens/refunds/provider/buyer_refunds_provider.dart';
import 'package:printing/printing.dart';

bool _buyerLineEligibleForRefund(String status) {
  final s = status.toLowerCase().trim();
  return s.contains('delivered') || s.contains('return');
}

String _buyerLineStatusLabel(InvoiceItemDetail item) {
  if (item.isReceived) {
    if (item.receivedVia == 'auto') {
      return 'Received (auto)';
    }
    return 'Received';
  }
  return item.status;
}

/// Pass as [GoRouter] `extra` when opening from My Orders (title + order-style meta).
class BuyerInvoiceDetailsArgs {
  const BuyerInvoiceDetailsArgs(this.invoiceId, {this.fromMyOrders = false});

  final int invoiceId;
  final bool fromMyOrders;
}

class BuyerInvoiceDetailsScreen extends ConsumerStatefulWidget {
  const BuyerInvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
    this.fromMyOrders = false,
  });
  static const routeName = '/buyer_invoice_details';

  final int invoiceId;
  final bool fromMyOrders;

  @override
  ConsumerState<BuyerInvoiceDetailsScreen> createState() =>
      _BuyerInvoiceDetailsScreenState();
}

class _BuyerInvoiceDetailsScreenState extends ConsumerState<BuyerInvoiceDetailsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(invoiceDetailsProvider(widget.invoiceId));
      ref.invalidate(buyerOrdersProvider);
    }
  }

  Future<void> _refreshDetails() async {
    ref.invalidate(invoiceDetailsProvider(widget.invoiceId));
    await ref.read(invoiceDetailsProvider(widget.invoiceId).future);
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(invoiceDetailsProvider(widget.invoiceId));
    final invoiceId = widget.invoiceId;
    final fromMyOrders = widget.fromMyOrders;

    final awaitingReceipt = detailsAsync.valueOrNull == null
        ? const <InvoiceItemDetail>[]
        : buyerLinesAwaitingReceipt(detailsAsync.valueOrNull!.items);
    final showBottomUpdateStatus =
        fromMyOrders && awaitingReceipt.length == 1;

    return Scaffold(
      body: ScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tuppertextandbackbutton(
                  screenName: fromMyOrders
                      ? 'Order details'
                      : '${ref.t(BKeys.invoiceDetails)} #$invoiceId',
                ),
                SizedBox(height: 12.h),
                Expanded(
                  child: detailsAsync.when(
                    data: (details) {
                      if (details == null) {
                        return Center(
                          child: Text(
                            ref.t(BKeys.invoiceNotFound),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AllColor.grey,
                            ),
                          ),
                        );
                      }
                      final hidePerLineReceived = showBottomUpdateStatus;
                      return RefreshIndicator(
                        onRefresh: _refreshDetails,
                        color: AllColor.loginButtomColor,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.only(
                            bottom: showBottomUpdateStatus ? 8.h : 28.h,
                          ),
                          child: _InvoiceWireframeCard(
                            ref: ref,
                            details: details,
                            invoiceId: invoiceId,
                            fromMyOrders: fromMyOrders,
                            hidePerLineReceivedButton: hidePerLineReceived,
                          ),
                        ),
                      );
                    },
                    loading: () => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          SizedBox(height: 12.h),
                          Text(
                            ref.t(BKeys.loading),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AllColor.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Text(
                          ref.t(BKeys.errorOccurred),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AllColor.red,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: showBottomUpdateStatus
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                child: FilledButton(
                  onPressed: () => buyerConfirmAndMarkReceived(
                    context,
                    ref,
                    invoiceItemId: awaitingReceipt.single.id,
                    invoiceId: invoiceId,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AllColor.loginButtomColor,
                    minimumSize: Size(double.infinity, 48.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    'Update status',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// Polished invoice: tinted meta block, vendor cards, table, fee panel, footer.
class _InvoiceWireframeCard extends StatelessWidget {
  const _InvoiceWireframeCard({
    required this.ref,
    required this.details,
    required this.invoiceId,
    this.fromMyOrders = false,
    this.hidePerLineReceivedButton = false,
  });

  final WidgetRef ref;
  final InvoiceDetails details;
  final int invoiceId;
  final bool fromMyOrders;
  final bool hidePerLineReceivedButton;

  String _modeLabel() {
    if (fromMyOrders) {
      return buyerInvoiceFulfillmentModeLabel(details.items);
    }
    final ds = details.deliveryStatus?.trim();
    if (ds != null && ds.isNotEmpty) return ds;
    return 'Delivery';
  }

  static List<MapEntry<int, List<InvoiceItemDetail>>> _groupByVendor(
    List<InvoiceItemDetail> items,
  ) {
    final map = <int, List<InvoiceItemDetail>>{};
    for (final i in items) {
      map.putIfAbsent(i.vendorId, () => []).add(i);
    }
    final keys = map.keys.toList()..sort();
    return keys.map((k) => MapEntry(k, map[k]!)).toList();
  }

  String get _currency => details.currency ?? 'USD';

  Color get _accent => AllColor.loginButtomColor;

  String _orderNumberDisplay() {
    final ord = details.orderNumber?.trim();
    if (ord != null && ord.isNotEmpty) return ord;
    final t = details.taxRef?.trim();
    if (t != null && t.isNotEmpty) return t;
    return '#$invoiceId';
  }

  /// Invoice-level delivery, else sum of line `delivery_charge` (matches API shape you shared).
  String? _effectiveDeliveryChargeRaw() {
    final root = details.deliveryCharge?.trim();
    if (root != null && root.isNotEmpty) return root;
    double sum = 0;
    var any = false;
    for (final item in details.items) {
      final s = item.lineDeliveryCharge?.trim();
      if (s == null || s.isEmpty) continue;
      final v = double.tryParse(s);
      if (v != null) {
        sum += v;
        any = true;
      }
    }
    if (!any) return null;
    return sum.toStringAsFixed(2);
  }

  String _vendorBlockTitle(
    WidgetRef ref,
    int vendorIndex,
    int totalVendors,
    String businessLabel,
  ) {
    if (totalVendors <= 1) return businessLabel;
    final letter = String.fromCharCode(65 + vendorIndex);
    final slot = ref.t(BKeys.invoiceVendorBlock, fallback: 'Vendor');
    return '$slot $letter · $businessLabel';
  }

  String _moneyOrDash(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    return raw.trim();
  }

  String _summaryAmount(String? raw) {
    final v = _moneyOrDash(raw);
    if (v == '—') return v;
    return '$_currency $v';
  }

  Widget _metaRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AllColor.grey500,
                height: 1.25,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AllColor.black,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByVendor(details.items);
    final customerLine =
        details.cusName != null && details.cusName!.trim().isNotEmpty
            ? details.cusName!.trim()
            : '—';

    final headerStyle = TextStyle(
      fontSize: 11.sp,
      fontWeight: FontWeight.w700,
      color: AllColor.black54,
      letterSpacing: 0.2,
    );
    final cellStyle = TextStyle(
      fontSize: 13.sp,
      color: AllColor.black,
      height: 1.3,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 18.h),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AllColor.grey200.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AllColor.orange50.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AllColor.orange200.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metaRow(
                  ref.t(BKeys.customer, fallback: 'Customer'),
                  customerLine,
                ),
                _metaRow(
                  ref.t(BKeys.orderNumber, fallback: 'Order Number'),
                  _orderNumberDisplay(),
                  isLast: !fromMyOrders,
                ),
                if (fromMyOrders) ...[
                  _metaRow(
                    ref.t(BKeys.status, fallback: 'Status'),
                    (details.status != null && details.status!.trim().isNotEmpty)
                        ? details.status!.trim()
                        : '—',
                  ),
                  _metaRow(
                    'Mode',
                    _modeLabel(),
                    isLast: true,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 12.h),
          _LiveTrackingCard(invoiceId: invoiceId),
          SizedBox(height: 18.h),
          Text(
            ref.t(BKeys.items, fallback: 'Items'),
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AllColor.black,
            ),
          ),
          SizedBox(height: 10.h),
          ...List.generate(grouped.length, (vendorIndex) {
            final entry = grouped[vendorIndex];
            final vendorId = entry.key;
            final lines = entry.value;
            final vendorName = lines.first.vendor?.businessName?.trim();
            final vLabel = (vendorName != null && vendorName.isNotEmpty)
                ? vendorName
                : '${ref.t(BKeys.vendorLabel)}$vendorId';
            final sectionTitle = _vendorBlockTitle(
              ref,
              vendorIndex,
              grouped.length,
              vLabel,
            );

            return Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: AllColor.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AllColor.grey200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 11.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AllColor.orange50.withValues(alpha: 0.9),
                            AllColor.white,
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(color: AllColor.grey200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 20.sp,
                            color: _accent,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              sectionTitle,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: AllColor.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: AllColor.grey100,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              ref.t(BKeys.productName, fallback: 'Product name'),
                              style: headerStyle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              ref.t(
                                BKeys.numberOfProducts,
                                fallback: 'Number of products',
                              ),
                              style: headerStyle,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              ref.t(BKeys.cost, fallback: 'Cost'),
                              style: headerStyle,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...lines.asMap().entries.map((e) {
                      final item = e.value;
                      final isLast = e.key == lines.length - 1;
                      final product = item.product;
                      final name = product?.name.isNotEmpty == true
                          ? product!.name
                          : '${ref.t(BKeys.productLabel)}${item.productId}';
                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 12.h,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: cellStyle,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.status.trim().isNotEmpty) ...[
                                        SizedBox(height: 4.h),
                                        Text(
                                          '${ref.t(BKeys.status, fallback: 'Status')}: ${_buyerLineStatusLabel(item)}',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            color: AllColor.grey500,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                      if (item.canMarkReceived) ...[
                                        SizedBox(height: 4.h),
                                        Text(
                                          item.receiptFields.autoReceiveHintLine,
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            color: AllColor.grey500,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                      if (item.canMarkReceived &&
                                          !hidePerLineReceivedButton) ...[
                                        SizedBox(height: 6.h),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: FilledButton(
                                            onPressed: () =>
                                                buyerConfirmAndMarkReceived(
                                              context,
                                              ref,
                                              invoiceItemId: item.id,
                                              invoiceId: invoiceId,
                                            ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AllColor.loginButtomColor,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 14.w,
                                                vertical: 6.h,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Text(
                                              'Received',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (_buyerLineEligibleForRefund(
                                        item.status,
                                      )) ...[
                                        SizedBox(height: 6.h),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton(
                                            onPressed: () =>
                                                _openBuyerLineRefundDialog(
                                              context,
                                              ref,
                                              invoiceId: invoiceId,
                                              invoiceItemId: item.id,
                                              suggestedAmount: item.totalPay,
                                            ),
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              foregroundColor:
                                                  AllColor.loginButtomColor,
                                            ),
                                            child: Text(
                                              'Request refund',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${item.quantity}',
                                    style: cellStyle.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.totalPay,
                                    style: cellStyle.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _accent,
                                      fontSize: 14.sp,
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Divider(
                              height: 1,
                              indent: 12.w,
                              endIndent: 12.w,
                              color: AllColor.grey200,
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              );
          }),
          SizedBox(height: 6.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
            decoration: BoxDecoration(
              color: AllColor.grey100,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AllColor.grey200),
            ),
            child: Column(
              children: [
                _feeLine(
                  ref.t(BKeys.deliveryCharge, fallback: 'Delivery charge'),
                  _summaryAmount(_effectiveDeliveryChargeRaw()),
                ),
                if (details.isUrgent == true) ...[
                  SizedBox(height: 8.h),
                  _feeLine(
                    'Urgent delivery',
                    details.urgentFee != null && details.urgentFee! > 0
                        ? '$_currency ${details.urgentFee!.toStringAsFixed(2)}'
                        : 'Yes',
                  ),
                ],
                SizedBox(height: 8.h),
                _feeLine(
                  ref.t(BKeys.tax, fallback: 'Tax'),
                  _summaryAmount(details.vat),
                ),
                SizedBox(height: 8.h),
                _feeLine(
                  ref.t(BKeys.platformFees, fallback: 'Platform fees'),
                  _summaryAmount(details.platformFee),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 12.h),
                  child: Divider(height: 1, color: AllColor.grey300),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 12.h, 0, 4.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        ref.t(BKeys.totalFees, fallback: 'Total fees'),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AllColor.black,
                        ),
                      ),
                      Text(
                        '$_currency ${details.payable}',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: AllColor.black,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.only(top: 14.h),
            child: Divider(height: 1, color: AllColor.grey200),
          ),
          Padding(
            padding: EdgeInsets.only(top: 14.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AllColor.grey100,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AllColor.grey200),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 32.h,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: Text(
                        'Market Jango',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: AllColor.grey500,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _shareInvoiceReceiptPdf(context, ref),
                  icon: Icon(
                    Icons.download_rounded,
                    size: 20.sp,
                    color: _accent,
                  ),
                  label: Text(
                    ref.t(BKeys.download, fallback: 'Download'),
                    style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feeLine(String label, String value) {
    final isDash = value == '—';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: AllColor.grey500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: isDash ? AllColor.grey300 : AllColor.black,
          ),
        ),
      ],
    );
  }

  Future<void> _shareInvoiceReceiptPdf(BuildContext context, WidgetRef ref) async {
    final labels = InvoiceReceiptPdfLabels(
      invoiceTitle: '${ref.t(BKeys.invoiceDetails)} #$invoiceId',
      customerLabel: ref.t(BKeys.customer, fallback: 'Customer'),
      customerValue: details.cusName ?? '—',
      orderNumberLabel: ref.t(BKeys.orderNumber, fallback: 'Order Number'),
      itemsTitle: ref.t(BKeys.items, fallback: 'Items'),
      productNameColumn: ref.t(BKeys.productName, fallback: 'Product name'),
      numberOfProductsColumn:
          ref.t(BKeys.numberOfProducts, fallback: 'Number of products'),
      costColumn: ref.t(BKeys.cost, fallback: 'Cost'),
      deliveryLabel: ref.t(BKeys.deliveryCharge, fallback: 'Delivery charge'),
      taxLabel: ref.t(BKeys.tax, fallback: 'Tax'),
      platformFeesLabel: ref.t(BKeys.platformFees, fallback: 'Platform fees'),
      totalFeesLabel: ref.t(BKeys.totalFees, fallback: 'Total fees'),
      vendorSlotWord: ref.t(BKeys.invoiceVendorBlock, fallback: 'Vendor'),
      vendorIdPrefix: ref.t(BKeys.vendorLabel),
      productFallbackPrefix: ref.t(BKeys.productLabel),
    );

    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AllColor.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
    );

    var dialogClosed = false;
    try {
      final bytes = await buildInvoiceReceiptPdfBytes(
        details: details,
        labels: labels,
        orderNumberValue: _orderNumberDisplay(),
        deliveryValue: _summaryAmount(_effectiveDeliveryChargeRaw()),
        taxValue: _summaryAmount(details.vat),
        platformValue: _summaryAmount(details.platformFee),
        totalValue: '$_currency ${details.payable}',
      );
      if (context.mounted) {
        nav.pop();
        dialogClosed = true;
      }
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'invoice_${invoiceId}_receipt.pdf',
      );
    } catch (e, st) {
      debugPrint('Invoice PDF: $e\n$st');
      if (context.mounted && !dialogClosed) {
        nav.pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
            margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            content: Text(ref.t(BKeys.errorOccurred)),
          ),
        );
      }
    }
  }
}

int? _parseBuyerLineItemId(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String _buyerLiveLocationLabel(dynamic loc) {
  if (loc is Map) {
    final lat = loc['latitude'] ?? loc['lat'];
    final lng = loc['longitude'] ?? loc['lng'];
    if (lat != null && lng != null) return '$lat, $lng';
  }
  if (loc != null) return loc.toString();
  return '—';
}

List<Widget> _buyerTrackLineWidgets(
  WidgetRef ref,
  int invoiceId,
  Map<String, dynamic> raw,
) {
  final items = raw['items'];
  if (items is! List || items.isEmpty) {
    return [
      Padding(
        padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
        child: Text(
          'No driver assignments for this order yet.',
          style: TextStyle(fontSize: 12.sp, color: AllColor.grey500),
        ),
      ),
    ];
  }
  final out = <Widget>[];
  for (final e in items) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final driverRaw = m['driver'];
    var driverName = '—';
    if (driverRaw is Map<String, dynamic>) {
      driverName = driverRaw['name']?.toString() ??
          driverRaw['full_name']?.toString() ??
          '—';
    }
    final itemId = m['item_id'] ?? m['invoice_item_id'];
    final lineItemId = _parseBuyerLineItemId(itemId);
    final loc = m['live_location'] ?? m['location'] ?? m['current_location'];
    final locStr = _buyerLiveLocationLabel(loc);
    out.add(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 0),
            title: Text(
              'Line ${itemId ?? '—'} · $driverName',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              locStr,
              style: TextStyle(fontSize: 11.sp, color: AllColor.grey500),
            ),
          ),
          if (lineItemId != null && lineItemId > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 8.h),
              child: _BuyerTrackPathRow(
                invoiceId: invoiceId,
                itemId: lineItemId,
              ),
            ),
        ],
      ),
    );
  }
  if (out.isEmpty) {
    return [
      Padding(
        padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
        child: Text(
          'Tracking response had no readable lines.',
          style: TextStyle(fontSize: 12.sp, color: AllColor.grey500),
        ),
      ),
    ];
  }
  return out;
}

class _BuyerTrackPathRow extends ConsumerWidget {
  const _BuyerTrackPathRow({
    required this.invoiceId,
    required this.itemId,
  });

  final int invoiceId;
  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = BuyerTrackPathKey(invoiceId: invoiceId, itemId: itemId);
    final async = ref.watch(buyerOrderTrackPathProvider(key));
    return async.when(
      loading: () => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Loading driver route…',
          style: TextStyle(fontSize: 11.sp, color: AllColor.grey500),
        ),
      ),
      error: (e, _) => Text(
        e.toString().replaceFirst('Exception: ', ''),
        style: TextStyle(fontSize: 11.sp, color: AllColor.red),
      ),
      data: (path) {
        if (path.points.isEmpty) {
          return Text(
            'No GPS trail yet for this line.',
            style: TextStyle(fontSize: 11.sp, color: AllColor.grey500),
          );
        }
        return TextButton.icon(
          onPressed: () => _openBuyerPathMapBottomSheet(context, path.points),
          icon: Icon(
            Icons.route,
            size: 18.sp,
            color: AllColor.loginButtomColor,
          ),
          label: Text(
            'View route (${path.points.length} pts)',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AllColor.loginButtomColor,
            ),
          ),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      },
    );
  }
}

void _openBuyerPathMapBottomSheet(
  BuildContext context,
  List<BuyerTrackPathPoint> points,
) {
  if (points.isEmpty) return;
  final latLngs =
      points.map((p) => LatLng(p.latitude, p.longitude)).toList();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (_, __) => Column(
        children: [
          SizedBox(height: 8.h),
          Text(
            'Driver route',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: latLngs.first,
                    zoom: 14,
                  ),
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('buyer_track_path'),
                      points: latLngs,
                      color: AllColor.blue500,
                      width: 5,
                    ),
                  },
                  onMapCreated: (c) {
                    if (latLngs.length < 2) return;
                    try {
                      final swLat = latLngs
                          .map((e) => e.latitude)
                          .reduce(math.min);
                      final swLng = latLngs
                          .map((e) => e.longitude)
                          .reduce(math.min);
                      final neLat = latLngs
                          .map((e) => e.latitude)
                          .reduce(math.max);
                      final neLng = latLngs
                          .map((e) => e.longitude)
                          .reduce(math.max);
                      c.animateCamera(
                        CameraUpdate.newLatLngBounds(
                          LatLngBounds(
                            southwest: LatLng(swLat, swLng),
                            northeast: LatLng(neLat, neLng),
                          ),
                          56,
                        ),
                      );
                    } catch (_) {}
                  },
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    ),
  );
}

class _LiveTrackingCard extends ConsumerWidget {
  const _LiveTrackingCard({required this.invoiceId});

  final int invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(buyerLiveTrackProvider(invoiceId));

    return Material(
      color: AllColor.white,
      borderRadius: BorderRadius.circular(12.r),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          title: Text(
            'Live delivery tracking',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AllColor.black,
            ),
          ),
          children: [
            live.when(
              loading: () => Padding(
                padding: EdgeInsets.all(16.w),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
                child: Text(
                  e.toString(),
                  style: TextStyle(fontSize: 12.sp, color: AllColor.red),
                ),
              ),
              data: (raw) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buyerTrackLineWidgets(ref, invoiceId, raw),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openBuyerLineRefundDialog(
  BuildContext context,
  WidgetRef ref, {
  required int invoiceId,
  required int invoiceItemId,
  String? suggestedAmount,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _BuyerLineRefundDialog(
      invoiceItemId: invoiceItemId,
      suggestedAmount: suggestedAmount,
    ),
  );

  if (ok != true || !context.mounted) return;

  ref.invalidate(invoiceDetailsProvider(invoiceId));
  ref.invalidate(buyerRefundsListProvider);
  GlobalSnackbar.show(
    context,
    title: 'Sent',
    message: 'Refund request submitted',
    type: CustomSnackType.success,
  );
}

class _BuyerLineRefundDialog extends StatefulWidget {
  const _BuyerLineRefundDialog({
    required this.invoiceItemId,
    this.suggestedAmount,
  });

  final int invoiceItemId;
  final String? suggestedAmount;

  @override
  State<_BuyerLineRefundDialog> createState() => _BuyerLineRefundDialogState();
}

class _BuyerLineRefundDialogState extends State<_BuyerLineRefundDialog> {
  late final TextEditingController _reason;
  late final TextEditingController _amount;
  bool _busy = false;
  String? _error;
  String? _reasonError;

  @override
  void initState() {
    super.initState();
    _reason = TextEditingController();
    _amount = TextEditingController(text: widget.suggestedAmount?.trim() ?? '');
  }

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    final orange = AllColor.loginButtomColor;
    final soft = AllColor.orange200;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AllColor.orange50.withValues(alpha: 0.35),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: soft, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: AllColor.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: AllColor.red, width: 1.5),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _reasonError = null;
    });

    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _reasonError = 'Please enter a reason for your refund.');
      return;
    }

    final amtRaw = _amount.text.trim();
    double? amount;
    if (amtRaw.isNotEmpty) {
      amount = double.tryParse(amtRaw.replaceAll(',', ''));
      if (amount == null) {
        setState(
          () => _error = 'Enter a valid amount or leave the field empty.',
        );
        return;
      }
    }

    setState(() => _busy = true);
    try {
      await BuyerRefundsApi.instance.requestLineRefund(
        invoiceItemId: widget.invoiceItemId,
        reason: reason,
        amount: amount,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orange = AllColor.loginButtomColor;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text(
        'Request refund',
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tell us what went wrong. Leave amount empty to request the full line total.',
                style: TextStyle(fontSize: 12.sp, color: AllColor.grey500),
              ),
              if (_error != null) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AllColor.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AllColor.red.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 18.sp, color: AllColor.red),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: AllColor.red,
                            fontSize: 12.sp,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 12.h),
              TextField(
                controller: _reason,
                enabled: !_busy,
                maxLines: 3,
                onChanged: (_) {
                  if (_reasonError != null) {
                    setState(() => _reasonError = null);
                  }
                },
                decoration: _fieldDecoration(
                  'Reason *',
                  hint: 'e.g. item damaged or wrong product',
                ).copyWith(errorText: _reasonError),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _amount,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _fieldDecoration('Amount (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: orange),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: orange),
          child: _busy
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
