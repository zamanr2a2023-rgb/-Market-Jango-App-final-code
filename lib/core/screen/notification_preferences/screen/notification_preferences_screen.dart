import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/screen/notification_preferences/data/notification_preferences_api.dart';
import 'package:market_jango/core/screen/notification_preferences/model/notification_preferences_model.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';

/// STEP_11 — user channel preferences (`PUT /api/notification/preferences`).
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  static const String routeName = '/notification/preferences';

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  NotificationPreferences? _draft;
  bool _saving = false;

  void _ensureDraft(NotificationPreferences loaded) {
    _draft ??= loaded;
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    setState(() => _saving = true);
    try {
      final msg = await NotificationPreferencesApi.instance.update(draft);
      ref.invalidate(notificationPreferencesProvider);
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Saved',
        message: msg,
        type: CustomSnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Error',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationPreferencesProvider);

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
                      'Notification settings',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AllColor.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.toString().replaceFirst('Exception: ', ''),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8.h),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(notificationPreferencesProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (loaded) {
                  _ensureDraft(loaded);
                  final draft = _draft!;
                  return ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    children: [
                      Text(
                        'Choose how you want to receive alerts. '
                        'SMS and WhatsApp are delivered by the server.',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AllColor.black54,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _PrefCard(
                        children: [
                          _PrefSwitch(
                            title: 'SMS notifications',
                            subtitle: 'Text messages to your phone',
                            value: draft.notifySms,
                            onChanged: _saving
                                ? null
                                : (v) => setState(
                                      () => _draft =
                                          draft.copyWith(notifySms: v),
                                    ),
                          ),
                          Divider(height: 1.h, color: AllColor.grey200),
                          _PrefSwitch(
                            title: 'WhatsApp notifications',
                            subtitle: 'Messages via WhatsApp',
                            value: draft.notifyWhatsapp,
                            onChanged: _saving
                                ? null
                                : (v) => setState(
                                      () => _draft =
                                          draft.copyWith(notifyWhatsapp: v),
                                    ),
                          ),
                          Divider(height: 1.h, color: AllColor.grey200),
                          _PrefSwitch(
                            title: 'In-app notifications',
                            subtitle: 'Inbox and push alerts in the app',
                            value: draft.notifyInApp,
                            onChanged: _saving
                                ? null
                                : (v) => setState(
                                      () => _draft =
                                          draft.copyWith(notifyInApp: v),
                                    ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
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
                            _saving ? 'Saving...' : 'Save preferences',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefCard extends StatelessWidget {
  const _PrefCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AllColor.grey200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _PrefSwitch extends StatelessWidget {
  const _PrefSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AllColor.loginButtomColor,
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12.sp, color: AllColor.black54),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
    );
  }
}
