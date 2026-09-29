// show_shipping_contract_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <-- ADD
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_save_botton.dart';
import 'package:market_jango/features/buyer/screens/cart/logic/buyer_shiping_update_logic.dart';
import 'package:market_jango/features/buyer/screens/cart/logic/cart_data.dart';
import 'package:market_jango/features/buyer/screens/prement/model/prement_page_data_model.dart';

void showShippingContractSheet(
  BuildContext context,
  WidgetRef ref,
  PaymentPageData? ares,
) {
  final messenger = ScaffoldMessenger.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AllColor.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
    ),
    builder: (sheetContext) {
      return _ShippingContractForm(
        ref: ref,
        page: ares,
        onSaved: () {
          Navigator.of(sheetContext).pop();
          ref.invalidate(cartProvider);
          messenger.showSnackBar(
            const SnackBar(content: Text('Contact info updated')),
          );
        },
      );
    },
  );
}

class _ShippingContractForm extends StatefulWidget {
  const _ShippingContractForm({
    required this.ref,
    required this.page,
    required this.onSaved,
  });

  final WidgetRef ref;
  final PaymentPageData? page;
  final VoidCallback onSaved;

  @override
  State<_ShippingContractForm> createState() => _ShippingContractFormState();
}

class _ShippingContractFormState extends State<_ShippingContractForm> {
  late final TextEditingController _pickupNameCtrl;
  late final TextEditingController _pickupPhoneCtrl;
  late final TextEditingController _dropNameCtrl;
  late final TextEditingController _dropPhoneCtrl;
  late final TextEditingController _emailCtrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final buyer = widget.page?.buyer;
    final saved = widget.ref.read(savedDeliveryContactsProvider);
    _pickupNameCtrl = TextEditingController(
      text: firstFilledContact(buyer?.pickupContactName, saved?.pickupName),
    );
    _pickupPhoneCtrl = TextEditingController(
      text: firstFilledContact(buyer?.pickupContactPhone, saved?.pickupPhone),
    );
    if ((saved?.pickupName.isEmpty ?? true) &&
        (buyer?.pickupContactName.isEmpty ?? true)) {
      loadSavedDeliveryContacts().then((stored) {
        if (!mounted || stored == null) return;
        widget.ref.read(savedDeliveryContactsProvider.notifier).state = stored;
        if (_pickupNameCtrl.text.trim().isEmpty) {
          _pickupNameCtrl.text = stored.pickupName;
        }
        if (_pickupPhoneCtrl.text.trim().isEmpty) {
          _pickupPhoneCtrl.text = stored.pickupPhone;
        }
      });
    }
    _dropNameCtrl = TextEditingController(
      text: (buyer?.dropContactName.isNotEmpty ?? false)
          ? buyer!.dropContactName
          : (buyer?.shipName ?? ''),
    );
    _dropPhoneCtrl = TextEditingController(
      text: (buyer?.dropContactPhone.isNotEmpty ?? false)
          ? buyer!.dropContactPhone
          : (buyer?.shipPhone ?? ''),
    );
    _emailCtrl = TextEditingController(text: buyer?.shipEmail ?? '');
  }

  @override
  void dispose() {
    final pickupNameCtrl = _pickupNameCtrl;
    final pickupPhoneCtrl = _pickupPhoneCtrl;
    final dropNameCtrl = _dropNameCtrl;
    final dropPhoneCtrl = _dropPhoneCtrl;
    final emailCtrl = _emailCtrl;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pickupNameCtrl.dispose();
      pickupPhoneCtrl.dispose();
      dropNameCtrl.dispose();
      dropPhoneCtrl.dispose();
      emailCtrl.dispose();
    });
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final pickupName = _pickupNameCtrl.text.trim();
    final pickupPhone = _pickupPhoneCtrl.text.trim();
    final dropName = _dropNameCtrl.text.trim();
    final dropPhone = _dropPhoneCtrl.text.trim();
    String? error;
    if (pickupName.isEmpty || dropName.isEmpty) {
      error = 'Pickup and drop name are required.';
    } else if (!isValidContactPhone(pickupPhone) ||
        !isValidContactPhone(dropPhone)) {
      error = 'Enter a valid phone number for pickup and drop.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.ref.read(userUpdateServiceProvider).updateUserFields(
        fields: {
          'pickup_contact_name': pickupName,
          'pickup_contact_phone': pickupPhone,
          'drop_contact_name': dropName,
          'drop_contact_phone': dropPhone,
          'ship_name': dropName,
          'ship_phone': dropPhone,
          if (_emailCtrl.text.trim().isNotEmpty)
            'ship_email': _emailCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      final saved = SavedDeliveryContacts(
        pickupName: pickupName,
        pickupPhone: pickupPhone,
        dropName: dropName,
        dropPhone: dropPhone,
      );
      widget.ref.read(savedDeliveryContactsProvider.notifier).state = saved;
      await persistSavedDeliveryContacts(saved);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 8.w, 16.h),
              decoration: BoxDecoration(
                color: AllColor.blue.withOpacity(0.08),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Shipping Contract',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AllColor.black,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.close, color: AllColor.black),
                    splashRadius: 20.r,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextFormField(
                      label: 'Pickup name',
                      controller: _pickupNameCtrl,
                      hintText: 'Pickup contact name',
                    ),
                    SizedBox(height: 12.h),
                    CustomTextFormField(
                      label: 'Pickup phone',
                      controller: _pickupPhoneCtrl,
                      hintText: 'Pickup phone',
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 12.h),
                    CustomTextFormField(
                      label: 'Drop name',
                      controller: _dropNameCtrl,
                      hintText: 'Drop contact name',
                    ),
                    SizedBox(height: 12.h),
                    CustomTextFormField(
                      label: 'Drop phone',
                      controller: _dropPhoneCtrl,
                      hintText: 'Drop phone',
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 12.h),
                    CustomTextFormField(
                      label: 'Email Address',
                      controller: _emailCtrl,
                      hintText: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (_error != null) ...[
                      SizedBox(height: 12.h),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: const Color(0xFFB91C1C),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    SizedBox(height: 12.h),
                    GlobalSaveBotton(
                      bottonName: _saving ? 'Saving...' : 'Save Changes',
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomTextFormField extends StatelessWidget {
  const CustomTextFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AllColor.black,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: AllColor.textHintColor,
              fontSize: 14.sp,
            ),
            filled: true,
            fillColor: const Color(0xFFE6F0F8),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 12.h,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(
                color: Color(0xFF0168B8),
                width: 0.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(
                color: Color(0xFF0168B8),
                width: 0.2,
              ),
            ),
          ),
          style: TextStyle(color: AllColor.black, fontSize: 14.sp),
        ),
      ],
    );
  }
}
