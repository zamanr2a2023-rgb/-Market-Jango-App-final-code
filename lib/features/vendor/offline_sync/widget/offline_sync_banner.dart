import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/features/vendor/offline_sync/data/connectivity_providers.dart';
import 'package:market_jango/features/vendor/offline_sync/data/offline_sync_manager.dart';
import 'package:market_jango/features/vendor/offline_sync/provider/offline_sync_providers.dart';

/// Compact offline / pending-sync strip for POS (STEP_13).
class OfflineSyncBanner extends ConsumerStatefulWidget {
  const OfflineSyncBanner({super.key});

  @override
  ConsumerState<OfflineSyncBanner> createState() => _OfflineSyncBannerState();
}

class _OfflineSyncBannerState extends ConsumerState<OfflineSyncBanner> {
  void _onQueueChanged() {
    if (!mounted) return;
    bumpOfflineQueue(ref);
  }

  @override
  void initState() {
    super.initState();
    OfflineSyncManager.instance.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    OfflineSyncManager.instance.removeListener(_onQueueChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider);
    final pending = ref.watch(offlinePendingCountProvider);
    if (online && pending <= 0) return const SizedBox.shrink();

    final bg = online ? const Color(0xFFFFF8E1) : const Color(0xFFFFEBEE);
    final border = online ? AllColor.orange200 : AllColor.red200;
    final fg = online ? AllColor.orange700 : AllColor.red;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            online ? Icons.cloud_upload_outlined : Icons.cloud_off_outlined,
            color: fg,
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              online
                  ? 'Pending sync: $pending sale${pending == 1 ? '' : 's'}'
                  : pending > 0
                      ? 'Offline — $pending sale(s) waiting to sync'
                      : 'Offline — sales will be saved locally',
              style: TextStyle(
                color: fg,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (online && pending > 0)
            TextButton(
              onPressed: () async {
                await OfflineSyncManager.instance.syncPending();
                bumpOfflineQueue(ref);
              },
              child: Text(
                'Sync now',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.sp,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
