import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/utils/image_controller.dart';
import 'package:market_jango/features/driver/screen/followers/data/driver_followers_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_followers/model/vendor_followers_model.dart';

class DriverFollowersScreen extends ConsumerWidget {
  const DriverFollowersScreen({super.key});

  static const String routeName = '/driver/followers';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driverFollowersProvider);

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
          'Followers',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AllColor.black,
          ),
        ),
        centerTitle: true,
      ),
      body: async.when(
        data: (result) => _FollowersBody(result: result),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp, color: AllColor.grey500),
                ),
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: () => ref.invalidate(driverFollowersProvider),
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

class _FollowersBody extends StatelessWidget {
  const _FollowersBody({required this.result});

  final VendorFollowersResult result;

  @override
  Widget build(BuildContext context) {
    final items = result.followers.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
          child: Text(
            '${result.followersCount} '
            '${result.followersCount == 1 ? 'Follower' : 'Followers'}',
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
                    'No followers yet',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: AllColor.grey500,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 72.w,
                    color: AllColor.grey200,
                  ),
                  itemBuilder: (context, i) => _FollowerTile(follower: items[i]),
                ),
        ),
      ],
    );
  }
}

class _FollowerTile extends StatelessWidget {
  const _FollowerTile({required this.follower});

  final VendorFollower follower;

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final image = follower.image;
    final typeLabel = follower.userType.isEmpty
        ? ''
        : follower.userType[0].toUpperCase() +
            follower.userType.substring(1);
    final followed = _formatDate(follower.followedAt);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        children: [
          ClipOval(
            child: image == null
                ? Container(
                    width: 48.r,
                    height: 48.r,
                    color: AllColor.grey200,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.person_outline,
                      size: 26.sp,
                      color: AllColor.grey500,
                    ),
                  )
                : FirstTimeShimmerImage(
                    imageUrl: image,
                    width: 48.r,
                    height: 48.r,
                    fit: BoxFit.cover,
                  ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  follower.name.isEmpty ? 'Unknown' : follower.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AllColor.black,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  [
                    if (typeLabel.isNotEmpty) typeLabel,
                    if (followed.isNotEmpty) 'Followed $followed',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AllColor.grey500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
