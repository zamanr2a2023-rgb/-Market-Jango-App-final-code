import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/localization/Keys/buyer_kay.dart';
import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/core/screen/buyer_massage/screen/global_massage_screen.dart';
import 'package:market_jango/core/screen/profile_screen/screen/global_profile_screen.dart';
import 'package:market_jango/core/utils/auth_gate.dart';
import 'package:market_jango/features/buyer/screens/all_categori/screen/all_categori_screen.dart';
import 'package:market_jango/features/buyer/screens/buyer_home_screen.dart';
import 'package:market_jango/features/buyer/screens/cart/screen/cart_screen.dart';
import 'package:market_jango/features/navbar/provider/shell_tab_index_providers.dart';

class BuyerBottomNavBar extends ConsumerWidget {
  const BuyerBottomNavBar({super.key});

  static const String routeName = '/bottom_nav_bar';

  static const List<Widget> _pages = [
    BuyerHomeScreen(),
    GlobalMassageScreen(),
    CategoriesScreen(),
    CartScreen(),
    GlobalSettingScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(buyerShellTabIndexProvider);

    return Scaffold(
      body: _pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) async {
          // Chat (1), Categories (2), and Cart (3) require login for guests.
          if (index == 1 || index == 2 || index == 3) {
            final redirect = index == 3
                ? CartScreen.routeName
                : index == 1
                    ? GlobalMassageScreen.routeName
                    : CategoriesScreen.routeName;
            final ok = await AuthGate.requireAuth(
              context,
              redirectTo: redirect,
            );
            if (!ok) return;
          }
          ref.read(buyerShellTabIndexProvider.notifier).state = index;
        },
        backgroundColor: AllColor.white,
        selectedItemColor: AllColor.orange,
        unselectedItemColor: AllColor.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_filled),
            label: ref.t(BKeys.home),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: ref.t(BKeys.chat),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.widgets_outlined),
            label: ref.t(BKeys.categories),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.shopping_cart_outlined),
            label: ref.t(BKeys.cart),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: ref.t(BKeys.myProfile),
          ),
        ],
      ),
    );
  }
}
