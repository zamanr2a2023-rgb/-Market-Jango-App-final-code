import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/localization/Keys/buyer_kay.dart';
import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/features/auth/data/vendor_business_type_data.dart';
import 'package:market_jango/features/buyer/screens/cart/data/visibility_locations_data.dart';
import 'package:market_jango/features/buyer/screens/filter/data/visibility_vendors_data.dart';
import 'package:market_jango/features/buyer/screens/filter/screen/available_vendors_screen.dart';

enum _FilterTab { location, businessType }

class LocationFilteringTab extends ConsumerStatefulWidget {
  const LocationFilteringTab({super.key});

  @override
  ConsumerState<LocationFilteringTab> createState() =>
      _LocationFilteringTabState();
}

class _LocationFilteringTabState extends ConsumerState<LocationFilteringTab> {
  _FilterTab _tab = _FilterTab.location;
  String? _selectedZone;
  String? _selectedState;
  String? _selectedTown;
  int? _selectedBusinessTypeId;
  String? _selectedBusinessTypeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.32),
      body: Stack(
        children: [
          Opacity(opacity: 0.4, child: Container(color: Colors.black)),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              decoration: BoxDecoration(
                color: AllColor.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTabButton('Location', _FilterTab.location),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _buildTabButton(
                          'Business Type',
                          _FilterTab.businessType,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  if (_tab == _FilterTab.location)
                    _buildLocationForm(theme)
                  else
                    _buildBusinessTypeForm(theme),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: _onApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AllColor.loginButtomColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, _FilterTab tab) {
    final selected = _tab == tab;
    return InkWell(
      onTap: () => setState(() => _tab = tab),
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: selected ? AllColor.loginButtomColor : AllColor.dropDown,
          borderRadius: BorderRadius.circular(10.r),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationForm(TextTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            ref.t(BKeys.enterLocation),
            style: theme.headlineMedium!.copyWith(fontSize: 14),
          ),
        ),
        SizedBox(height: 5.h),
        ref.watch(visibilityZonesProvider).when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                e.toString().replaceFirst('Exception: ', ''),
                style: TextStyle(color: Colors.red, fontSize: 12.sp),
              ),
              data: (zones) => DropdownButtonFormField<String>(
                initialValue:
                    _selectedZone != null && zones.contains(_selectedZone)
                        ? _selectedZone
                        : null,
                decoration: buildInputDecoration(),
                hint: Text(ref.t(BKeys.searchLocation)),
                items: zones
                    .map(
                      (z) => DropdownMenuItem<String>(
                        value: z,
                        child: Text(z),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedZone = v;
                    _selectedState = null;
                    _selectedTown = null;
                  });
                },
              ),
            ),
        SizedBox(height: 12.h),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'State',
            style: theme.headlineMedium!.copyWith(fontSize: 14),
          ),
        ),
        SizedBox(height: 5.h),
        ref
            .watch(
              visibilityStatesByZoneProvider(
                (_selectedZone ?? '').trim(),
              ),
            )
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => DropdownButtonFormField<String>(
                decoration: buildInputDecoration(),
                items: const [],
                onChanged: null,
                hint: Text(
                  e.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (states) => DropdownButtonFormField<String>(
                initialValue: _selectedState != null &&
                        states.contains(_selectedState)
                    ? _selectedState
                    : null,
                decoration: buildInputDecoration(),
                hint: const Text('Select state'),
                items: states
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(s),
                      ),
                    )
                    .toList(),
                onChanged: ((_selectedZone ?? '').trim().isEmpty)
                    ? null
                    : (v) => setState(() {
                          _selectedState = v;
                          _selectedTown = null;
                        }),
              ),
            ),
        SizedBox(height: 12.h),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Town',
            style: theme.headlineMedium!.copyWith(fontSize: 14),
          ),
        ),
        SizedBox(height: 5.h),
        ref
            .watch(
              visibilityTownsByZoneProvider(
                (_selectedZone ?? '').trim(),
              ),
            )
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => DropdownButtonFormField<String>(
                decoration: buildInputDecoration(),
                items: const [],
                onChanged: null,
                hint: Text(
                  e.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (towns) => DropdownButtonFormField<String>(
                initialValue:
                    _selectedTown != null && towns.contains(_selectedTown)
                        ? _selectedTown
                        : null,
                decoration: buildInputDecoration(),
                hint: const Text('Select town'),
                items: towns
                    .map(
                      (t) => DropdownMenuItem<String>(
                        value: t,
                        child: Text(t),
                      ),
                    )
                    .toList(),
                onChanged: ((_selectedZone ?? '').trim().isEmpty)
                    ? null
                    : (v) => setState(() => _selectedTown = v),
              ),
            ),
      ],
    );
  }

  Widget _buildBusinessTypeForm(TextTheme theme) {
    return SizedBox(
      height: 280.h,
      child: ref.watch(businessTypesProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                e.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 12.sp),
              ),
            ),
            data: (types) {
              if (types.isEmpty) {
                return const Center(child: Text('No business types found'));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select business type',
                    style: theme.headlineMedium!.copyWith(fontSize: 14),
                  ),
                  SizedBox(height: 8.h),
                  Expanded(
                    child: ListView.separated(
                      itemCount: types.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final type = types[index];
                        final selected = _selectedBusinessTypeId == type.id;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedBusinessTypeId = type.id;
                              _selectedBusinessTypeName = type.name;
                            });
                          },
                          borderRadius: BorderRadius.circular(10.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 12.h,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AllColor.loginButtomColor
                                      .withValues(alpha: 0.12)
                                  : AllColor.dropDown,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: selected
                                    ? AllColor.loginButtomColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        type.name,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      if (type.description
                                          .trim()
                                          .isNotEmpty) ...[
                                        SizedBox(height: 2.h),
                                        Text(
                                          type.description.trim(),
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            color: AllColor.grey500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check_circle,
                                    color: AllColor.loginButtomColor,
                                    size: 20.sp,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _onApply() {
    if (_tab == _FilterTab.location) {
      final zone = (_selectedZone ?? '').trim();
      final st = (_selectedState ?? '').trim();
      final town = (_selectedTown ?? '').trim();

      if (zone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your location')),
        );
        return;
      }

      Navigator.pop(context);
      context.push(
        AvailableVendorsScreen.routeName,
        extra: AvailableVendorsScreenArgs.location(
          VisibilityVendorsParams(
            zone: zone,
            state: st.isEmpty ? null : st,
            town: town.isEmpty ? null : town,
          ),
        ),
      );
      return;
    }

    if (_selectedBusinessTypeId == null || _selectedBusinessTypeId! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a business type')),
      );
      return;
    }

    Navigator.pop(context);
    context.push(
      AvailableVendorsScreen.routeName,
      extra: AvailableVendorsScreenArgs.businessType(
        BusinessTypeVendorsParams(
          businessTypeId: _selectedBusinessTypeId!,
          businessTypeName: _selectedBusinessTypeName,
        ),
      ),
    );
  }

  InputDecoration buildInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AllColor.dropDown,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Colors.grey),
      ),
    );
  }
}
