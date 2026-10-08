import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/localization/Keys/buyer_kay.dart';
import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/core/screen/buyer_massage/model/chat_history_route_model.dart';
import 'package:market_jango/core/screen/buyer_massage/screen/global_chat_screen.dart';
import 'package:market_jango/core/utils/image_controller.dart';
import 'package:market_jango/features/transport/screens/driver/screen/driver_details_screen.dart';
import 'package:market_jango/features/vendor/screens/vendor_asign_to_order_driver/screen/asign_to_order_driver.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/vendor_available_drivers_loader.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_orders_models.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/widget/vendor_driver_assign_filters.dart';
import 'package:market_jango/features/vendor/screens/vendor_outlets/data/vendor_outlets_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_outlets/screen/assign_to_order_outlet.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';

class VendorDriverList extends ConsumerStatefulWidget {
  const VendorDriverList({super.key});
  static const routeName = "/vendorDriverList";

  @override
  ConsumerState<VendorDriverList> createState() => _VendorDriverListState();
}

class _VendorDriverListState extends ConsumerState<VendorDriverList> {
  final _search = TextEditingController();
  final _pickup = TextEditingController();
  final _drop = TextEditingController();
  bool _showOutlets = false;
  String? _transportType;
  List<VendorAvailableDriver> _availableDrivers = [];
  bool _driversLoading = false;
  String? _driversError;

  @override
  void initState() {
    super.initState();
    _loadAvailableDrivers();
  }

  @override
  void dispose() {
    _search.dispose();
    _pickup.dispose();
    _drop.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableDrivers() async {
    setState(() {
      _driversLoading = true;
      _driversError = null;
    });
    try {
      final q = _search.text.trim();
      final list = await VendorAvailableDriversLoader.instance.fetch(
        search: q.isEmpty ? null : q,
        pickLocation: _pickup.text.trim(),
        dropLocation: _drop.text.trim(),
        transportType: _transportType,
      );
      if (mounted) {
        setState(() {
          _availableDrivers = list;
          _driversLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _driversError = e.toString().replaceFirst('Exception: ', '');
          _driversLoading = false;
        });
      }
    }
  }

  void _clearDriverFilters() {
    _pickup.clear();
    _drop.clear();
    setState(() => _transportType = null);
    _loadAvailableDrivers();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _search.text.trim().toLowerCase();
    final showBack = context.canPop();

    return Scaffold(
      backgroundColor: AllColor.white,
      body: SafeArea(
        child: Column(
          children: [
            if (showBack) const CustomBackButton(),
            SizedBox(height: showBack ? 20.h : 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.h),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (!_showOutlets) _loadAvailableDrivers();
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _showOutlets
                      ? 'Search your outlet'
                      : ref.t(BKeys.searchYourTransporter),
                  hintStyle: TextStyle(color: AllColor.textHintColor),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AllColor.black54,
                  ),
                  filled: true,
                  fillColor: AllColor.grey100,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: buildOutlineInputBorder(),
                  focusedBorder: buildOutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            // Drivers / Outlets tabs
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: _ListTabButton(
                      label: 'Drivers',
                      icon: Icons.local_shipping_outlined,
                      selected: !_showOutlets,
                      onTap: () => setState(() => _showOutlets = false),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _ListTabButton(
                      label: 'Outlets',
                      icon: Icons.storefront_outlined,
                      selected: _showOutlets,
                      onTap: () => setState(() => _showOutlets = true),
                    ),
                  ),
                ],
              ),
            ),
            if (!_showOutlets) ...[
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: VendorDriverAssignFilters(
                  pickupController: _pickup,
                  dropController: _drop,
                  selectedTransport: _transportType,
                  onTransportChanged: (v) => setState(() => _transportType = v),
                  onSearch: _loadAvailableDrivers,
                  onClear: _clearDriverFilters,
                  enabled: !_driversLoading,
                ),
              ),
            ],
            SizedBox(height: 12.h),
            if (_showOutlets)
              Expanded(child: _OutletsList(searchQuery: searchQuery))
            else
              Expanded(
                child: _driversLoading
                    ? Center(child: Text(ref.t(BKeys.loading)))
                    : _driversError != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Text(
                            _driversError!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _availableDrivers.isEmpty
                    ? Center(
                        child: Text(
                          ref.t(BKeys.no_data),
                          style: TextStyle(color: AllColor.black54),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAvailableDrivers,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: _availableDrivers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final driver = _availableDrivers[i];
                            return _AvailableDriverCard(
                              data: driver,
                              onAssign: () {
                                context.push(
                                  AssignToOrderDriver.routeName,
                                  extra: AssignToOrderDriverArgs(
                                    driverId: driver.id,
                                    driverName: driver.name,
                                  ),
                                );
                              },
                              onChat: driver.userId == null
                                  ? null
                                  : () async {
                                      final authStorage = AuthLocalStorage();
                                      final userIdStr = await authStorage
                                          .getUserId();
                                      if (userIdStr == null ||
                                          userIdStr.isEmpty) {
                                        throw Exception('user id not founde');
                                      }
                                      final myUserId = int.tryParse(userIdStr);
                                      if (myUserId == null) {
                                        throw Exception('Invalid user id');
                                      }
                                      if (!context.mounted) return;
                                      context.push(
                                        GlobalChatScreen.routeName,
                                        extra: ChatArgs(
                                          partnerId: driver.userId!,
                                          partnerName: driver.name,
                                          partnerImage: driver.userImage ?? '',
                                          myUserId: myUserId,
                                        ),
                                      );
                                    },
                            );
                          },
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder buildOutlineInputBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: AllColor.grey200),
    );
  }
}

/* ===================== MODEL & DEMO DATA ===================== */

// class DriverItem {
//   final String id;
//   final String name;
//   final String phone;
//   final String address;
//   final double price;
//   final String avatarUrl;
//   final bool online;
//   const DriverItem({
//     required this.id,
//     required this.name,
//     required this.phone,
//     required this.address,
//     required this.price,
//     required this.avatarUrl,
//     required this.online,
//   });
// }

// const _drivers = <DriverItem>[
//   DriverItem(
//     id: '1',
//     name: 'Nguyen, Shane',
//     phone: '+00123456789',
//     address: 'australia, road 19 house 1',
//     price: 48,
//     avatarUrl:
//         'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=300',
//     online: true,
//   ),
//   DriverItem(
//     id: '2',
//     name: 'Henry, Arthur',
//     phone: '+00123456789',
//     address: 'australia, road 19 house 1',
//     price: 48,
//     avatarUrl:
//         'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=301',
//     online: true,
//   ),
//   DriverItem(
//     id: '3',
//     name: 'Cooper, Kristin',
//     phone: '+00123456789',
//     address: 'australia, road 19 house 1',
//     price: 48,
//     avatarUrl:
//         'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=300',
//     online: true,
//   ),
//   DriverItem(
//     id: '4',
//     name: 'Black, Marvin',
//     phone: '+00123456789',
//     address: 'australia, road 19 house 1',
//     price: 48,
//     avatarUrl:
//         'https://images.unsplash.com/photo-1544006659-f0b21884ce1d?w=300',
//     online: true,
//   ),
//   DriverItem(
//     id: '5',
//     name: 'Miles, Esther',
//     phone: '+00123456789',
//     address: 'australia, road 19 house 1',
//     price: 48,
//     avatarUrl:
//         'https://images.unsplash.com/photo-1548142813-c348350df52b?w=300',
//     online: true,
//   ),
// ];

/* ===================== TAB BUTTON ===================== */

class _ListTabButton extends StatelessWidget {
  const _ListTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AllColor.loginButtomColor : AllColor.grey100,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18.sp,
                color: selected ? AllColor.white : AllColor.black54,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AllColor.white : AllColor.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ===================== OUTLETS LIST ===================== */

class _OutletsList extends ConsumerWidget {
  const _OutletsList({required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outletsAsync = ref.watch(vendorOutletsProvider);

    return outletsAsync.when(
      data: (outlets) {
        final filtered = outlets.where((o) {
          if (searchQuery.isEmpty) return true;
          return o.name.toLowerCase().contains(searchQuery) ||
              o.phone.toLowerCase().contains(searchQuery) ||
              (o.zone?.toLowerCase().contains(searchQuery) ?? false) ||
              (o.town?.toLowerCase().contains(searchQuery) ?? false);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              searchQuery.isEmpty ? 'No outlets found' : ref.t(BKeys.no_data),
              style: TextStyle(color: AllColor.black54),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(vendorOutletsProvider);
            await ref.read(vendorOutletsProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final outlet = filtered[i];
              return _OutletCard(
                data: outlet,
                onAssign: () {
                  context.push(
                    AssignToOrderOutlet.routeName,
                    extra: AssignToOrderOutletArgs(
                      outletId: outlet.id,
                      outletName: outlet.name,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
      loading: () => Center(child: Text(ref.t(BKeys.loading))),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error.toString().replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(color: AllColor.black54),
            ),
            TextButton(
              onPressed: () => ref.invalidate(vendorOutletsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same card design as [_DriverCard], without the chat/message icon.
class _OutletCard extends ConsumerWidget {
  const _OutletCard({required this.data, required this.onAssign});

  final VendorOutlet data;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeColor = Colors.green;

    return Container(
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AllColor.grey200),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 60.h,
                  width: 60.w,
                  color: AllColor.grey100,
                  child: Icon(Icons.storefront, color: AllColor.grey),
                ),
              ),
              SizedBox(width: 10.h),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            data.name,
                            style: TextStyle(
                              color: AllColor.black,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.h,
                            vertical: 5.w,
                          ),
                          decoration: BoxDecoration(
                            color: activeColor.withOpacity(.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: activeColor),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              color: activeColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    if (data.phone.trim().isNotEmpty)
                      Text(
                        data.phone,
                        style: TextStyle(color: AllColor.black54),
                      ),
                    SizedBox(height: 4.h),
                    Text(
                      data.zone != null && data.zone!.isNotEmpty
                          ? 'Zone: ${data.zone}'
                          : 'Zone: —',
                      style: TextStyle(
                        color: AllColor.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 12.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (data.addressOrLocation != null &&
                        data.addressOrLocation!.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        'Location: ${data.addressOrLocation}',
                        style: TextStyle(
                          color: AllColor.black54,
                          fontSize: 12.sp,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 4.h),
                    Text(
                      'Max concurrent orders: ${data.defaultMaxConcurrentOrders}',
                      style: TextStyle(color: AllColor.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 10.h),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                height: 36.h,
                child: ElevatedButton(
                  onPressed: onAssign,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AllColor.loginButtomColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.h),
                  ),
                  child: Text(
                    ref.t(BKeys.assignedOrder),
                    style: TextStyle(
                      color: AllColor.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDriverPrice(String price) {
  final trimmed = price.trim();
  if (trimmed.isEmpty) return '—';
  if (trimmed.startsWith(r'$') ||
      trimmed.contains('UGX') ||
      trimmed.contains('AED')) {
    return trimmed;
  }
  return '\$$trimmed';
}

/* ===================== CARD WIDGET ===================== */

class _AvailableDriverCard extends ConsumerWidget {
  const _AvailableDriverCard({
    required this.data,
    required this.onAssign,
    this.onChat,
  });

  final VendorAvailableDriver data;
  final VoidCallback onAssign;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = data.name.isNotEmpty ? data.name : 'Driver';
    final transport = data.transportType?.trim();
    final transportLabel = transport != null && transport.isNotEmpty
        ? VendorDriverAssignFilters.labelForTransport(transport.toLowerCase())
        : null;

    return GestureDetector(
      onTap: data.userId != null
          ? () {
              context.push(
                DriverDetailsScreen.routeName,
                extra: data.userId,
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: AllColor.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AllColor.grey200),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 60.h,
                    width: 60.w,
                    color: AllColor.grey100,
                    child: (data.userImage ?? '').isNotEmpty
                        ? FirstTimeShimmerImage(
                            imageUrl: data.userImage!,
                            fit: BoxFit.cover,
                          )
                        : Icon(Icons.person, color: AllColor.grey),
                  ),
                ),
                SizedBox(width: 10.h),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: AllColor.black,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.h,
                              vertical: 5.w,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Text(
                              'Available',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              (data.phone ?? '').isNotEmpty ? data.phone! : '—',
                              style: TextStyle(color: AllColor.black54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatDriverPrice(data.price ?? ''),
                            style: TextStyle(
                              color: AllColor.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        (data.location ?? '').isNotEmpty
                            ? data.location!
                            : '—',
                        style: TextStyle(color: AllColor.black54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (transportLabel != null) ...[
                        SizedBox(height: 4.h),
                        Text(
                          transportLabel,
                          style: TextStyle(
                            color: AllColor.black87,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: 36.h,
                  child: ElevatedButton(
                    onPressed: onAssign,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AllColor.loginButtomColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16.h),
                    ),
                    child: Text(
                      ref.t(BKeys.assignedOrder),
                      style: TextStyle(
                        color: AllColor.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (onChat != null)
                  SizedBox(
                    height: 40.h,
                    width: 40.w,
                    child: Material(
                      color: AllColor.blue500,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onChat,
                        child: Icon(
                          Icons.chat,
                          size: 20.sp,
                          color: AllColor.white,
                        ),
                      ),
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
