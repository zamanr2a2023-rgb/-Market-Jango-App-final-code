import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/utils/auth_gate.dart';
import 'package:market_jango/core/utils/auth_session_utils.dart';
import 'package:market_jango/core/widget/custom_auth_button.dart';
import 'package:market_jango/features/auth/screens/login/screen/login_screen.dart';
import 'package:market_jango/features/auth/screens/user_type_screen.dart';
import 'package:market_jango/features/navbar/provider/shell_tab_index_providers.dart';
import 'package:market_jango/features/navbar/screen/buyer_bottom_nav_bar.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const String routeName = '/splashScreen';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// `null` = still checking; `true` = logged in (hide buttons); `false` = guest splash.
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final loggedIn = await AuthGate.isLoggedIn();
    if (!mounted) return;

    setState(() => _isLoggedIn = loggedIn);

    if (!loggedIn) return;

    // Hold branding for 2s, then go to role home (buyer/vendor/driver/transport).
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final homeRoute = await AuthSessionUtils.getHomeRouteForUserType();
    if (!mounted) return;

    if (homeRoute != null) {
      context.go(homeRoute);
    } else {
      // Logged in but unknown role — fall back to login.
      context.go(LoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAuthActions = _isLoggedIn == false;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 55.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logos.png',
                  height: 333.h,
                  width: 300.w,
                  fit: BoxFit.contain,
                ),
                if (showAuthActions)
                  const SplashScreenText()
                else ...[
                  SizedBox(height: 48.h),
                  Center(
                    child: Text(
                      'One Marketplace,\n Endless Possibilities',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  SizedBox(height: 28.h),
                  // Brief hold while redirecting logged-in users.
                  if (_isLoggedIn == true || _isLoggedIn == null)
                    const CircularProgressIndicator(strokeWidth: 2.4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SplashScreenText extends ConsumerWidget {
  const SplashScreenText({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        SizedBox(height: 48.h),
        Center(
          child: Text(
            'One Marketplace,\n Endless Possibilities',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
        ),
        SizedBox(height: 20.h),
        CustomAuthButton(
          buttonText: 'Login',
          onTap: () async {
            await AuthSessionUtils.handleSplashLoginClick(context);
          },
        ),
        SizedBox(height: 20.h),
        SplashSignUpButton(
          buttonText: 'Sign Up',
          onTap: () {
            context.push(UserScreen.routeName);
          },
        ),
        SizedBox(height: 20.h),
        TextButton(
          onPressed: () {
            // Guest browse — do not persist any login session.
            ref.read(buyerShellTabIndexProvider.notifier).state = 0;
            context.go(BuyerBottomNavBar.routeName);
          },
          child: Text(
            'Continue as Guest',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        SizedBox(height: 28.h),
      ],
    );
  }
}
