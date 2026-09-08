import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/core/utils/get_token_sharedpefarens.dart';
import 'package:market_jango/features/auth/screens/login/screen/login_screen.dart';
import 'package:market_jango/features/buyer/screens/billing/screen/buyer_billing_screen.dart';
import 'package:market_jango/features/buyer/screens/billing/screen/buyer_invoice_details_screen.dart';
import 'package:market_jango/features/buyer/screens/cart/screen/cart_screen.dart';
import 'package:market_jango/features/buyer/screens/order/screen/buyer_order_history_screen.dart';
import 'package:market_jango/features/buyer/screens/order/screen/buyer_order_page.dart';
import 'package:market_jango/features/buyer/screens/prement/screen/buyer_payment_screen.dart';
import 'package:market_jango/features/buyer/screens/refunds/screen/buyer_refund_detail_screen.dart';
import 'package:market_jango/features/buyer/screens/refunds/screen/buyer_refunds_screen.dart';
import 'package:market_jango/features/buyer/screens/wallet/screen/buyer_wallet_screen.dart';
import 'package:market_jango/core/screen/buyer_massage/screen/global_massage_screen.dart';
import 'package:market_jango/core/screen/following/screen/my_following_screen.dart';
import 'package:market_jango/core/screen/global_tracking_screen/screen/global_tracking_screen_1.dart';

/// Buyer auth gate — guest = no valid *login* token (registration token does not count).
class AuthGate {
  AuthGate._();

  static final AuthLocalStorage _storage = AuthLocalStorage();

  /// True only when the user completed login (not guest, not mid-registration).
  static Future<bool> isLoggedIn() async {
    final hasFlag = await _storage.hasLoggedInBefore();
    final token = await _storage.getLoginToken();
    return hasFlag && token != null && token.isNotEmpty;
  }

  static Future<bool> isGuest() async => !(await isLoggedIn());

  /// Paths that require a logged-in buyer session.
  static final Set<String> protectedBuyerPaths = {
    CartScreen.routeName,
    BuyerPaymentScreen.routeName,
    BuyerWalletScreen.routeName,
    BuyerOrderPage.routeName,
    BuyerOrderHistoryScreen.routeName,
    BuyerBillingScreen.routeName,
    BuyerInvoiceDetailsScreen.routeName,
    BuyerRefundsScreen.routeName,
    BuyerRefundDetailScreen.routeName,
    GlobalMassageScreen.routeName,
    MyFollowingScreen.routeName,
    GlobalTrackingScreen1.routeName,
  };

  static bool isProtectedBuyerPath(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    for (final p in protectedBuyerPaths) {
      if (path == p || path.startsWith('$p/')) return true;
    }
    return false;
  }

  /// Login URL that returns to [redirectTo] after success.
  static String loginLocation({String? redirectTo}) {
    if (redirectTo == null || redirectTo.isEmpty) {
      return LoginScreen.routeName;
    }
    return Uri(
      path: LoginScreen.routeName,
      queryParameters: {'redirect': redirectTo},
    ).toString();
  }

  /// If logged in → `true`. If guest → navigate to login and return `false`.
  ///
  /// Does **not** retry the caller's action; after login the user lands on
  /// [redirectTo] (or current location) so they can continue.
  static Future<bool> requireAuth(
    BuildContext context, {
    String? redirectTo,
    bool replace = false,
  }) async {
    if (await isLoggedIn()) return true;
    if (!context.mounted) return false;

    String target = redirectTo ?? '';
    if (target.isEmpty) {
      try {
        target = GoRouterState.of(context).uri.toString();
      } catch (_) {
        target = '';
      }
    }

    final loc = loginLocation(redirectTo: target.isEmpty ? null : target);
    if (replace) {
      context.go(loc);
    } else {
      context.push(loc);
    }
    return false;
  }
}

/// Reactive login flag — refreshes when [authTokenProvider] is invalidated.
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  await ref.watch(authTokenProvider.future);
  return AuthGate.isLoggedIn();
});
