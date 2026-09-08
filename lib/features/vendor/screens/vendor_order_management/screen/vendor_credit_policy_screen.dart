import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/utils/get_user_type.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/core/widget/vendor_role_guard.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/vendor_order_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_orders_models.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/provider/vendor_orders_provider.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';

/// STEP_03 credit policy — Admin-configurable credit limit, due days, late fee.
/// Exposed to Vendor Owner in this app (no separate Admin Flutter module).
class VendorCreditPolicyScreen extends ConsumerStatefulWidget {
  const VendorCreditPolicyScreen({super.key});

  static const routeName = '/vendor/credit-policy';

  @override
  ConsumerState<VendorCreditPolicyScreen> createState() =>
      _VendorCreditPolicyScreenState();
}

class _VendorCreditPolicyScreenState
    extends ConsumerState<VendorCreditPolicyScreen> {
  final _limit = TextEditingController();
  final _dueDays = TextEditingController();
  final _lateFee = TextEditingController();
  bool _saving = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _limit.dispose();
    _dueDays.dispose();
    _lateFee.dispose();
    super.dispose();
  }

  void _hydrate(VendorCreditPolicy p) {
    if (_hydrated) return;
    _hydrated = true;
    _limit.text = p.creditLimit > 0 ? p.creditLimit.toStringAsFixed(2) : '';
    _dueDays.text = p.dueDays > 0 ? '${p.dueDays}' : '';
    _lateFee.text = p.lateFee > 0 ? p.lateFee.toStringAsFixed(2) : '';
  }

  Future<void> _save() async {
    final limit = double.tryParse(_limit.text.trim().replaceAll(',', ''));
    final days = int.tryParse(_dueDays.text.trim());
    final fee = double.tryParse(_lateFee.text.trim().replaceAll(',', ''));
    if (limit == null || limit < 0) {
      GlobalSnackbar.show(
        context,
        title: 'Credit limit',
        message: 'Enter a valid credit limit (0 or more).',
        type: CustomSnackType.error,
      );
      return;
    }
    if (days == null || days < 0) {
      GlobalSnackbar.show(
        context,
        title: 'Due date',
        message: 'Enter due days as a whole number (0 or more).',
        type: CustomSnackType.error,
      );
      return;
    }
    if (fee == null || fee < 0) {
      GlobalSnackbar.show(
        context,
        title: 'Late fee',
        message: 'Enter a valid late fee (0 or more).',
        type: CustomSnackType.error,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await VendorOrderApi.instance.updateCreditPolicy(
        VendorCreditPolicy(
          creditLimit: limit,
          dueDays: days,
          lateFee: fee,
        ),
      );
      ref.invalidate(vendorCreditPolicyProvider);
      _hydrated = false;
      _hydrate(updated);
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Saved',
        message: 'Credit policy updated.',
        type: CustomSnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Could not save',
        message:
            '${e.toString().replaceFirst('Exception: ', '')}\n'
            'Admin credit-policy API may be missing on the backend.',
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vendorCreditPolicyProvider);

    return VendorRoleGuard(
      allowedProvider: isVendorOwnerProvider,
      title: 'Credit policy',
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: AllColor.white,
          elevation: 0,
          leading: Padding(
            padding: EdgeInsets.only(left: 8.w),
            child: const CustomBackButton(),
          ),
          title: Text(
            'Credit policy',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: AllColor.black,
            ),
          ),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Text(e.toString()),
            ),
          ),
          data: (policy) {
            _hydrate(policy);
            return ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AllColor.blue500.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    'Admin / Owner configuration for walk-in Debt: '
                    'credit limit, payment due days, and late fee.\n\n'
                    'If save fails, the backend still needs '
                    '/api/admin/credit-policy (or /api/vendor/credit-policy).',
                    style: TextStyle(fontSize: 13.sp, height: 1.35),
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: _limit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Credit limit *',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _dueDays,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Due date (days) *',
                    hintText: 'e.g. 30',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _lateFee,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Late fee *',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 20.h),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AllColor.loginButtomColor,
                    minimumSize: Size(double.infinity, 48.h),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save policy'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
