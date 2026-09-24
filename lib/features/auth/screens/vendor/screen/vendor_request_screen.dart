import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:market_jango/core/constants/api_control/auth_api.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/screen/google_map/data/location_store.dart';
import 'package:market_jango/core/screen/google_map/screen/google_map.dart';
import 'package:market_jango/core/widget/custom_auth_button.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/core/widget/sreeen_brackground.dart';
import 'package:market_jango/features/auth/screens/phone_number_screen.dart';

import '../../../data/vendor_business_type_data.dart';
import '../../../data/vendor_location_data.dart';
import '../../../logic/register_vendor_request_riverpod.dart';

class VendorRequestScreen extends ConsumerWidget {
  const VendorRequestScreen({super.key});

  static const String routeName = '/vendor_request';

  Future<void> _pickFiles(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'doc', 'docx'],
    );

    if (result != null) {
      ref.read(pickedFilesProvider.notifier).state =
          result.paths.map((e) => File(e!)).toList();
    }
  }

  void _showCountryPicker(BuildContext context, WidgetRef ref) {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (country) {
        ref.read(selectedCountryProvider.notifier).state = country;
      },
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final country = ref.read(selectedCountryProvider);
    final businessName = ref.read(businessNameProvider);
    final businessType = ref.read(selectedBusinessTypeProvider);
    final address = ref.read(addressProvider);
    final files = ref.read(pickedFilesProvider);
    final latitude = ref.read(selectedLatitudeProvider);
    final longitude = ref.read(selectedLongitudeProvider);
    final zone = ref.read(selectedVendorZoneProvider);
    final vendorState = ref.read(selectedVendorStateProvider);
    final town = ref.read(selectedVendorTownProvider);

    if (country == null ||
        businessName.isEmpty ||
        businessType == null ||
        address.isEmpty ||
        files.isEmpty ||
        zone == null ||
        zone.isEmpty ||
        vendorState == null ||
        vendorState.isEmpty ||
        town == null ||
        town.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'Error',
        message:
            'Please fill all fields, select zone/state/town, and upload documents',
        type: CustomSnackType.error,
      );
      return;
    }

    ref.read(vendorLoadingProvider.notifier).state = true;

    final notifier = ref.read(vendorRegisterProvider.notifier);
    await notifier.registerVendor(
      url: AuthAPIController.registerVendorRequestStore,
      country: country.name,
      businessName: businessName,
      businessType: businessType,
      address: address,
      files: files,
      latitude: latitude,
      longitude: longitude,
      zone: zone,
      stateName: vendorState,
      town: town,
    );

    ref.read(vendorLoadingProvider.notifier).state = false;

    final state = ref.read(vendorRegisterProvider);
    state.when(
      data: (vendor) {
        if (vendor != null) {
          GlobalSnackbar.show(
            context,
            title: 'Success',
            message: 'Vendor registered successfully!',
            type: CustomSnackType.success,
          );
          context.push(PhoneNumberScreen.routeName);
        }
      },
      error: (e, _) => GlobalSnackbar.show(
        context,
        title: 'Error',
        message: e.toString(),
        type: CustomSnackType.error,
      ),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(selectedCountryProvider);
    final businessName = ref.watch(businessNameProvider);
    final address = ref.watch(addressProvider);
    final files = ref.watch(pickedFilesProvider);
    final loading = ref.watch(vendorLoadingProvider);
    final lat = ref.watch(selectedLatitudeProvider);
    final lng = ref.watch(selectedLongitudeProvider);

    return Scaffold(
      body: ScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                child: Row(
                  children: [
                    const CustomBackButton(),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Create Store',
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              color: AllColor.black,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Set up your shop in a few steps',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AllColor.grey500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 40.w),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 28.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StoreSectionCard(
                        title: 'Store details',
                        subtitle: 'Basic information about your business',
                        icon: Icons.storefront_rounded,
                        children: [
                          _FieldLabel('Country'),
                          _SelectTile(
                            value: country?.name,
                            placeholder: 'Choose your country',
                            onTap: () => _showCountryPicker(context, ref),
                          ),
                          SizedBox(height: 14.h),
                          _FieldLabel('Business name'),
                          _StoreTextField(
                            initialValue: businessName,
                            hint: 'e.g. Fresh Mart',
                            onChanged: (v) =>
                                ref.read(businessNameProvider.notifier).state =
                                    v,
                          ),
                          SizedBox(height: 14.h),
                          _FieldLabel('Business type'),
                          const BusinessTypeDropdown(),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      _StoreSectionCard(
                        title: 'Service area',
                        subtitle: 'Select zone, then state and town',
                        icon: Icons.map_outlined,
                        children: [
                          _FieldLabel('Zone'),
                          const VendorZoneDropdown(),
                          SizedBox(height: 14.h),
                          _FieldLabel('State'),
                          const VendorStateDropdown(),
                          SizedBox(height: 14.h),
                          _FieldLabel('Town'),
                          const VendorTownDropdown(),
                          SizedBox(height: 14.h),
                          _FieldLabel('Full address'),
                          _StoreTextField(
                            initialValue: address,
                            hint: 'Street, landmark, building…',
                            maxLines: 2,
                            onChanged: (v) =>
                                ref.read(addressProvider.notifier).state = v,
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      _StoreSectionCard(
                        title: 'Map pin',
                        subtitle: 'Optional — helps customers find you',
                        icon: Icons.location_on_outlined,
                        children: [
                          Material(
                            color: AllColor.orange50,
                            borderRadius: BorderRadius.circular(14.r),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14.r),
                              onTap: () async {
                                final result = await context.push<LatLng>(
                                  GoogleMapScreen.routeName,
                                );
                                if (result == null) return;
                                ref
                                    .read(selectedLatitudeProvider.notifier)
                                    .state = result.latitude;
                                ref
                                    .read(selectedLongitudeProvider.notifier)
                                    .state = result.longitude;
                                if (!context.mounted) return;
                                GlobalSnackbar.show(
                                  context,
                                  title: 'Success',
                                  message: 'Location selected',
                                  type: CustomSnackType.success,
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 14.h,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(color: AllColor.orange200),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 40.r,
                                      width: 40.r,
                                      decoration: BoxDecoration(
                                        color: AllColor.loginButtomColor
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(12.r),
                                      ),
                                      child: Icon(
                                        Icons.my_location_rounded,
                                        color: AllColor.loginButtomColor,
                                        size: 20.sp,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lat != null && lng != null
                                                ? 'Location selected'
                                                : 'Pick on map',
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            lat != null && lng != null
                                                ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                                                : 'Tap to open Google Map',
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              color: AllColor.grey500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: AllColor.grey500,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      _StoreSectionCard(
                        title: 'Documents',
                        subtitle: 'Upload license / ID / store photos',
                        icon: Icons.folder_open_rounded,
                        children: [
                          Material(
                            color: AllColor.white,
                            borderRadius: BorderRadius.circular(14.r),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14.r),
                              onTap: () => _pickFiles(context, ref),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 18.h,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: files.isEmpty
                                        ? AllColor.grey200
                                        : AllColor.orange200,
                                    style: BorderStyle.solid,
                                  ),
                                  color: files.isEmpty
                                      ? const Color(0xFFF8F9FA)
                                      : AllColor.orange50,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      files.isEmpty
                                          ? Icons.cloud_upload_outlined
                                          : Icons.check_circle_outline,
                                      color: AllColor.loginButtomColor,
                                      size: 28.sp,
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      files.isEmpty
                                          ? 'Tap to upload files'
                                          : '${files.length} file(s) selected',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'JPG, PNG, PDF, DOC',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: AllColor.grey500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      CustomAuthButton(
                        buttonText: loading ? 'Submitting...' : 'Continue',
                        onTap:
                            loading ? () {} : () => _submit(context, ref),
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

final selectedCountryProvider = StateProvider<Country?>((ref) => null);
final selectedBusinessTypeProvider = StateProvider<String?>((ref) => null);
final businessNameProvider = StateProvider<String>((ref) => '');
final addressProvider = StateProvider<String>((ref) => '');
final pickedFilesProvider = StateProvider<List<File>>((ref) => []);
final vendorLoadingProvider = StateProvider<bool>((ref) => false);

class _StoreSectionCard extends StatelessWidget {
  const _StoreSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 16.h),
      decoration: BoxDecoration(
        color: AllColor.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AllColor.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 38.r,
                width: 38.r,
                decoration: BoxDecoration(
                  color: AllColor.loginButtomColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: AllColor.loginButtomColor, size: 20.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AllColor.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AllColor.black87,
        ),
      ),
    );
  }
}

BoxDecoration _fieldShellDeco({bool enabled = true}) {
  return BoxDecoration(
    color: enabled ? AllColor.white : const Color(0xFFF3F4F6),
    borderRadius: BorderRadius.circular(14.r),
    border: Border.all(
      color: enabled ? AllColor.grey200 : AllColor.grey200.withValues(alpha: 0.8),
    ),
  );
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.placeholder,
    required this.onTap,
    this.value,
  });

  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          height: 52.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: _fieldShellDeco(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? value! : placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                    color: hasValue ? AllColor.black : AllColor.textHintColor,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AllColor.grey500,
                size: 22.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreTextField extends StatelessWidget {
  const _StoreTextField({
    required this.hint,
    required this.onChanged,
    this.initialValue,
    this.maxLines = 1,
  });

  final String? initialValue;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: AllColor.black,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(
          color: AllColor.textHintColor,
          fontWeight: FontWeight.w500,
          fontSize: 14.sp,
        ),
        filled: true,
        fillColor: AllColor.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: AllColor.grey200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: AllColor.grey200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: AllColor.loginButtomColor, width: 1.4),
        ),
      ),
    );
  }
}

Widget _dropdownShell({
  required Widget child,
  bool enabled = true,
}) {
  return Container(
    height: 52.h,
    padding: EdgeInsets.symmetric(horizontal: 14.w),
    decoration: _fieldShellDeco(enabled: enabled),
    alignment: Alignment.centerLeft,
    child: child,
  );
}

Widget _hintRow(String text, {bool showChevron = true}) {
  return Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color: AllColor.textHintColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      if (showChevron)
        Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AllColor.grey500,
          size: 22.sp,
        ),
    ],
  );
}

class BusinessTypeDropdown extends ConsumerWidget {
  const BusinessTypeDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessTypesAsync = ref.watch(businessTypesProvider);
    final selectedType = ref.watch(selectedBusinessTypeProvider);

    return _dropdownShell(
      child: businessTypesAsync.when(
        data: (types) {
          if (types.isEmpty) {
            return _hintRow('No business types found', showChevron: false);
          }
          final names = types.map((e) => e.name).toList();
          final value = selectedType != null && names.contains(selectedType)
              ? selectedType
              : null;
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Text(
                'Choose business type',
                style: TextStyle(
                  color: AllColor.textHintColor,
                  fontSize: 14.sp,
                ),
              ),
              value: value,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AllColor.grey500,
                size: 22.sp,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              items: types
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type.name,
                      child: Text(
                        type.name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AllColor.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                ref.read(selectedBusinessTypeProvider.notifier).state = value;
              },
            ),
          );
        },
        loading: () => Center(
          child: SizedBox(
            width: 20.r,
            height: 20.r,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AllColor.loginButtomColor,
            ),
          ),
        ),
        error: (err, stack) => InkWell(
          onTap: () => ref.invalidate(businessTypesProvider),
          child: _hintRow('Tap to retry types'),
        ),
      ),
    );
  }
}

class VendorZoneDropdown extends ConsumerWidget {
  const VendorZoneDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(vendorRegisterZonesProvider);
    final selected = ref.watch(selectedVendorZoneProvider);

    return _dropdownShell(
      child: zonesAsync.when(
        data: (zones) {
          if (zones.isEmpty) {
            return _hintRow('No zones found', showChevron: false);
          }
          final value =
              selected != null && zones.contains(selected) ? selected : null;
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Text(
                'Select zone',
                style: TextStyle(
                  color: AllColor.textHintColor,
                  fontSize: 14.sp,
                ),
              ),
              value: value,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AllColor.grey500,
                size: 22.sp,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              items: zones
                  .map(
                    (z) => DropdownMenuItem<String>(
                      value: z,
                      child: Text(
                        z,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AllColor.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                ref.read(selectedVendorZoneProvider.notifier).state = v;
                ref.read(selectedVendorStateProvider.notifier).state = null;
                ref.read(selectedVendorTownProvider.notifier).state = null;
              },
            ),
          );
        },
        loading: () => Center(
          child: SizedBox(
            width: 20.r,
            height: 20.r,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AllColor.loginButtomColor,
            ),
          ),
        ),
        error: (err, _) => InkWell(
          onTap: () => ref.invalidate(vendorRegisterZonesProvider),
          child: _hintRow('Tap to retry zones'),
        ),
      ),
    );
  }
}

class VendorStateDropdown extends ConsumerWidget {
  const VendorStateDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(selectedVendorZoneProvider)?.trim() ?? '';
    final selected = ref.watch(selectedVendorStateProvider);

    if (zone.isEmpty) {
      return _dropdownShell(
        enabled: false,
        child: _hintRow('Select zone first'),
      );
    }

    final statesAsync = ref.watch(vendorRegisterStatesProvider(zone));

    return _dropdownShell(
      child: statesAsync.when(
        data: (states) {
          if (states.isEmpty) {
            return _hintRow('No states for this zone', showChevron: false);
          }
          final value =
              selected != null && states.contains(selected) ? selected : null;
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Text(
                'Select state',
                style: TextStyle(
                  color: AllColor.textHintColor,
                  fontSize: 14.sp,
                ),
              ),
              value: value,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AllColor.grey500,
                size: 22.sp,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              items: states
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s,
                      child: Text(
                        s,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AllColor.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                ref.read(selectedVendorStateProvider.notifier).state = v;
                ref.read(selectedVendorTownProvider.notifier).state = null;
              },
            ),
          );
        },
        loading: () => Center(
          child: SizedBox(
            width: 20.r,
            height: 20.r,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AllColor.loginButtomColor,
            ),
          ),
        ),
        error: (err, _) => InkWell(
          onTap: () => ref.invalidate(vendorRegisterStatesProvider(zone)),
          child: _hintRow('Tap to retry states'),
        ),
      ),
    );
  }
}

class VendorTownDropdown extends ConsumerWidget {
  const VendorTownDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(selectedVendorZoneProvider)?.trim() ?? '';
    final selected = ref.watch(selectedVendorTownProvider);

    if (zone.isEmpty) {
      return _dropdownShell(
        enabled: false,
        child: _hintRow('Select zone first'),
      );
    }

    final townsAsync = ref.watch(vendorRegisterTownsProvider(zone));

    return _dropdownShell(
      child: townsAsync.when(
        data: (towns) {
          if (towns.isEmpty) {
            return _hintRow('No towns for this zone', showChevron: false);
          }
          final value =
              selected != null && towns.contains(selected) ? selected : null;
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Text(
                'Select town',
                style: TextStyle(
                  color: AllColor.textHintColor,
                  fontSize: 14.sp,
                ),
              ),
              value: value,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AllColor.grey500,
                size: 22.sp,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              items: towns
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t,
                      child: Text(
                        t,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AllColor.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                ref.read(selectedVendorTownProvider.notifier).state = v;
              },
            ),
          );
        },
        loading: () => Center(
          child: SizedBox(
            width: 20.r,
            height: 20.r,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AllColor.loginButtomColor,
            ),
          ),
        ),
        error: (err, _) => InkWell(
          onTap: () => ref.invalidate(vendorRegisterTownsProvider(zone)),
          child: _hintRow('Tap to retry towns'),
        ),
      ),
    );
  }
}
