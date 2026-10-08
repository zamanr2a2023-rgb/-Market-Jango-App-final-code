import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/localization/Keys/buyer_kay.dart';
import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/core/screen/profile_screen/data/profile_data.dart';
import 'package:market_jango/core/utils/get_user_type.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/buyer/data/buyer_transport_enable_data.dart';
import 'package:market_jango/features/navbar/provider/shell_tab_index_providers.dart';
import 'package:market_jango/features/navbar/screen/buyer_bottom_nav_bar.dart';
import 'package:market_jango/features/navbar/screen/transport_bottom_nav_bar.dart';

/// Buyer profile: enable transport (POLISH) or open existing transport shell.
class BuyerTransportProfileEntry extends ConsumerWidget {
  const BuyerTransportProfileEntry({super.key});

  Future<void> _openTransport(BuildContext context, WidgetRef ref) async {
    ref.read(transportNavIndexProvider.notifier).state = 0;
    if (!context.mounted) return;
    context.push(TransportBottomNavBar.routeName);
  }

  Future<void> _enableAndOpen(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable transport'),
        content: const Text(
          'Activate shipping on your buyer account? You can book shipments '
          'with the same login — no separate account needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ref.t(BKeys.cancel, fallback: 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await enableBuyerTransportModule();
      invalidateBuyerTransportModule(ref);
      final userId = await ref.read(getUserIdProvider.future);
      if (userId != null && userId.isNotEmpty) {
        ref.invalidate(userProvider(userId));
      }
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        GlobalSnackbar.show(
          context,
          title: 'Transport',
          message: 'Transport is enabled for your account.',
          type: CustomSnackType.success,
        );
        await _openTransport(context, ref);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        GlobalSnackbar.show(
          context,
          title: 'Transport',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
        );
      }
    }
  }

  void _returnToBuyerHome(BuildContext context, WidgetRef ref) {
    ref.read(buyerShellTabIndexProvider.notifier).state = 0;
    context.go(BuyerBottomNavBar.routeName);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inTransportShell = ref.watch(transportShellActiveProvider);
    if (inTransportShell) {
      return _SettingsTile(
        leadingIcon: Icons.storefront_outlined,
        title: ref.t(BKeys.home, fallback: 'Marketplace'),
        subtitle: 'Back to buyer shopping',
        onTap: () => _returnToBuyerHome(context, ref),
      );
    }

    final canUse = ref.watch(buyerTransportModuleProvider);
    final mayEnable = ref.watch(buyerMayEnableTransportProvider);

    return canUse.when(
      data: (enabled) {
        if (enabled) {
          return _SettingsTile(
            leadingIcon: Icons.local_shipping_outlined,
            title: ref.t(BKeys.transport, fallback: 'Transport'),
            onTap: () => _openTransport(context, ref),
          );
        }
        return mayEnable.when(
          data: (showEnable) {
            if (!showEnable) return const SizedBox.shrink();
            return _SettingsTile(
              leadingIcon: Icons.local_shipping_outlined,
              title: 'Enable transport',
              onTap: () => _enableAndOpen(context, ref),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.leadingIcon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData leadingIcon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(leadingIcon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
