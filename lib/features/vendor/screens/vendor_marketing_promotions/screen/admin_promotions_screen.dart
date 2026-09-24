import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/vendor_marketing_promotions/data/vendor_promotion_api.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';

/// STEP_05 admin promotion approval (`POST /api/admin/promotions/{id}/approve`).
/// Available when logged in as admin (or when backend allows the role).
class AdminPromotionsScreen extends ConsumerStatefulWidget {
  const AdminPromotionsScreen({super.key});

  static const String routeName = '/admin/promotions';

  @override
  ConsumerState<AdminPromotionsScreen> createState() =>
      _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends ConsumerState<AdminPromotionsScreen> {
  final Set<int> _busy = {};

  Future<void> _approve(int id) async {
    setState(() => _busy.add(id));
    try {
      await VendorPromotionApi.approve(id);
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Approved',
        message: 'Promotion #$id approved',
        type: CustomSnackType.success,
      );
      ref.invalidate(adminPromotionsListProvider);
    } catch (e) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Error',
        message: e.toString(),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _reject(int id) async {
    setState(() => _busy.add(id));
    try {
      await VendorPromotionApi.reject(id);
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Rejected',
        message: 'Promotion #$id rejected',
        type: CustomSnackType.success,
      );
      ref.invalidate(adminPromotionsListProvider);
    } catch (e) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Error',
        message: e.toString(),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(adminPromotionsListProvider);

    return Scaffold(
      backgroundColor: AllColor.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),
              const CustomBackButton(),
              SizedBox(height: 12.h),
              Text(
                'Promotion approvals',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Approve pending vendor marketing promotions.',
                style: TextStyle(fontSize: 12.sp, color: Colors.black54),
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(adminPromotionsListProvider);
                    await ref.read(adminPromotionsListProvider.future);
                  },
                  child: listAsync.when(
                    data: (items) {
                      final pending =
                          items.where((e) => e.isPending || !e.isApproved).toList();
                      final show = pending.isNotEmpty ? pending : items;
                      if (show.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: 80.h),
                            const Center(child: Text('No pending promotions')),
                          ],
                        );
                      }
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: show.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) {
                          final p = show[i];
                          final busy = _busy.contains(p.id);
                          return ListTile(
                            title: Text(p.title),
                            subtitle: Text(
                              [
                                if (p.zone.isNotEmpty) 'Zone: ${p.zone}',
                                if (p.status.isNotEmpty) 'Status: ${p.status}',
                                if (p.content.isNotEmpty) p.content,
                              ].join('\n'),
                            ),
                            isThreeLine: true,
                            trailing: busy
                                ? SizedBox(
                                    width: 24.w,
                                    height: 24.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 4,
                                    children: [
                                      TextButton(
                                        onPressed: () => _approve(p.id),
                                        child: const Text('Approve'),
                                      ),
                                      TextButton(
                                        onPressed: () => _reject(p.id),
                                        child: const Text('Reject'),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16.w),
                      children: [
                        Text(
                          e.toString(),
                          style: TextStyle(fontSize: 13.sp),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Backend dependency: GET /api/admin/promotions '
                          '(pending list). Approve uses '
                          'POST /api/admin/promotions/{id}/approve.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
