import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:market_jango/core/constants/api_control/auth_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/core/widget/custom_auth_button.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/core/widget/sreeen_brackground.dart';
import 'package:market_jango/features/auth/logic/register_password_riverpod.dart';
import 'package:market_jango/features/auth/logic/register_user_riverpod.dart';
import 'package:market_jango/features/auth/screens/Congratulation.dart';
import 'package:market_jango/features/auth/screens/login/logic/obscureText_controller.dart';
import 'package:market_jango/features/auth/screens/login/logic/password_validator.dart';
import 'package:market_jango/features/buyer/data/visibility_zones_register_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_request.dart';

class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});
  static const String routeName = '/new_password_screen';

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedShipZone;
  String? _userType;
  bool _typeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserType();
  }

  Future<void> _loadUserType() async {
    final storage = AuthLocalStorage();
    final fromStorage = await storage.getUserType();
    final pref = await SharedPreferences.getInstance();
    final fromPref = pref.getString('user_type')?.toLowerCase();
    // In-memory selection from User Type screen (registration flow).
    final fromProvider = ref.read(userTypeP).trim().toLowerCase();

    String? resolved = fromStorage?.trim().toLowerCase();
    if (resolved == null || resolved.isEmpty) {
      resolved = fromPref?.trim().toLowerCase();
    }
    if (resolved == null || resolved.isEmpty) {
      // userTypeP values are like "Buyer" → buyer
      if (fromProvider.isNotEmpty) resolved = fromProvider;
    }

    if (!mounted) return;
    setState(() {
      _userType = resolved;
      _typeLoaded = true;
    });
  }

  bool get _isBuyer => (_userType ?? '').toLowerCase() == 'buyer';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (password != confirm) {
      GlobalSnackbar.show(context,
          title: "Error",
          message: "Passwords do not match",
          type: CustomSnackType.error);
      return;
    }

    if (_isBuyer &&
        (_selectedShipZone == null || _selectedShipZone!.trim().isEmpty)) {
      GlobalSnackbar.show(context,
          title: "Error",
          message: "Please select your shipping zone",
          type: CustomSnackType.error);
      return;
    }

    final notifier = ref.read(registerPasswordProvider.notifier);
    await notifier.setPassword(
      url: AuthAPIController.registerPassword,
      password: password,
      confirmPassword: confirm,
      shipZone: _isBuyer ? _selectedShipZone : null,
    );

    final state = ref.read(registerPasswordProvider);
    state.when(
      data: (ok) async {
        final type = (await AuthLocalStorage().getUserType()) ??
            (await SharedPreferences.getInstance()).getString('user_type');
        Logger().i(type);
        if (!mounted) return;
        if (ok) {
          GlobalSnackbar.show(context,
              title: "Success",
              message: "Password set successfully!",
              type: CustomSnackType.success);

          switch (type?.toLowerCase()) {
            case "buyer":
              context.pushReplacement(CongratulationScreen.routeName);
              break;
            case "transport":
              context.pushReplacement(CongratulationScreen.routeName);
              break;
            default:
              context.pushReplacement(AccountRequest.routeName);
          }
        }
      },
      error: (e, _) => GlobalSnackbar.show(context,
          title: "Error", message: e.toString(), type: CustomSnackType.error),
      loading: () {},
    );
  }

  Widget _zoneSection(AsyncValue<List<VisibilityZoneOption>> zonesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 24.h),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Shipping zone *',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Used for zone-based home banners and promotions',
          style: TextStyle(fontSize: 11.sp, color: Colors.black54),
        ),
        SizedBox(height: 12.h),
        zonesAsync.when(
          data: (zones) {
            if (zones.isEmpty) {
              return TextFormField(
                initialValue: _selectedShipZone,
                decoration: const InputDecoration(
                  hintText: 'Enter zone (e.g. UGANDA)',
                ),
                onChanged: (v) =>
                    setState(() => _selectedShipZone = v.trim()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Shipping zone is required';
                  }
                  return null;
                },
              );
            }
            return DropdownButtonFormField<String>(
              value: _selectedShipZone != null &&
                      zones.any((z) => z.name == _selectedShipZone)
                  ? _selectedShipZone
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Select shipping zone',
              ),
              items: zones
                  .map(
                    (z) => DropdownMenuItem(
                      value: z.name,
                      child: Text(z.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedShipZone = v),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Shipping zone is required';
                }
                return null;
              },
            );
          },
          loading: () => Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: const LinearProgressIndicator(minHeight: 2),
          ),
          error: (_, __) => TextFormField(
            decoration: const InputDecoration(
              hintText: 'Enter zone (e.g. UGANDA)',
              helperText: 'Could not load zone list — enter manually',
            ),
            onChanged: (v) => setState(() => _selectedShipZone = v.trim()),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Shipping zone is required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isObscure = ref.watch(passwordVisibilityProvider);
    final loading = ref.watch(registerPasswordProvider).isLoading;
    final t = Theme.of(context).textTheme;
    // Also react to in-memory registration selection immediately.
    final providerType = ref.watch(userTypeP).toLowerCase();
    final isBuyer = _isBuyer || (!_typeLoaded && providerType == 'buyer');
    final zonesAsync = isBuyer
        ? ref.watch(visibilityLocationsZonesProvider)
        : const AsyncValue<List<VisibilityZoneOption>>.data([]);

    return Scaffold(
      body: ScreenBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: 30.h),
                const CustomBackButton(),
                SizedBox(height: 80.h),
                Text('Create New Password', style: t.titleLarge),
                SizedBox(height: 30.h),
                Text(
                  'Type and confirm a secure new password for your account',
                  style: t.titleMedium!.copyWith(fontSize: 11.sp),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40.h),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: isObscure,
                  validator: passwordValidator,
                  decoration: InputDecoration(
                    hintText: "New Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => ref
                          .read(passwordVisibilityProvider.notifier)
                          .state = !isObscure,
                    ),
                  ),
                ),
                SizedBox(height: 30.h),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: isObscure,
                  validator: passwordValidator,
                  decoration: InputDecoration(
                    hintText: "Confirm Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => ref
                          .read(passwordVisibilityProvider.notifier)
                          .state = !isObscure,
                    ),
                  ),
                ),
                if (isBuyer) _zoneSection(zonesAsync),
                SizedBox(height: 40.h),
                CustomAuthButton(
                  buttonText: loading ? "Saving..." : "Save",
                  onTap: loading ? () {} : _submit,
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
