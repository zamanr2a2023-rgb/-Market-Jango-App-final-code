import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/api_control/common_api.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/utils/get_token_sharedpefarens.dart';
import 'package:market_jango/core/utils/get_user_type.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/affiliate/data/affiliate_data.dart';
import 'package:market_jango/features/affiliate/model/affiliate_model.dart';

class AffiliateScreen extends ConsumerWidget {
  const AffiliateScreen({super.key});

  static const String routeName = '/affiliate';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDriver = ref.watch(getUserTypeProvider).value == 'driver';
    final statsAsync = ref.watch(affiliateStatisticsProvider);
    final affiliateLinksAsync = ref.watch(affiliateLinksProvider);
    final influencerLinksAsync = isDriver
        ? ref.watch(driverInfluencerReferralLinksProvider)
        : ref.watch(influencerReferralLinksProvider);
    final statsNotifier = ref.read(affiliateStatisticsProvider.notifier);
    final InfluencerReferralLinksNotifierInterface influencerNotifier = isDriver
        ? ref.read(driverInfluencerReferralLinksProvider.notifier)
        : ref.read(influencerReferralLinksProvider.notifier);
    final linksNotifier = ref.read(affiliateLinksProvider.notifier);

    Future<void> onRefresh() async {
      if (!isDriver) await statsNotifier.refresh();
      await linksNotifier.refresh();
      await influencerNotifier.refresh();
    }

    final storeLinks = affiliateLinksAsync.valueOrNull ?? const <AffiliateLinkModel>[];
    final hasStoreLink = storeLinks.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AllColor.white,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 12.w),
          child: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios, size: 20.r, color: AllColor.black),
          ),
        ),
        title: Text(
          'Influencer links',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AllColor.black,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: hasStoreLink
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _openEditStoreSheet(context, ref, storeLinks.first),
              backgroundColor: AllColor.loginButtomColor,
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              label: Text(
                'Edit',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statsAsync.when(
                data: (stats) {
                  if (stats == null) return const SizedBox.shrink();
                  return _StatsCards(statistics: stats);
                },
                loading: () => SizedBox(height: 20.h),
                error: (_, __) => const SizedBox.shrink(),
              ),
              SizedBox(height: 24.h),
              Text(
                'Influencer links',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: AllColor.black,
                ),
              ),
              SizedBox(height: 12.h),
              influencerLinksAsync.when(
                loading: () => Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _ErrorSection(
                  message: e.toString().replaceFirst('Exception: ', ''),
                  onRetry: () {
                    influencerNotifier.refresh();
                    if (!isDriver) statsNotifier.refresh();
                  },
                ),
                data: (influencerList) {
                  if (influencerList.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: Center(
                        child: affiliateLinksAsync.when(
                          loading: () => Text(
                            'No influencer links yet.',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AllColor.grey500,
                            ),
                          ),
                          error: (_, __) => Text(
                            'No influencer links yet.',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AllColor.grey500,
                            ),
                          ),
                          data: (links) {
                            final canCreateAffiliateLink = links.isEmpty;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No influencer links yet.',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: AllColor.grey500,
                                  ),
                                ),
                                if (canCreateAffiliateLink) ...[
                                  SizedBox(height: 16.h),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _openAddSheet(context, ref, links),
                                    icon: const Icon(Icons.add, size: 18),
                                    label:
                                        const Text('Create affiliate link'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AllColor.loginButtomColor,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: influencerList.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final item = influencerList[index];
                      return _InfluencerLinkCard(
                        item: item,
                        onApprove: !item.vendorApproved

                            ? () => _approveInfluencerLink(
                                context,
                                ref,
                                item.id,
                                influencerNotifier,
                              )

                          //  ? () => _approveInfluencerLink(context, ref, item.id, influencerNotifier)

                            : null,
                        onDelete: () => _deleteInfluencerLink(
                          context,
                          ref,
                          item.id,
                          item.influencerName,
                          influencerNotifier,
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 100.h),
            ],
          ),
        ),
      ),
    );
  }

  String _baseUrl() {
    try {
      final base = Uri.parse(CommonAPIController.affiliateLinks);
      return '${base.scheme}://${base.host}${base.port != 80 && base.port != 443 ? ':${base.port}' : ''}';
    } catch (_) {
      return 'https://example.com';
    }
  }

  Future<void> _approveInfluencerLink(
    BuildContext context,
    WidgetRef ref,
    int id,

    InfluencerReferralLinksNotifierInterface notifier,

  //  InfluencerReferralLinksNotifier notifier,

  ) async {
    try {
      await notifier.approveLink(id);
      if (context.mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Approved',
          message: 'Referral link approved',
          type: CustomSnackType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Error',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
        );
      }
    }
  }

  Future<void> _deleteInfluencerLink(
    BuildContext context,
    WidgetRef ref,
    int id,
    String name,

    InfluencerReferralLinksNotifierInterface notifier,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete link'),
        content: Text('Are you sure you want to delete the link for "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      await notifier.deleteLink(id);
      if (context.mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Deleted',
          message: 'Influencer link removed',
          type: CustomSnackType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Error',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
        );
      }
    }
  }

  void _copyLink(BuildContext context, AffiliateLinkModel link) {
    try {
      final base = _baseUrl();
      final url = '$base/affiliate/${link.linkCode}';
      Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Copied',
          message: 'Link copied to clipboard',
          type: CustomSnackType.success,
        );
      }
    } catch (_) {
      if (context.mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Error',
          message: 'Could not copy link',
          type: CustomSnackType.error,
        );
      }
    }
  }

  void _openAddSheet(
    BuildContext context,
    WidgetRef ref,
    List<AffiliateLinkModel> links,
  ) {
    if (links.isNotEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'Limit reached',
        message: 'You can only create one link.',
        type: CustomSnackType.error,
      );
      return;
    }
    _showStoreAffiliateSheet(context, ref);
  }

  void _openEditStoreSheet(
    BuildContext context,
    WidgetRef ref,
    AffiliateLinkModel link,
  ) {
    final fullUrl = '${_baseUrl()}/affiliate/${link.linkCode}';
    _showStoreAffiliateSheet(
      context,
      ref,
      existingLink: link,
      initialFullUrl: fullUrl,
    );
  }

  void _showStoreAffiliateSheet(
    BuildContext context,
    WidgetRef ref, {
    AffiliateLinkModel? existingLink,
    String? initialFullUrl,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddLinkSheet(
        existingLink: existingLink,
        initialFullUrl: initialFullUrl,
        onSaved: () {
          ref.read(affiliateLinksProvider.notifier).refresh();
          if (ref.read(getUserTypeProvider).value != 'driver') {
            ref.read(affiliateStatisticsProvider.notifier).refresh();
          }
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AffiliateLinkModel link,
    AffiliateLinksNotifier linksNotifier,
    AffiliateStatisticsNotifier statsNotifier,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete link?'),
        content: Text('Remove "${link.displayName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final token = await ref.read(authTokenProvider.future);
                await affiliateDelete(token, id: link.id);
                await linksNotifier.refresh();
                await statsNotifier.refresh();
                if (context.mounted) {
                  GlobalSnackbar.show(
                    context,
                    title: 'Deleted',
                    message: 'Affiliate link removed',
                    type: CustomSnackType.success,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  GlobalSnackbar.show(
                    context,
                    title: 'Error',
                    message: e.toString().replaceFirst('Exception: ', ''),
                    type: CustomSnackType.error,
                  );
                }
              }
            },
            child: Text('Delete', style: TextStyle(color: AllColor.red)),
          ),
        ],
      ),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorSection({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: AllColor.grey500),
            SizedBox(height: 16.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: AllColor.grey500),
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AllColor.loginButtomColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCards extends StatelessWidget {
  final AffiliateStatisticsModel statistics;

  const _StatsCards({required this.statistics});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.link,
                label: 'Links',
                value: '${statistics.activeLinks}/${statistics.totalLinks}',
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _StatCard(
                icon: Icons.touch_app_outlined,
                label: 'Clicks',
                value: '${statistics.totalClicks}',
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.percent,
                label: 'Conversions',
                value: '${statistics.totalConversions}',
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _StatCard(
                icon: Icons.attach_money,
                label: 'Revenue',
                value: statistics.totalRevenue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22.r, color: AllColor.loginButtomColor),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AllColor.black,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: AllColor.grey500),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.link_off, size: 48.sp, color: AllColor.grey300),
          SizedBox(height: 16.h),
          Text(
            'No affiliate links yet',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AllColor.black,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Create a link to share and track clicks and conversions.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: AllColor.grey500),
          ),
          SizedBox(height: 20.h),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: Icon(Icons.add, size: 18.sp),
            label: const Text('Create link'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AllColor.loginButtomColor,
              side: BorderSide(color: AllColor.loginButtomColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final AffiliateLinkModel link;
  final String baseUrl;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LinkCard({
    required this.link,
    required this.baseUrl,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fullUrl = '$baseUrl/affiliate/${link.linkCode}';
    final isActive = link.status == 'active';

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AllColor.orange50,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.link,
                  size: 20.r,
                  color: AllColor.loginButtomColor,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.displayName,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AllColor.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      link.linkCode,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AllColor.grey500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isActive
                      ? AllColor.green.withOpacity(0.15)
                      : AllColor.grey200,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AllColor.green : AllColor.grey500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _MiniChip(icon: Icons.touch_app, label: '${link.clicks}'),
              SizedBox(width: 12.w),
              _MiniChip(icon: Icons.trending_up, label: '${link.conversions}'),
              SizedBox(width: 12.w),
              _MiniChip(icon: Icons.attach_money, label: link.revenue),
            ],
          ),
          SizedBox(height: 12.h),
          SelectableText(
            fullUrl,
            style: TextStyle(
              fontSize: 11.sp,
              color: AllColor.grey500,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              TextButton.icon(
                onPressed: onCopy,
                icon: Icon(Icons.copy, size: 18.r),
                label: const Text('Copy'),
                style: TextButton.styleFrom(
                  foregroundColor: AllColor.loginButtomColor,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 20.r),
                color: AllColor.grey500,
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 20.r),
                color: AllColor.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card for one item from influencer-referral-links API (image + name + link + stats).
class _InfluencerLinkCard extends StatelessWidget {
  const _InfluencerLinkCard({
    required this.item,
    this.onApprove,
    required this.onDelete,
  });

  final InfluencerReferralLinkModel item;
  final Future<void> Function()? onApprove;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.image?.trim().isNotEmpty == true ? item.image! : null;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: 52.r,
                        height: 52.r,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderAvatar(),
                      )
                    : _placeholderAvatar(),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.influencerName.isNotEmpty
                          ? item.influencerName
                          : 'Influencer',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AllColor.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.influencerEmail.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        item.influencerEmail,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AllColor.grey500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Container(

                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),

                       //   padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),

                          decoration: BoxDecoration(
                            color: item.vendorApproved
                                ? AllColor.green.withOpacity(0.15)
                                : AllColor.grey200,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            item.vendorApproved ? 'Approved' : 'Pending',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,

                              color: item.vendorApproved
                                  ? AllColor.green
                                  : AllColor.grey500,

                             // color: item.vendorApproved ? AllColor.green : AllColor.grey500,

                            ),
                          ),
                        ),
                        if (onApprove != null) ...[
                          SizedBox(width: 8.w),
                          TextButton(
                            onPressed: () => onApprove!(),
                            style: TextButton.styleFrom(

                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              minimumSize: Size.zero,
                              foregroundColor: AllColor.loginButtomColor,
                            ),
                            child: Text(
                              'Approve',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

//                               padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
//                               minimumSize: Size.zero,
//                               foregroundColor: AllColor.loginButtomColor,
//                             ),
//                             child: Text('Approve', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),

                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SelectableText(
            item.referralLink,
            style: TextStyle(
              fontSize: 11.sp,
              color: AllColor.grey500,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              _MiniChip(icon: Icons.touch_app, label: '${item.clicks}'),
              SizedBox(width: 12.w),
              _MiniChip(icon: Icons.trending_up, label: '${item.conversions}'),
              SizedBox(width: 12.w),
              _MiniChip(
                icon: Icons.attach_money,
                label: item.totalEarnings.toStringAsFixed(0),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  if (item.referralLink.isEmpty) return;
                  Clipboard.setData(ClipboardData(text: item.referralLink));
                  if (context.mounted) {
                    GlobalSnackbar.show(
                      context,
                      title: 'Copied',
                      message: 'Influencer link copied',
                      type: CustomSnackType.success,
                    );
                  }
                },
                icon: Icon(Icons.copy, size: 18.r),
                label: const Text('Copy link'),
                style: TextButton.styleFrom(
                  foregroundColor: AllColor.loginButtomColor,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => onDelete?.call(),

                icon: Icon(
                  Icons.delete_outline,
                  size: 18.r,
                  color: AllColor.red,
                ),
                label: Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AllColor.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: AllColor.red),

//                 icon: Icon(Icons.delete_outline, size: 18.r, color: AllColor.red),
//                 label: Text('Delete', style: TextStyle(fontSize: 13.sp, color: AllColor.red, fontWeight: FontWeight.w600)),
//                 style: TextButton.styleFrom(
//                   foregroundColor: AllColor.red,
//                 ),

              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholderAvatar() {
    return Container(
      width: 52.r,
      height: 52.r,
      color: AllColor.grey200,
      child: Icon(Icons.person, size: 28.r, color: AllColor.grey500),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.r, color: AllColor.grey500),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: AllColor.grey500),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog shown after creating a link – displays the shareable URL
// ---------------------------------------------------------------------------

class _CreatedLinkDialog extends StatelessWidget {
  final String fullUrl;
  final String linkCode;
  final VoidCallback onCopy;

  const _CreatedLinkDialog({
    required this.fullUrl,
    required this.linkCode,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AllColor.loginButtomColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.link_rounded,
                    size: 28.r,
                    color: AllColor.loginButtomColor,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link created',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: AllColor.black,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Share this link to track clicks',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AllColor.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AllColor.grey100.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AllColor.grey200),
              ),
              child: SelectableText(
                fullUrl,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AllColor.black87,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Code: $linkCode',
              style: TextStyle(fontSize: 12.sp, color: AllColor.grey500),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onCopy();
                    },
                    icon: Icon(Icons.copy_rounded, size: 20.r),
                    label: const Text('Copy link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AllColor.loginButtomColor,
                      side: BorderSide(color: AllColor.loginButtomColor),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AllColor.loginButtomColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add link bottom sheet
// ---------------------------------------------------------------------------

class _AddLinkSheet extends ConsumerStatefulWidget {
  final AffiliateLinkModel? existingLink;
  final String? initialFullUrl;
  final VoidCallback onSaved;

  const _AddLinkSheet({
    this.existingLink,
    this.initialFullUrl,
    required this.onSaved,
  });

  @override
  ConsumerState<_AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends ConsumerState<_AddLinkSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _destinationController = TextEditingController();
  final _customRateController = TextEditingController();
  final _cookieDurationController = TextEditingController();
  final _expiresAtController = TextEditingController();
  bool _loading = false;
  bool _hydrating = false;
  bool _active = true;
  String _attributionModel = 'first_click';
  AffiliateLinkModel? _editingLink;
  String? _fullUrlForCopy;

  static const List<String> _attributionOptions = ['first_click', 'last_click'];

  bool get _isEditMode => _editingLink != null;

  @override
  void initState() {
    super.initState();
    _editingLink = widget.existingLink;
    _fullUrlForCopy = widget.initialFullUrl;
    if (_editingLink != null) {
      _active = _editingLink!.status == 'active';
      _applyLinkToControllers(_editingLink!);
      _hydrating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromApi());
    }
  }

  bool _isValidHttpUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null) return false;
    if (!uri.hasScheme) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    return true;
  }

  void _applyLinkToControllers(AffiliateLinkModel link) {
    _nameController.text = link.name ?? '';
    _descriptionController.text = link.description ?? '';
    _destinationController.text = link.destinationUrl ?? '';
    if (link.customRate != null) {
      _customRateController.text = link.customRate!.toString();
    }
    if (link.cookieDurationDays != null) {
      _cookieDurationController.text = link.cookieDurationDays!.toString();
    }
    final attr = link.attributionModel?.trim();
    if (attr != null &&
        attr.isNotEmpty &&
        _attributionOptions.contains(attr)) {
      _attributionModel = attr;
    }
    if (link.expiresAt != null && link.expiresAt!.isNotEmpty) {
      _expiresAtController.text = link.expiresAt!;
    }
    _active = link.status == 'active';
  }

  Future<void> _hydrateFromApi() async {
    final link = _editingLink;
    if (link == null) {
      if (mounted) setState(() => _hydrating = false);
      return;
    }
    try {
      final detail = await ref.read(affiliateLinkDetailProvider(link.id).future);
      if (!mounted) return;
      if (detail != null) {
        _editingLink = detail.affiliateLink;
        if (detail.fullUrl.isNotEmpty) {
          _fullUrlForCopy = detail.fullUrl;
        }
        _applyLinkToControllers(detail.affiliateLink);
      }
    } catch (_) {
      // Keep list payload pre-fill.
    } finally {
      if (mounted) setState(() => _hydrating = false);
    }
  }

  double? _parseCustomRate() {
    final raw = _customRateController.text.trim();
    if (raw.isEmpty) return null;
    final v = double.tryParse(raw);
    if (v == null || v < 0 || v > 100) {
      GlobalSnackbar.show(
        context,
        title: 'Invalid rate',
        message: 'Custom rate must be between 0 and 100',
        type: CustomSnackType.error,
      );
      return null;
    }
    return v;
  }

  int? _parseCookieDays() {
    final raw = _cookieDurationController.text.trim();
    if (raw.isEmpty) return null;
    final v = int.tryParse(raw);
    if (v == null || v < 1) {
      GlobalSnackbar.show(
        context,
        title: 'Invalid duration',
        message: 'Cookie duration must be a positive number of days',
        type: CustomSnackType.error,
      );
      return null;
    }
    return v;
  }

  void _copyStoreLink() {
    final url = _fullUrlForCopy ?? '';
    if (url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    GlobalSnackbar.show(
      context,
      title: 'Copied',
      message: 'Affiliate link copied',
      type: CustomSnackType.success,
    );
  }

  Future<void> _switchToEditWithLink(AffiliateLinkModel link) async {
    _editingLink = link;
    _fullUrlForCopy =
        '${Uri.parse(CommonAPIController.affiliateLinks).origin}/affiliate/${link.linkCode}';
    _applyLinkToControllers(link);
    setState(() {});
    await _hydrateFromApi();
    if (mounted) {
      GlobalSnackbar.show(
        context,
        title: 'Existing link',
        message: 'Your store affiliate link is open for editing.',
        type: CustomSnackType.info,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _destinationController.dispose();
    _customRateController.dispose();
    _cookieDurationController.dispose();
    _expiresAtController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final destination = _destinationController.text.trim();
    if (!_isEditMode) {
      if (destination.isEmpty) {
        GlobalSnackbar.show(
          context,
          title: 'Invalid URL',
          message: 'Destination URL is required',
          type: CustomSnackType.error,
        );
        return;
      }
    }
    if (destination.isNotEmpty && !_isValidHttpUrl(destination)) {
      GlobalSnackbar.show(
        context,
        title: 'Invalid URL',
        message: 'Destination URL must be a valid http/https link',
        type: CustomSnackType.error,
      );
      return;
    }

    final customRate = _parseCustomRate();
    if (_customRateController.text.trim().isNotEmpty && customRate == null) {
      return;
    }
    final cookieDurationDays = _parseCookieDays();
    if (_cookieDurationController.text.trim().isNotEmpty &&
        cookieDurationDays == null) {
      return;
    }

    final expiresAtStr = _expiresAtController.text.trim();
    final expiresAt = expiresAtStr.isEmpty ? null : expiresAtStr;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    setState(() => _loading = true);
    try {
      final token = await ref.read(authTokenProvider.future);

      if (_isEditMode) {
        await affiliateUpdate(
          token,
          id: _editingLink!.id,
          name: name.isEmpty ? null : name,
          description: description.isEmpty ? null : description,
          destinationUrl: destination.isEmpty ? null : destination,
          customRate: customRate,
          cookieDurationDays: cookieDurationDays,
          attributionModel: _attributionModel,
          expiresAt: expiresAt,
          status: _active ? 'active' : 'inactive',
        );
        if (mounted) {
          widget.onSaved();
          Navigator.pop(context);
          GlobalSnackbar.show(
            context,
            title: 'Updated',
            message: 'Store affiliate link saved',
            type: CustomSnackType.success,
          );
        }
        return;
      }

      final result = await affiliateGenerate(
        token,
        name: name.isEmpty ? null : name,
        description: description.isEmpty ? null : description,
        destinationUrl: destination,
        customRate: customRate,
        cookieDurationDays: cookieDurationDays,
        attributionModel: _attributionModel,
        expiresAt: expiresAt,
      );
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        _showCreatedLinkDialog(context, result.fullUrl, result.link.linkCode);
      }
    } on AffiliateApiException catch (e) {
      if (!_isEditMode && e.statusCode == 422) {
        await ref.read(affiliateLinksProvider.notifier).refresh();
        final links = ref.read(affiliateLinksProvider).valueOrNull ?? [];
        if (links.isNotEmpty && mounted) {
          await _switchToEditWithLink(links.first);
          return;
        }
      }
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Error',
          message: e.message,
          type: CustomSnackType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Error',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreatedLinkDialog(
    BuildContext context,
    String fullUrl,
    String linkCode,
  ) {
    final displayUrl = fullUrl.isNotEmpty
        ? fullUrl
        : '${Uri.parse(CommonAPIController.affiliateLinks).origin}/affiliate/$linkCode';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CreatedLinkDialog(
        fullUrl: displayUrl,
        linkCode: linkCode,
        onCopy: () {
          Clipboard.setData(ClipboardData(text: displayUrl));
          if (context.mounted) {
            GlobalSnackbar.show(
              context,
              title: 'Copied',
              message: 'Link copied to clipboard',
              type: CustomSnackType.success,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24.h;
    final linkCode = _editingLink?.linkCode ?? '';
    final displayUrl = _fullUrlForCopy ?? '';
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, bottomPadding),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 12.h),
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AllColor.grey200,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AllColor.loginButtomColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(
                      _isEditMode
                          ? Icons.edit_rounded
                          : Icons.add_link_rounded,
                      size: 28.r,
                      color: AllColor.loginButtomColor,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditMode
                              ? 'Edit store affiliate link'
                              : 'New affiliate link',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: AllColor.black,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _isEditMode
                              ? 'Update your store affiliate program'
                              : 'Share this link to track clicks & conversions',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AllColor.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_hydrating) ...[
                SizedBox(height: 16.h),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_isEditMode && linkCode.isNotEmpty) ...[
                SizedBox(height: 20.h),
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AllColor.grey100.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: AllColor.grey200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link code (read-only)',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AllColor.grey500,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        linkCode,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (displayUrl.isNotEmpty) ...[
                        SizedBox(height: 10.h),
                        Text(
                          displayUrl,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AllColor.black87,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        OutlinedButton.icon(
                          onPressed: _copyStoreLink,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy link'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AllColor.loginButtomColor,
                            side: BorderSide(color: AllColor.loginButtomColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              SizedBox(height: 28.h),
              Text(
                'Link details',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AllColor.grey500,
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: _nameController,
                style: TextStyle(fontSize: 15.sp),
                decoration: InputDecoration(
                  hintText: 'e.g. Summer campaign',
                  labelText: 'Name',
                  labelStyle: TextStyle(
                    fontSize: 11.sp,
                    color: AllColor.grey500,
                  ),
                  prefixIcon: Icon(
                    Icons.label_outline_rounded,
                    size: 22.r,
                    color: AllColor.grey500,
                  ),
                  filled: true,
                  fillColor: AllColor.grey100.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: AllColor.grey200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(
                      color: AllColor.loginButtomColor,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                style: TextStyle(fontSize: 15.sp),
                decoration: InputDecoration(
                  hintText: 'Where or how you’ll use this link',
                  labelText: 'Description',
                  labelStyle: TextStyle(
                    fontSize: 11.sp,
                    color: AllColor.grey500,
                  ),
                  alignLabelWithHint: true,
                  prefixIcon: Icon(
                    Icons.description_outlined,
                    size: 22.r,
                    color: AllColor.grey500,
                  ),
                  filled: true,
                  fillColor: AllColor.grey100.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: AllColor.grey200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(
                      color: AllColor.loginButtomColor,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: _destinationController,
                style: TextStyle(fontSize: 15.sp),
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'https://example.com/page',
                  labelText: 'Destination URL',
                  labelStyle: TextStyle(
                    fontSize: 11.sp,
                    color: AllColor.grey500,
                  ),
                  prefixIcon: Icon(
                    Icons.link_rounded,
                    size: 22.r,
                    color: AllColor.grey500,
                  ),
                  filled: true,
                  fillColor: AllColor.grey100.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: AllColor.grey200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(
                      color: AllColor.loginButtomColor,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
              ),
              SizedBox(height: 28.h),
              Text(
                'Tracking & settings',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AllColor.grey500,
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: _customRateController,
                style: TextStyle(fontSize: 15.sp),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 10',
                  labelText: 'Custom rate %',
                  labelStyle: TextStyle(
                    fontSize: 11.sp,
                    color: AllColor.grey500,
                  ),
                  prefixIcon: Icon(
                    Icons.percent_rounded,
                    size: 22.r,
                    color: AllColor.grey500,
                  ),
                  filled: true,
                  fillColor: AllColor.grey100.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: AllColor.grey200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(
                      color: AllColor.loginButtomColor,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: _cookieDurationController,
                style: TextStyle(fontSize: 15.sp),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 30',
                  labelText: 'Cookie duration (days)',
                  labelStyle: TextStyle(
                    fontSize: 11.sp,
                    color: AllColor.grey500,
                  ),
                  prefixIcon: Icon(
                    Icons.cookie_rounded,
                    size: 22.r,
                    color: AllColor.grey500,
                  ),
                  filled: true,
                  fillColor: AllColor.grey100.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: AllColor.grey200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(
                      color: AllColor.loginButtomColor,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              DropdownButtonFormField<String>(
                initialValue: _attributionModel,
                decoration: InputDecoration(
                  labelText: 'Attribution model',
                  labelStyle: TextStyle(
                    fontSize: 11.sp,
                    color: AllColor.grey500,
                  ),
                  prefixIcon: Icon(
                    Icons.touch_app_rounded,
                    size: 22.r,
                    color: AllColor.grey500,
                  ),
                  filled: true,
                  fillColor: AllColor.grey100.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: AllColor.grey200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(
                      color: AllColor.loginButtomColor,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
                items: _attributionOptions
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value == 'first_click' ? 'First click' : 'Last click',
                          style: TextStyle(fontSize: 15.sp),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) setState(() => _attributionModel = value);
                },
              ),
              SizedBox(height: 14.h),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null && mounted) {
                    final y = picked.year;
                    final m = picked.month.toString().padLeft(2, '0');
                    final d = picked.day.toString().padLeft(2, '0');
                    _expiresAtController.text = '$y-$m-$d';
                  }
                },
                borderRadius: BorderRadius.circular(14.r),
                child: IgnorePointer(
                  child: TextField(
                    controller: _expiresAtController,
                    readOnly: true,
                    style: TextStyle(fontSize: 15.sp),
                    decoration: InputDecoration(
                      hintText: 'Tap to pick date',
                      labelText: 'Expires at',
                      labelStyle: TextStyle(
                        fontSize: 11.sp,
                        color: AllColor.grey500,
                      ),
                      prefixIcon: Icon(
                        Icons.calendar_today_rounded,
                        size: 22.r,
                        color: AllColor.grey500,
                      ),
                      filled: true,
                      fillColor: AllColor.grey100.withOpacity(0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(
                          color: AllColor.grey200,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(
                          color: AllColor.loginButtomColor,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                    ),
                  ),
                ),
              ),
              if (_isEditMode) ...[
                SizedBox(height: 14.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AllColor.grey100.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: AllColor.grey200),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'Link active',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _active ? 'Clicks are being tracked' : 'Link is paused',
                      style: TextStyle(fontSize: 12.sp, color: AllColor.grey500),
                    ),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    activeThumbColor: AllColor.loginButtomColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 28.h),
              SizedBox(
                height: 52.h,
                child: ElevatedButton(
                  onPressed: (_loading || _hydrating) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AllColor.loginButtomColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: _loading
                      ? SizedBox(
                          height: 24.h,
                          width: 24.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isEditMode
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              size: 22.r,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              _isEditMode ? 'Save changes' : 'Create link',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
