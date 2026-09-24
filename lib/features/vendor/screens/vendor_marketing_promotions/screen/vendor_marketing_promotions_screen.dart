import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/buyer/data/visibility_zones_register_data.dart';
import 'package:market_jango/features/buyer/screens/cart/data/visibility_locations_data.dart';
import 'package:market_jango/features/vendor/screens/vendor_marketing_promotions/data/vendor_promotion_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_marketing_promotions/model/vendor_promotion_model.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';

/// STEP_05 vendor marketing promotions (not affiliate links).
class VendorMarketingPromotionsScreen extends ConsumerStatefulWidget {
  const VendorMarketingPromotionsScreen({super.key});

  static const String routeName = '/vendor/marketing-promotions';

  @override
  ConsumerState<VendorMarketingPromotionsScreen> createState() =>
      _VendorMarketingPromotionsScreenState();
}

class _VendorMarketingPromotionsScreenState
    extends ConsumerState<VendorMarketingPromotionsScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  String? _zone;
  File? _image;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  InputDecoration _fieldDec({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF0F6FF),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: AllColor.grey300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: AllColor.grey300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: AllColor.blue, width: 1.4),
      ),
    );
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _image = File(x.path));
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final zone = (_zone ?? '').trim();
    if (title.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'Error',
        message: 'Title is required',
        type: CustomSnackType.error,
      );
      return;
    }
    if (zone.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'Error',
        message: 'Target zone is required',
        type: CustomSnackType.error,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await VendorPromotionApi.create(
        title: title,
        zone: zone,
        content: _content.text.trim(),
        image: _image,
      );
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Submitted',
        message: 'Promotion sent for admin approval',
        type: CustomSnackType.success,
      );
      _title.clear();
      _content.clear();
      setState(() {
        _zone = null;
        _image = null;
      });
      ref.invalidate(vendorPromotionsListProvider);
    } catch (e) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Error',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _zoneField() {
    final zonesAsync = ref.watch(visibilityLocationsZonesProvider);
    final deliveryZones = ref.watch(visibilityZonesProvider);

    return zonesAsync.when(
      data: (zones) {
        final names = zones.map((e) => e.name).toList();
        return deliveryZones.when(
          data: (fallback) {
            final all = <String>{...names, ...fallback}.toList()..sort();
            if (all.isEmpty) {
              return TextFormField(
                decoration: _fieldDec(
                  label: 'Target zone *',
                  hint: 'e.g. Kampala',
                ),
                onChanged: (v) => setState(() => _zone = v.trim()),
              );
            }
            return DropdownButtonFormField<String>(
              value: _zone != null && all.contains(_zone) ? _zone : null,
              decoration: _fieldDec(label: 'Target zone *'),
              items: all
                  .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                  .toList(),
              onChanged: (v) => setState(() => _zone = v),
            );
          },
          loading: () => _zoneLoading(),
          error: (_, __) {
            if (names.isEmpty) {
              return TextFormField(
                decoration: _fieldDec(
                  label: 'Target zone *',
                  hint: 'e.g. Kampala',
                ),
                onChanged: (v) => setState(() => _zone = v.trim()),
              );
            }
            return DropdownButtonFormField<String>(
              value:
                  _zone != null && names.contains(_zone) ? _zone : null,
              decoration: _fieldDec(label: 'Target zone *'),
              items: names
                  .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                  .toList(),
              onChanged: (v) => setState(() => _zone = v),
            );
          },
        );
      },
      loading: () => _zoneLoading(),
      error: (_, __) => TextFormField(
        decoration: _fieldDec(
          label: 'Target zone *',
          hint: 'e.g. Kampala',
        ),
        onChanged: (v) => setState(() => _zone = v.trim()),
      ),
    );
  }

  Widget _zoneLoading() => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: const LinearProgressIndicator(minHeight: 2),
      );

  Widget _imagePicker() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 14.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F6FF),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AllColor.grey300),
        ),
        child: _image == null
            ? Row(
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: AllColor.blue, size: 28.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add image (optional)',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AllColor.black,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Tap to choose from gallery',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.file(
                      _image!,
                      width: 64.w,
                      height: 64.w,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Image selected',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Tap to change',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AllColor.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _image = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _promoCard(VendorPromotion p) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AllColor.grey300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (p.status.isNotEmpty)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: p.isApproved
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    p.status,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: p.isApproved ? Colors.green.shade700 : Colors.orange.shade800,
                    ),
                  ),
                ),
            ],
          ),
          if (p.zone.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              'Zone: ${p.zone}',
              style: TextStyle(fontSize: 12.sp, color: Colors.black54),
            ),
          ],
          if (p.content.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              p.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.sp, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(vendorPromotionsListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AllColor.white,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: const CustomBackButton(),
        ),
        title: Text(
          'Marketing promotions',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: AllColor.black,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 28.h),
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AllColor.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              'Create a zone-targeted promotion. After admin approval it can appear for buyers in that zone.\n'
              'This is not an affiliate link.',
              style: TextStyle(fontSize: 13.sp, height: 1.35),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'New promotion',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10.h),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: _fieldDec(
              label: 'Title *',
              hint: 'e.g. Weekend sale',
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _content,
            maxLines: 4,
            minLines: 3,
            decoration: _fieldDec(
              label: 'Content / text',
              hint: 'Describe the offer…',
            ),
          ),
          SizedBox(height: 12.h),
          _zoneField(),
          SizedBox(height: 12.h),
          _imagePicker(),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AllColor.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: _submitting
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Create promotion',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 28.h),
          Text(
            'Your promotions',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10.h),
          listAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: AllColor.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AllColor.grey300),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.campaign_outlined,
                          size: 36.sp, color: Colors.black38),
                      SizedBox(height: 8.h),
                      Text(
                        'No promotions listed yet',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Submit one above. A list appears when the backend supports GET /api/vendor/promotions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(children: items.map(_promoCard).toList());
            },
            loading: () => Padding(
              padding: EdgeInsets.all(24.w),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AllColor.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AllColor.grey300),
              ),
              child: Text(
                'Promotion list is unavailable. You can still create promotions above.',
                style: TextStyle(fontSize: 13.sp, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
