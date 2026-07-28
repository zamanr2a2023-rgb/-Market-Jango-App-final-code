import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/screen/following/data/following_api.dart';
import 'package:market_jango/core/screen/following/model/following_model.dart';
import 'package:market_jango/core/utils/get_user_type.dart';
import 'package:market_jango/core/utils/image_controller.dart';
import 'package:market_jango/features/buyer/screens/buyer_vendor_profile/screen/buyer_vendor_profile_screen.dart';
import 'package:market_jango/features/transport/screens/driver/screen/driver_details_screen.dart';

class MyFollowingScreen extends ConsumerWidget {
  const MyFollowingScreen({super.key});

  static const String routeName = '/myFollowing';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myFollowingProvider);

    return Scaffold(
      backgroundColor: AllColor.white,
      appBar: AppBar(
        backgroundColor: AllColor.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          'Following',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AllColor.black,
          ),
        ),
        centerTitle: true,
      ),
      body: async.when(
        data: (result) => _FollowingBody(result: result),
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
                  onPressed: () => ref.invalidate(myFollowingProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowingBody extends ConsumerWidget {
  const _FollowingBody({required this.result});

  final FollowingListResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = result.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
          child: Text(
            '${result.total} Following',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AllColor.grey500,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    ref.watch(getUserTypeProvider).value == 'transport'
                        ? 'You are not following any drivers yet'
                        : 'You are not following any vendors yet',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: AllColor.grey500,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(myFollowingProvider);
                    await ref.read(myFollowingProvider.future);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 72.w,
                      color: AllColor.grey200,
                    ),
                    itemBuilder: (context, i) =>
                        _FollowingTile(item: items[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _FollowingTile extends StatelessWidget {
  const _FollowingTile({required this.item});

  final FollowingItem item;

  void _openProfile(BuildContext context) {
    if (item.isVendor) {
      context.push(
        BuyerVendorProfileScreen.routeName,
        extra: {
          'vendorId': item.followableId,
          'userId': item.userId,
        },
      );
      return;
    }

    if (item.isDriver) {
      // DriverDetailsScreen loads profile via userProvider(userId).
      context.push(
        DriverDetailsScreen.routeName,
        extra: item.userId > 0 ? item.userId : item.followableId,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unknown type: ${item.followableType}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = item.image?.trim() ?? '';
    final isNetwork =
        url.startsWith('http://') || url.startsWith('https://');

    return InkWell(
      onTap: () => _openProfile(context),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24.r,
              backgroundColor: AllColor.grey200,
              child: ClipOval(
                child: isNetwork
                    ? FirstTimeShimmerImage(
                        imageUrl: url,
                        width: 48.r,
                        height: 48.r,
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        item.isVendor
                            ? Icons.storefront_rounded
                            : Icons.local_shipping_rounded,
                        color: AllColor.grey500,
                        size: 22.sp,
                      ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AllColor.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: item.isVendor
                              ? AllColor.loginButtomColor
                                  .withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          item.isVendor ? 'Vendor' : 'Driver',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: item.isVendor
                                ? AllColor.loginButtomColor
                                : Colors.blue.shade700,
                          ),
                        ),
                      ),
                      if (item.subtitle != 'Vendor' &&
                          item.subtitle != 'Driver') ...[
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AllColor.grey500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AllColor.grey500),
          ],
        ),
      ),
    );
  }
}
