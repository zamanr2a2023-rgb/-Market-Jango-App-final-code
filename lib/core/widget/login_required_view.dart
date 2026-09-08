import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/utils/auth_gate.dart';
import 'package:market_jango/core/widget/custom_auth_button.dart';

/// Friendly placeholder when a guest opens a login-required screen/action.
class LoginRequiredView extends StatelessWidget {
  const LoginRequiredView({
    super.key,
    this.title = 'Login required',
    this.message = 'Please log in to continue.',
    this.redirectTo,
    this.showBack = true,
  });

  final String title;
  final String message;
  final String? redirectTo;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AllColor.white,
      appBar: showBack
          ? AppBar(
              elevation: 0,
              backgroundColor: AllColor.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/bottom_nav_bar');
                  }
                },
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 56.sp,
                color: AllColor.orange,
              ),
              SizedBox(height: 16.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: AllColor.black,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.4,
                  color: AllColor.black54,
                ),
              ),
              SizedBox(height: 28.h),
              CustomAuthButton(
                buttonText: 'Log in',
                onTap: () {
                  final loc = AuthGate.loginLocation(redirectTo: redirectTo);
                  context.push(loc);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
