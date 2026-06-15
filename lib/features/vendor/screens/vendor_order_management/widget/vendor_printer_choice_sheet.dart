import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/util/vendor_invoice_printer_service.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/util/vendor_printer_prefs.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// 58mm Bluetooth (OEM) or 80mm Wi‑Fi/Ethernet (Epson/Star).
class VendorPrinterChoiceSheet extends StatefulWidget {
  const VendorPrinterChoiceSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.build58Bytes,
    required this.build80Pdf,
    required this.pdfJobName,
    this.subtitle58,
    this.subtitle80,
  });

  final String title;
  final String? subtitle;
  final String? subtitle58;
  final String? subtitle80;
  final Future<List<int>> Function() build58Bytes;
  final Future<Uint8List> Function() build80Pdf;
  final String pdfJobName;

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? subtitle58,
    String? subtitle80,
    required Future<List<int>> Function() build58Bytes,
    required Future<Uint8List> Function() build80Pdf,
    required String pdfJobName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) => VendorPrinterChoiceSheet(
        title: title,
        subtitle: subtitle,
        subtitle58: subtitle58,
        subtitle80: subtitle80,
        build58Bytes: build58Bytes,
        build80Pdf: build80Pdf,
        pdfJobName: pdfJobName,
      ),
    );
  }

  @override
  State<VendorPrinterChoiceSheet> createState() =>
      _VendorPrinterChoiceSheetState();
}

class _VendorPrinterChoiceSheetState extends State<VendorPrinterChoiceSheet> {
  bool _busy = false;
  bool _loadingBt = true;
  String? _savedMac;
  String? _savedName;
  List<BluetoothInfo> _pairedDevices = [];
  BluetoothInfo? _activePrinter;

  @override
  void initState() {
    super.initState();
    _refreshBluetoothState();
  }

  Future<void> _refreshBluetoothState() async {
    setState(() => _loadingBt = true);
    try {
      final saved = await VendorPrinterPrefs.saved58Printer();
      List<BluetoothInfo> paired = [];
      try {
        paired = await VendorInvoicePrinterService.listPairedPrinters();
      } catch (_) {}

      BluetoothInfo? active;
      if (saved.mac != null || saved.name != null) {
        active = await VendorInvoicePrinterService.findPairedPrinter(
          mac: saved.mac,
          name: saved.name,
        );
      }
      active ??= paired.isEmpty
          ? null
          : () {
              final likely =
                  VendorInvoicePrinterService.likelyPrinters(paired);
              return likely.isNotEmpty ? likely.first : paired.first;
            }();

      if (!mounted) return;
      setState(() {
        _savedMac = saved.mac;
        _savedName = saved.name;
        _pairedDevices = paired;
        _activePrinter = active;
        _loadingBt = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBt = false);
    }
  }

  String get _btTitle {
    if (_activePrinter != null && _activePrinter!.name.trim().isNotEmpty) {
      return _activePrinter!.name.trim();
    }
    if (_savedName != null && _savedName!.trim().isNotEmpty) {
      return _savedName!.trim();
    }
    return '58mm Bluetooth';
  }

  String get _btSubtitle {
    if (widget.subtitle58 != null && widget.subtitle58!.trim().isNotEmpty) {
      return widget.subtitle58!.trim();
    }
    if (_activePrinter != null) {
      return 'Paired · ${_activePrinter!.macAdress}';
    }
    if (_pairedDevices.isEmpty) {
      return 'No paired devices — pair your printer in phone Bluetooth settings';
    }
    final count = VendorInvoicePrinterService.likelyPrinters(_pairedDevices).length;
    if (count > 0) {
      return '$count printer(s) detected · tap to choose';
    }
    return '${_pairedDevices.length} paired device(s) · tap to choose';
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Printed',
          message: 'Sent to printer successfully.',
          type: CustomSnackType.success,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Print failed',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print58(String mac, String name) async {
    final bytes = await widget.build58Bytes();
    await VendorInvoicePrinterService.print58RawBytes(
      bytes: bytes,
      macAddress: mac,
      printerName: name,
    );
  }

  Future<void> _print58Saved() async {
    final block = await VendorInvoicePrinterService.ensureBluetoothReady();
    if (block != null) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Bluetooth',
          message: block,
          type: CustomSnackType.error,
        );
      }
      return;
    }

    final mac = _savedMac;
    final name = _savedName ?? _activePrinter?.name ?? 'Printer';
    if ((mac == null || mac.isEmpty) && _activePrinter == null) {
      await _pickBluetoothPrinter();
      return;
    }

    final paired = _activePrinter ??
        await VendorInvoicePrinterService.findPairedPrinter(
          mac: mac,
          name: name,
        );
    if (paired == null) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Printer not found',
          message:
              'Saved printer "$name" is not paired on this phone. Select your printer (e.g. B1-H828033545).',
          type: CustomSnackType.error,
        );
      }
      await _pickBluetoothPrinter();
      return;
    }

    setState(() => _busy = true);
    try {
      await _print58(paired.macAdress, paired.name);
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Printed',
          message: 'Sent to printer successfully.',
          type: CustomSnackType.success,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Print failed',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
        );
        await _pickBluetoothPrinter();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickBluetoothPrinter() async {
    final block = await VendorInvoicePrinterService.ensureBluetoothReady();
    if (block != null) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Bluetooth',
          message: block,
          type: CustomSnackType.error,
        );
      }
      return;
    }

    List<BluetoothInfo> devices;
    try {
      devices = await VendorInvoicePrinterService.listPairedPrinters();
    } catch (e) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Error',
          message: e.toString(),
          type: CustomSnackType.error,
        );
      }
      return;
    }

    if (!mounted) return;
    if (devices.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'No printer',
        message:
            'Pair your 58mm printer (XPrinter, Goojprt, HSPOS, etc.) in phone Bluetooth settings, then try again.',
        type: CustomSnackType.error,
      );
      return;
    }

    final likely = VendorInvoicePrinterService.likelyPrinters(devices);
    final others = devices
        .where((d) => !likely.any((p) => p.macAdress == d.macAdress))
        .toList();

    final picked = await showModalBottomSheet<BluetoothInfo>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                  child: Text(
                    'Select Bluetooth printer',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (likely.isNotEmpty) ...[
                        _PickerSectionHeader(title: 'Detected printers'),
                        ...likely.map((d) => _PrinterListTile(device: d, ctx: ctx)),
                      ],
                      if (others.isNotEmpty) ...[
                        _PickerSectionHeader(
                          title: likely.isEmpty
                              ? 'Paired devices'
                              : 'Other paired devices',
                        ),
                        ...others.map((d) => _PrinterListTile(device: d, ctx: ctx)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null || !mounted) return;
    await VendorPrinterPrefs.save58Printer(
      mac: picked.macAdress,
      name: picked.name,
    );
    setState(() {
      _activePrinter = picked;
      _savedMac = picked.macAdress;
      _savedName = picked.name;
    });
    await _run(() => _print58(picked.macAdress, picked.name));
  }

  @override
  Widget build(BuildContext context) {
    final s80 = widget.subtitle80 ??
        'Epson / Star · system print dialog';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
        20.w,
        24.h + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 14.h),
              decoration: BoxDecoration(
                color: AllColor.grey300,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AllColor.orange50.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.print_rounded,
                  color: AllColor.loginButtomColor,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              widget.subtitle!,
              style: TextStyle(fontSize: 13.sp, color: AllColor.grey500),
            ),
          ],
          SizedBox(height: 16.h),
          if (_busy || _loadingBt)
            const Center(child: CircularProgressIndicator()),
          if (!_busy && !_loadingBt) ...[
            TextButton(
              onPressed: _pickBluetoothPrinter,
              child: Text(
                _activePrinter != null
                    ? 'Change Bluetooth printer'
                    : 'Select Bluetooth printer',
              ),
            ),
            SizedBox(height: 4.h),
            _PrintOptionTile(
              icon: Icons.bluetooth,
              title: _btTitle,
              subtitle: _btSubtitle,
              onTap: _print58Saved,
            ),
            SizedBox(height: 10.h),
            _PrintOptionTile(
              icon: Icons.wifi,
              title: '80mm Wi‑Fi / Ethernet',
              subtitle: s80,
              onTap: () => _run(() async {
                final pdf = await widget.build80Pdf();
                await VendorInvoicePrinterService.print80RawPdf(
                  pdfBytes: pdf,
                  jobName: widget.pdfJobName,
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickerSectionHeader extends StatelessWidget {
  const _PickerSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AllColor.grey500,
        ),
      ),
    );
  }
}

class _PrinterListTile extends StatelessWidget {
  const _PrinterListTile({required this.device, required this.ctx});

  final BluetoothInfo device;
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) {
    final isPrinter = VendorInvoicePrinterService.looksLikePrinter(device);
    return ListTile(
      leading: Icon(
        isPrinter ? Icons.print_outlined : Icons.bluetooth,
        color: isPrinter ? AllColor.loginButtomColor : AllColor.grey500,
      ),
      title: Text(device.name),
      subtitle: Text(device.macAdress),
      onTap: () => Navigator.pop(ctx, device),
    );
  }
}

class _PrintOptionTile extends StatelessWidget {
  const _PrintOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AllColor.white,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AllColor.grey200),
          ),
          child: Row(
            children: [
              Icon(icon, color: AllColor.loginButtomColor, size: 28.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.sp, color: AllColor.grey500),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AllColor.grey500),
            ],
          ),
        ),
      ),
    );
  }
}
