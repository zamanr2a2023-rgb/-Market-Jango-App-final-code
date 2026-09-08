import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/screen/buyer_massage/screen/global_massage_screen.dart';
import 'package:market_jango/core/screen/global_notification/screen/global_notifications_screen.dart';
import 'package:market_jango/core/screen/profile_screen/screen/global_profile_screen.dart';
import 'package:market_jango/features/buyer/screens/all_categori/screen/all_categori_screen.dart';
import 'package:market_jango/features/buyer/screens/cart/screen/cart_screen.dart';
import 'package:market_jango/features/navbar/provider/shell_tab_index_providers.dart';
import 'package:market_jango/features/navbar/screen/buyer_bottom_nav_bar.dart';
import 'package:market_jango/features/navbar/screen/driver_bottom_nav_bar.dart';
import 'package:market_jango/features/navbar/screen/transport_bottom_nav_bar.dart';
import 'package:market_jango/features/navbar/screen/vendor_bottom_nav.dart';

/// Profile/settings tab indices (matches each shell’s `_pages`).
const _buyerProfileTab = 4;
const _vendorProfileTab = 4;
const _driverProfileTab = 3;
const _transportProfileTab = 3;

/// After resetting password when user came from logged-in edit profile — go shell + Profile tab.
void navigateToShellProfileTabForUserType({
  required WidgetRef ref,
  required BuildContext context,
  required String userTypeRaw,
}) {
  final ut = userTypeRaw.toLowerCase().trim();
  _goShellWithTab(context, ut, _profileTabFor(ut));
}

/// After login: if [redirectTo] is a screen that lives inside a bottom-nav shell,
/// open that shell on the matching tab (so the nav bar is not missing).
///
/// Returns `true` when navigation was handled here.
bool navigatePostLoginRedirectToShell({
  required BuildContext context,
  required String userTypeRaw,
  required String redirectTo,
}) {
  final path = Uri.tryParse(redirectTo)?.path ?? redirectTo;
  final ut = userTypeRaw.toLowerCase().trim();

  // Settings / profile — every role has this as a shell tab.
  if (path == GlobalSettingScreen.routeName) {
    _goShellWithTab(context, ut, _profileTabFor(ut));
    return true;
  }

  // Chat — tab 1 on all shells.
  if (path == GlobalMassageScreen.routeName) {
    _goShellWithTab(context, ut, 1);
    return true;
  }

  // Vendor notifications tab.
  if (path == GlobalNotificationsScreen.routeName) {
    if (ut == 'vendor') {
      _goShellWithTab(context, ut, 2);
      return true;
    }
    _goShellWithTab(context, ut, 0);
    return true;
  }

  // Buyer-only shell tabs — other roles go to their home shell.
  if (path == CartScreen.routeName || path == CategoriesScreen.routeName) {
    if (ut == 'buyer') {
      final tab = path == CartScreen.routeName ? 3 : 2;
      _goShellWithTab(context, ut, tab);
      return true;
    }
    _goShellWithTab(context, ut, 0);
    return true;
  }

  return false;
}

int _profileTabFor(String ut) {
  if (ut == 'driver') return _driverProfileTab;
  if (ut == 'transport') return _transportProfileTab;
  if (ut == 'vendor') return _vendorProfileTab;
  return _buyerProfileTab;
}

void _goShellWithTab(BuildContext context, String ut, int tab) {
  final container = ProviderScope.containerOf(context);
  if (ut == 'vendor') {
    container.read(vendorShellTabIndexProvider.notifier).state = tab;
    context.go(VendorBottomNav.routeName);
    return;
  }
  if (ut == 'driver') {
    container.read(driverNavIndexProvider.notifier).state = tab;
    context.go(DriverBottomNavBar.routeName);
    return;
  }
  if (ut == 'transport') {
    container.read(transportNavIndexProvider.notifier).state = tab;
    context.go(TransportBottomNavBar.routeName);
    return;
  }
  // buyer (default)
  container.read(buyerShellTabIndexProvider.notifier).state = tab;
  context.go(BuyerBottomNavBar.routeName);
}
