import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/api_control/auth_api.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/custom_auth_button.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/core/widget/sreeen_brackground.dart';
import 'package:market_jango/features/auth/screens/phone_number_screen.dart';
import '../data/route_data.dart';
import '../data/vendor_location_data.dart';
import '../logic/register_car_info_riverpod.dart';


class CarInfoScreen extends ConsumerStatefulWidget {
  const CarInfoScreen({super.key});
  static const String routeName = '/car_info';

  @override
  ConsumerState<CarInfoScreen> createState() => _CarInfoScreenState();
}

class _CarInfoScreenState extends ConsumerState<CarInfoScreen> {
  final _carNameCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String? _selectedRouteId;
  String? _selectedTransportType;
  List<File> _pickedFiles = [];
  bool _acceptedTerms = false;
  late final TapGestureRecognizer _termsTapRecognizer;

  static const List<String> _transportTypes = [
    'motorcycle',
    'car',
    'air',
    'water',
  ];

  String _labelForTransportType(String type) {
    if (type.isEmpty) return type;
    return '${type[0].toUpperCase()}${type.substring(1)}';
  }

  @override
  void initState() {
    super.initState();
    _termsTapRecognizer = TapGestureRecognizer()..onTap = _showTermsDialog;
  }

  @override
  void dispose() {
    _termsTapRecognizer.dispose();
    _carNameCtrl.dispose();
    _plateCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _showTermsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms and Conditions'),
        content: SingleChildScrollView(
          child: Text(
            'By registering as a driver on Market Jango, you agree that:\n\n'
            '• The vehicle and license information you provide is accurate and up to date.\n'
            '• You will comply with applicable traffic laws and safety requirements.\n'
            '• Uploaded documents (e.g. driving license) may be verified by the platform.\n'
            '• You are responsible for the service you provide to passengers and for any pricing '
            'you list, in line with platform rules.\n'
            '• The platform may update these terms; continued use after changes constitutes acceptance.\n\n'
            'For full legal terms, refer to any official policy documents published by Market Jango.',
            style: TextStyle(fontSize: 14.sp, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _pickedFiles = result.paths
            .where((e) => e != null && File(e).existsSync())
            .map((e) => File(e!))
            .toList();
      });
    }
  }

  Future<void> _submit() async {
    final zone = ref.read(selectedVendorZoneProvider)?.trim() ?? '';
    final stateName = ref.read(selectedVendorStateProvider)?.trim() ?? '';
    final town = ref.read(selectedVendorTownProvider)?.trim() ?? '';
    if (_carNameCtrl.text.trim().isEmpty ||
        _plateCtrl.text.trim().isEmpty ||
        zone.isEmpty ||
        stateName.isEmpty ||
        town.isEmpty ||
        _priceCtrl.text.trim().isEmpty ||
        _selectedTransportType == null ||
        _pickedFiles.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: "Error",
        message: "Please fill all fields and upload your documents",
        type: CustomSnackType.error,
      );
      return;
    }

    if (!_acceptedTerms) {
      GlobalSnackbar.show(
        context,
        title: "Error",
        message: "Please accept the Terms and Conditions to continue",
        type: CustomSnackType.error,
      );
      return;
    }

    final notifier = ref.read(driverRegisterProvider.notifier);
    await notifier.registerDriver(
      url: AuthAPIController.registerDriverCarInfo,
      carName: _carNameCtrl.text.trim(),
      numberPlate: _plateCtrl.text.trim(),
      price: _priceCtrl.text.trim(),
      transportType: _selectedTransportType!,
      routeId: _selectedRouteId,
      files: _pickedFiles,
      zone: zone,
      stateName: stateName,
      town: town,
    );

    await Future.delayed(const Duration(milliseconds: 100));
    final result = ref.read(driverRegisterProvider);

    if (!context.mounted) return;
    result.when(
      data: (driver) {
        if (driver == null) return;
        GlobalSnackbar.show(
          context,
          title: 'Success',
          message: 'Driver registered successfully!',
          type: CustomSnackType.success,
        );
        context.push(PhoneNumberScreen.routeName);
      },
      error: (e, _) => GlobalSnackbar.show(
        context,
        title: 'Error',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: CustomSnackType.error,
      ),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(driverRegisterProvider);
    final routeAsync = ref.watch(routeListProvider);
    final loading = asyncState.isLoading;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: ScreenBackground(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                SizedBox(height: 30.h),
                const CustomBackButton(),
                SizedBox(height: 20.h),
                Center(child: Text("Car Information", style: textTheme.titleLarge)),
                SizedBox(height: 8.h),
                Center(
                  child: Text(
                    "Add your vehicle, plate, and location",
                    style: textTheme.bodySmall,
                  ),
                ),
                SizedBox(height: 28.h),
                const _SectionTitle('Vehicle'),
                _Labeled(
                  label: 'Transport type',
                  child: _driverFieldShell(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Choose transport type'),
                        value: _selectedTransportType,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        items: _transportTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(
                              _labelForTransportType(type),
                              style: const TextStyle(color: Colors.black87),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedTransportType = value);
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                _Labeled(
                  label: 'Brand name',
                  child: TextFormField(
                    controller: _carNameCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. Toyota'),
                  ),
                ),
                SizedBox(height: 14.h),
                _Labeled(
                  label: 'Number plate',
                  child: TextFormField(
                    controller: _plateCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'e.g. UAX 123A'),
                  ),
                ),
                SizedBox(height: 22.h),
                const _SectionTitle('Location'),
                const _Labeled(label: 'Zone', child: _DriverZoneField()),
                SizedBox(height: 14.h),
                const _Labeled(label: 'State', child: _DriverStateField()),
                SizedBox(height: 14.h),
                const _Labeled(label: 'Town', child: _DriverTownField()),
                SizedBox(height: 22.h),
                const _SectionTitle('Route'),
                _Labeled(
                  label: 'Price',
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Enter your price'),
                  ),
                ),
                SizedBox(height: 14.h),

                /// Route dropdown
                _Labeled(
                  label: 'Driving route (optional)',
                  child: routeAsync.when(
                    data: (routes) {
                      return _driverFieldShell(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            hint: const Text('Select route if required'),
                            value: _selectedRouteId == null
                                ? null
                                : int.tryParse(_selectedRouteId!),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            items: routes.map((route) {
                              return DropdownMenuItem<int>(
                                value: route.id,
                                child: Text(
                                  route.name,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRouteId = value?.toString();
                              });
                            },
                          ),
                        ),
                      );
                    },
                    loading: () => _driverFieldShell(
                      child: const Text('Loading routes...'),
                    ),
                    error: (e, _) => Text('Failed to load routes: $e'),
                  ),
                ),

                SizedBox(height: 22.h),
                const _SectionTitle('Documents'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
                    child: Text(
                      'Driving license and other documents',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AllColor.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: _pickFiles,
                  child: Container(
                    height: 60.h,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AllColor.textBorderColor, width: 0.5.sp),
                      borderRadius: BorderRadius.circular(30.r),
                      color: AllColor.orange50,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _pickedFiles.isEmpty
                              ? 'Upload Multiple Files'
                              : '${_pickedFiles.length} file(s) selected',
                          style: TextStyle(
                            color: AllColor.textHintColor,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const Icon(Icons.upload_file),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24.h),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24.w,
                        height: 24.h,
                        child: Checkbox(
                          value: _acceptedTerms,
                          onChanged: (v) =>
                              setState(() => _acceptedTerms = v ?? false),
                          activeColor: AllColor.loginButtomColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AllColor.black.withValues(alpha: 0.65),
                                height: 1.35,
                              ),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms and Conditions',
                                  style: TextStyle(
                                    color: AllColor.loginButtomColor,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: _termsTapRecognizer,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24.h),
                CustomAuthButton(
                  buttonText: loading ? "Submitting..." : "Confirm",
                  onTap: loading ? () {} : _submit,
                ),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: AllColor.black,
          ),
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 6.w, bottom: 6.h),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2B6CB0),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

Widget _driverFieldShell({required Widget child}) {
  return Container(
    height: 60.h,
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: const Color(0xFFFEF8E7),
      borderRadius: BorderRadius.circular(30.r),
      border: Border.all(color: AllColor.textBorderColor, width: 0.5.sp),
    ),
    child: child,
  );
}

class _DriverZoneField extends ConsumerWidget {
  const _DriverZoneField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(vendorRegisterZonesProvider);
    final selected = ref.watch(selectedVendorZoneProvider);
    return _driverFieldShell(
      child: zonesAsync.when(
        data: (zones) {
          final value =
              selected != null && zones.contains(selected) ? selected : null;
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Select zone'),
              value: value,
              icon: const Icon(Icons.arrow_drop_down),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              items: zones
                  .map(
                    (z) => DropdownMenuItem<String>(
                      value: z,
                      child: Text(z, style: const TextStyle(color: Colors.black87)),
                    ),
                  )
                  .toList(),
              onChanged: zones.isEmpty
                  ? null
                  : (v) {
                      ref.read(selectedVendorZoneProvider.notifier).state = v;
                      ref.read(selectedVendorStateProvider.notifier).state = null;
                      ref.read(selectedVendorTownProvider.notifier).state = null;
                    },
            ),
          );
        },
        loading: () => const Text('Loading zones...'),
        error: (_, __) => InkWell(
          onTap: () => ref.invalidate(vendorRegisterZonesProvider),
          child: const Text('Tap to retry zones'),
        ),
      ),
    );
  }
}

class _DriverStateField extends ConsumerWidget {
  const _DriverStateField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(selectedVendorZoneProvider)?.trim() ?? '';
    final selected = ref.watch(selectedVendorStateProvider);
    if (zone.isEmpty) {
      return _driverFieldShell(child: const Text('Select zone first'));
    }
    final statesAsync = ref.watch(vendorRegisterStatesProvider(zone));
    return _driverFieldShell(
      child: statesAsync.when(
        data: (states) {
          final value =
              selected != null && states.contains(selected) ? selected : null;
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Select state'),
              value: value,
              icon: const Icon(Icons.arrow_drop_down),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              items: states
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s,
                      child: Text(s, style: const TextStyle(color: Colors.black87)),
                    ),
                  )
                  .toList(),
              onChanged: states.isEmpty
                  ? null
                  : (v) {
                      ref.read(selectedVendorStateProvider.notifier).state = v;
                      ref.read(selectedVendorTownProvider.notifier).state = null;
                    },
            ),
          );
        },
        loading: () => const Text('Loading states...'),
        error: (_, __) => InkWell(
          onTap: () => ref.invalidate(vendorRegisterStatesProvider(zone)),
          child: const Text('Tap to retry states'),
        ),
      ),
    );
  }
}

class _DriverTownField extends ConsumerWidget {
  const _DriverTownField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(selectedVendorZoneProvider)?.trim() ?? '';
    final stateName = ref.watch(selectedVendorStateProvider)?.trim() ?? '';
    final selected = ref.watch(selectedVendorTownProvider);
    if (zone.isEmpty) {
      return _driverFieldShell(child: const Text('Select zone first'));
    }
    if (stateName.isEmpty) {
      return _driverFieldShell(child: const Text('Select state first'));
    }
    final townParams = VendorRegisterTownParams(
      zone: zone,
      state: stateName,
    );
    final townsAsync = ref.watch(vendorRegisterTownsProvider(townParams));
    return _driverFieldShell(
      child: townsAsync.when(
        data: (towns) {
          final value =
              selected != null && towns.contains(selected) ? selected : null;
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Select town'),
              value: value,
              icon: const Icon(Icons.arrow_drop_down),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              items: towns
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t,
                      child: Text(t, style: const TextStyle(color: Colors.black87)),
                    ),
                  )
                  .toList(),
              onChanged: towns.isEmpty
                  ? null
                  : (v) {
                      ref.read(selectedVendorTownProvider.notifier).state = v;
                    },
            ),
          );
        },
        loading: () => const Text('Loading towns...'),
        error: (_, __) => InkWell(
          onTap: () => ref.invalidate(vendorRegisterTownsProvider(townParams)),
          child: const Text('Tap to retry towns'),
        ),
      ),
    );
  }
}
