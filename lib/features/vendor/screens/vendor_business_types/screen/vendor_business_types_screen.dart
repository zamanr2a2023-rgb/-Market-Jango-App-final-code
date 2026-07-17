import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/vendor_business_types/data/vendor_business_types_api.dart';

class VendorBusinessTypesScreen extends ConsumerStatefulWidget {
  const VendorBusinessTypesScreen({super.key});

  static const String routeName = '/vendor/business-types';

  @override
  ConsumerState<VendorBusinessTypesScreen> createState() =>
      _VendorBusinessTypesScreenState();
}

class _VendorBusinessTypesScreenState
    extends ConsumerState<VendorBusinessTypesScreen> {
  int? _busyTypeId;

  Future<void> _add(VendorBusinessType type) async {
    setState(() => _busyTypeId = type.id);
    try {
      final msg = await VendorBusinessTypesApi.instance.add([type.id]);
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Business type',
        message: msg,
        type: CustomSnackType.success,
      );
      ref.invalidate(vendorBusinessTypesProvider);
    } catch (e) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Business type',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busyTypeId = null);
    }
  }

  Future<void> _remove(VendorBusinessType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove business type'),
        content: Text('Remove "${type.name}" from your store?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: AllColor.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyTypeId = type.id);
    try {
      final msg = await VendorBusinessTypesApi.instance.remove(type.id);
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Business type',
        message: msg,
        type: CustomSnackType.success,
      );
      ref.invalidate(vendorBusinessTypesProvider);
    } catch (e) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Business type',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busyTypeId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vendorBusinessTypesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: AllColor.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          'Business Types',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AllColor.black,
          ),
        ),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp, color: AllColor.grey500),
                ),
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(vendorBusinessTypesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (result) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(vendorBusinessTypesProvider);
            await ref.read(vendorBusinessTypesProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16.r),
            children: [
              _UsageCard(result: result),
              SizedBox(height: 16.h),
              _SectionTitle(
                title: 'Selected types',
                count: result.selected.length,
              ),
              SizedBox(height: 8.h),
              if (result.selected.isEmpty)
                _EmptyCard(text: 'No business type selected yet')
              else
                ...result.selected.map(
                  (t) => _TypeCard(
                    type: t,
                    selected: true,
                    busy: _busyTypeId == t.id,
                    onAction: () => _remove(t),
                  ),
                ),
              SizedBox(height: 20.h),
              _SectionTitle(
                title: 'Available types',
                count: result.available.length,
              ),
              SizedBox(height: 8.h),
              if (!result.canAddMore)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: AllColor.orange50,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: AllColor.loginButtomColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18.sp,
                          color: AllColor.loginButtomColor,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'You reached your limit '
                            '(${result.used}/${result.limit}). '
                            'Remove a type or upgrade your plan to add more.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AllColor.black,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (result.available.isEmpty)
                _EmptyCard(text: 'No more types available')
              else
                ...result.available.map(
                  (t) => _TypeCard(
                    type: t,
                    selected: false,
                    busy: _busyTypeId == t.id,
                    canAdd: result.canAddMore,
                    onAction: result.canAddMore ? () => _add(t) : null,
                  ),
                ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.result});

  final VendorBusinessTypesResult result;

  @override
  Widget build(BuildContext context) {
    final limit = result.limit;
    final used = result.used;
    final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 20.sp,
                color: AllColor.loginButtomColor,
              ),
              SizedBox(width: 8.w),
              Text(
                'Plan usage',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AllColor.black,
                ),
              ),
              const Spacer(),
              Text(
                '$used / $limit used',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: result.canAddMore
                      ? AllColor.loginButtomColor
                      : AllColor.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AllColor.grey200,
              color: result.canAddMore
                  ? AllColor.loginButtomColor
                  : AllColor.red,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'Allowed categories: ${result.allowedCategoriesCount}',
            style: TextStyle(fontSize: 12.sp, color: AllColor.grey500),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: AllColor.black,
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AllColor.grey200,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AllColor.grey500,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20.h),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 13.sp, color: AllColor.grey500),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.selected,
    required this.busy,
    this.canAdd = true,
    this.onAction,
  });

  final VendorBusinessType type;
  final bool selected;
  final bool busy;
  final bool canAdd;
  final VoidCallback? onAction;

  IconData get _typeIcon {
    switch (type.slug) {
      case 'restaurant':
        return Icons.restaurant_outlined;
      case 'grocery':
        return Icons.local_grocery_store_outlined;
      case 'pharmacy':
        return Icons.local_pharmacy_outlined;
      case 'electronics':
        return Icons.devices_other_outlined;
      case 'clothing':
        return Icons.checkroom_outlined;
      case 'hardware':
        return Icons.hardware_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: selected
              ? AllColor.loginButtomColor.withValues(alpha: 0.4)
              : AllColor.grey200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: selected
                  ? AllColor.loginButtomColor.withValues(alpha: 0.1)
                  : AllColor.grey200.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _typeIcon,
              size: 20.sp,
              color: selected ? AllColor.loginButtomColor : AllColor.grey500,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        type.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AllColor.black,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.check_circle,
                        size: 15.sp,
                        color: AllColor.loginButtomColor,
                      ),
                    ],
                  ],
                ),
                if (type.description.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    type.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AllColor.grey500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          if (busy)
            SizedBox(
              width: 20.r,
              height: 20.r,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AllColor.loginButtomColor,
              ),
            )
          else if (selected)
            IconButton(
              onPressed: onAction,
              tooltip: 'Remove',
              icon: Icon(
                Icons.delete_outline,
                size: 20.sp,
                color: AllColor.red,
              ),
            )
          else
            TextButton.icon(
              onPressed: canAdd ? onAction : null,
              style: TextButton.styleFrom(
                foregroundColor: AllColor.loginButtomColor,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
              ),
              icon: Icon(Icons.add, size: 18.sp),
              label: Text(
                'Add',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
