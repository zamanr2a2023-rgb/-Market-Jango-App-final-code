import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/custom_auth_button.dart';
import 'package:market_jango/core/widget/sreeen_brackground.dart';
import 'package:market_jango/features/auth/screens/login/logic/email_validator.dart';
import 'package:market_jango/features/auth/screens/login/logic/login_riverpod.dart';
import 'package:market_jango/features/auth/screens/login/logic/obscureText_controller.dart';
import 'package:market_jango/features/auth/screens/user_type_screen.dart'
    show UserScreen;
import 'package:market_jango/features/navbar/screen/buyer_bottom_nav_bar.dart';
import '../../forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const String routeName = '/loginScreen';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenBackground(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                SizedBox(height: 30.h),
                const CustomBackButton(
                  fallbackRoute: BuyerBottomNavBar.routeName,
                ),
                const LoginHereText(),
                LoginTextFormField(
                  controllerEmail: _emailController,
                  controllerPassword: _passwordController,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginTextFormField extends ConsumerStatefulWidget {
  const LoginTextFormField({
    super.key,
    required this.controllerEmail,
    required this.controllerPassword,
  });

  final TextEditingController controllerEmail;
  final TextEditingController controllerPassword;

  @override
  ConsumerState<LoginTextFormField> createState() =>
      _LoginTextFormFieldState();
}

class _LoginTextFormFieldState extends ConsumerState<LoginTextFormField> {
  final _formKey = GlobalKey<FormState>();

  void _goToSignUp() {
    context.push(UserScreen.routeName);
  }

  void _goToForgotPassword() {
    context.push(ForgotPasswordScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final isObscure = ref.watch(passwordVisibilityProvider);
    return Form(
      key: _formKey,
      child: Column(
        children: [
          SizedBox(height: 28.h),
          TextFormField(
            autovalidateMode: AutovalidateMode.disabled,
            textInputAction: TextInputAction.next,
            controller: widget.controllerEmail,
            keyboardType: TextInputType.text,
            validator: loginEmailOrPhoneValidator,
            decoration: InputDecoration(
              hintText: "Email or Phone number",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
          ),
          SizedBox(height: 29.h),
          TextFormField(
            controller: widget.controllerPassword,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.disabled,
            validator: (_) => null,
            obscureText: isObscure,
            decoration: InputDecoration(
              hintText: "Password",
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(
                  isObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  ref.read(passwordVisibilityProvider.notifier).state =
                      !isObscure;
                },
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(height: 30.h),
              InkWell(
                onTap: _goToForgotPassword,
                child: Text(
                  "Forgot your Password?",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              SizedBox(height: 30.h),
              Consumer(
                builder: (context, ref, child) {
                  final loginState = ref.watch(loginStateProvider);
                  final isLoading = loginState.isLoading;
                  return CustomAuthButton(
                    buttonText: isLoading ? "Logging in..." : "Login",
                    onTap: () {
                      if (!isLoading &&
                          _formKey.currentState!.validate()) {
                        ref.read(loginStateProvider.notifier).login(
                              context: context,
                              email: widget.controllerEmail.text,
                              password: widget.controllerPassword.text,
                            );
                      }
                    },
                  );
                },
              ),
              SizedBox(height: 50.h),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  InkWell(
                    onTap: _goToSignUp,
                    borderRadius: BorderRadius.circular(4.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 4.h,
                      ),
                      child: Text(
                        "Sign up",
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: AllColor.loginButtomColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LoginHereText extends StatelessWidget {
  const LoginHereText({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        SizedBox(height: 50.h),
        Center(child: Text("Login Here", style: textTheme.titleLarge)),
        SizedBox(height: 12.h),
        Center(
          child: Text(
            "Welcome back you've \n been missed!",
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
