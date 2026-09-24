import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/admin/announcements/data/admin_announcements_api.dart';
import 'package:market_jango/features/admin/announcements/model/admin_announcement_model.dart';
import 'package:market_jango/features/buyer/data/visibility_zones_register_data.dart';
import 'package:market_jango/features/buyer/screens/cart/data/visibility_locations_data.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';

/// STEP_11 — admin create announcement (`POST /api/admin/announcements`).
/// SMS/WhatsApp delivery is handled by the backend.
class AdminAnnouncementsScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  static const String routeName = '/admin/announcements';

  @override
  ConsumerState<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState
    extends ConsumerState<AdminAnnouncementsScreen> {
  final _title = TextEditingController();
  String? _zone;
  bool _channelSms = true;
  bool _channelWhatsapp = true;
  bool _channelInApp = true;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  InputDecoration _fieldDec({required String label, String? hint}) {
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
        message: 'Zone is required',
        type: CustomSnackType.error,
      );
      return;
    }
    if (!_channelSms && !_channelWhatsapp && !_channelInApp) {
      GlobalSnackbar.show(
        context,
        title: 'Error',
        message: 'Select at least one channel',
        type: CustomSnackType.error,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final msg = await AdminAnnouncementsApi.instance.create(
        AdminAnnouncementRequest(
          title: title,
          channelSms: _channelSms,
          channelWhatsapp: _channelWhatsapp,
          channelInApp: _channelInApp,
          zone: zone,
        ),
      );
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Sent',
        message: msg,
        type: CustomSnackType.success,
      );
      _title.clear();
      setState(() {
        _zone = null;
        _channelSms = true;
        _channelWhatsapp = true;
        _channelInApp = true;
      });
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    decoration: _fieldDec(
                      label: 'Zone *',
                      hint: 'Enter zone name (e.g. Kampala)',
                    ),
                    onChanged: (v) => setState(() => _zone = v.trim()),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Zone list unavailable — enter a Zone Management name.',
                    style: TextStyle(fontSize: 11.sp, color: AllColor.black54),
                  ),
                ],
              );
            }
            final value = all.contains(_zone) ? _zone : null;
            return DropdownButtonFormField<String>(
              value: value,
              decoration: _fieldDec(label: 'Zone *'),
              items: all
                  .map(
                    (z) => DropdownMenuItem(value: z, child: Text(z)),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _zone = v),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) {
            if (names.isEmpty) {
              return TextFormField(
                decoration: _fieldDec(
                  label: 'Zone *',
                  hint: 'Enter zone name',
                ),
                onChanged: (v) => setState(() => _zone = v.trim()),
              );
            }
            final value = names.contains(_zone) ? _zone : null;
            return DropdownButtonFormField<String>(
              value: value,
              decoration: _fieldDec(label: 'Zone *'),
              items: names
                  .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _zone = v),
            );
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => deliveryZones.when(
        data: (fallback) {
          if (fallback.isEmpty) {
            return TextFormField(
              decoration: _fieldDec(
                label: 'Zone *',
                hint: 'Enter zone name',
              ),
              onChanged: (v) => setState(() => _zone = v.trim()),
            );
          }
          final value = fallback.contains(_zone) ? _zone : null;
          return DropdownButtonFormField<String>(
            value: value,
            decoration: _fieldDec(label: 'Zone *'),
            items: fallback
                .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                .toList(),
            onChanged:
                _submitting ? null : (v) => setState(() => _zone = v),
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(
          e.toString().replaceFirst('Exception: ', ''),
          style: TextStyle(color: AllColor.red, fontSize: 12.sp),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AllColor.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: Row(
                children: [
                  const CustomBackButton(),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Announcements',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                children: [
                  Text(
                    'Send an announcement by zone. SMS and WhatsApp are '
                    'delivered by the backend.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AllColor.black54,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: _title,
                    enabled: !_submitting,
                    decoration: _fieldDec(
                      label: 'Title *',
                      hint: 'Hello',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 14.h),
                  _zoneField(),
                  SizedBox(height: 16.h),
                  Text(
                    'Channels',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AllColor.grey200),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('SMS'),
                          value: _channelSms,
                          onChanged: _submitting
                              ? null
                              : (v) => setState(() => _channelSms = v),
                          activeThumbColor: AllColor.loginButtomColor,
                        ),
                        Divider(height: 1.h, color: AllColor.grey200),
                        SwitchListTile(
                          title: const Text('WhatsApp'),
                          value: _channelWhatsapp,
                          onChanged: _submitting
                              ? null
                              : (v) => setState(() => _channelWhatsapp = v),
                          activeThumbColor: AllColor.loginButtomColor,
                        ),
                        Divider(height: 1.h, color: AllColor.grey200),
                        SwitchListTile(
                          title: const Text('In-app'),
                          value: _channelInApp,
                          onChanged: _submitting
                              ? null
                              : (v) => setState(() => _channelInApp = v),
                          activeThumbColor: AllColor.loginButtomColor,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AllColor.loginButtomColor,
                        foregroundColor: AllColor.white,
                        disabledBackgroundColor: AllColor.grey200,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Text(
                        _submitting ? 'Sending...' : 'Send announcement',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
