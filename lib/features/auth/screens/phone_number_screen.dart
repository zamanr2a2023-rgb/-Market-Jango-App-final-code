import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../core/constants/api_control/auth_api.dart';
import '../../../core/utils/phone_e164_utils.dart';
import '../../../core/widget/custom_auth_button.dart';
import '../../../core/widget/global_snackbar.dart';
import '../../../core/widget/sreeen_brackground.dart';
import '../logic/register_name_&_phone_riverpod.dart';
import 'code_screen.dart';

class PhoneNumberScreen extends ConsumerStatefulWidget {
  const PhoneNumberScreen({super.key});
  static const String routeName = '/phoneNumberScreen';

  @override
  ConsumerState<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends ConsumerState<PhoneNumberScreen> {
  String _countryCode = '256';
  String _nationalNumber = '';

  String get _e164Phone => toE164Phone(
        countryCode: _countryCode,
        nationalNumber: _nationalNumber,
      );

  Future<void> _submit() async {
    final phone = _e164Phone;
    if (phone.length < 10) {
      GlobalSnackbar.show(
        context,
        title: "Error",
        message: "Please enter a valid phone number",
        type: CustomSnackType.error,
      );
      return;
    }

    final notifier = ref.read(postProvider.notifier);
    await notifier.send(
      keyname: 'phone',
      value: phone,
      url: AuthAPIController.registerPhone,
      context: context,
    );

    final result = ref.read(postProvider);
    result.when(
      data: (ok) {
        if (ok) {
          context.push(CodeScreen.routeName);
        } else {
          GlobalSnackbar.show(
            context,
            title: "Error",
            message: "Failed to save phone number",
            type: CustomSnackType.error,
          );
        }
      },
      error: (e, _) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        GlobalSnackbar.show(
          context,
          title: "Error",
          message: msg,
          type: CustomSnackType.error,
        );
      },
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(postProvider);
    final loading = state.isLoading;

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

                Center(
                  child: Text(
                    "Can we get to your \n number?",
                    style: textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 28.h),

                IntlPhoneField(
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '757477539',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                  initialCountryCode: 'UG',
                  disableLengthCheck: false,
                  onChanged: (phone) {
                    _countryCode = phone.countryCode;
                    _nationalNumber = phone.number;
                  },
                ),
                SizedBox(height: 28.h),

                Center(
                  child: Text(
                    "We’ll text you a code to verify you're really  \n "
                        "you Message and data rates may apply.\n "
                        "What happens if your number changes?",
                    textAlign: TextAlign.center,
                    style: textTheme.titleSmall,
                  ),
                ),
                SizedBox(height: 120.h),

                CustomAuthButton(
                  buttonText: loading ? "Please wait..." : "Next",
                  onTap: loading ? () {} : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
