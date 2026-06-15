import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/vendor_barcode/data/vendor_barcode_api.dart';
import 'vendor_barcode_product_detail_screen.dart';

class VendorBarcodeScanScreen extends StatefulWidget {
  const VendorBarcodeScanScreen({
    super.key,
    this.returnProductIdOnSuccess = false,
  });

  /// When true (e.g. opened from walk-in POS), successful lookup pops with
  /// `Navigator.pop(context, productId)` instead of opening product detail.
  final bool returnProductIdOnSuccess;

  static const routeName = '/vendor/barcodes/scan';

  @override
  State<VendorBarcodeScanScreen> createState() => _VendorBarcodeScanScreenState();
}

class _VendorBarcodeScanScreenState extends State<VendorBarcodeScanScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _scanLineController;
  final _manual = TextEditingController();
  bool _busy = false;
  DateTime? _lastDetect;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  Rect _barcodeScanWindow(Size size) {
    final width = size.width * 0.82;
    final height = width * 0.38;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.5),
      width: width,
      height: height,
    );
  }

  Future<void> _lookup(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _busy) return;
    final now = DateTime.now();
    if (_lastDetect != null &&
        now.difference(_lastDetect!) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastDetect = now;

    setState(() => _busy = true);
    try {
      final product = await VendorBarcodeApi.instance.scanBarcode(code);
      if (!mounted) return;
      await _controller.stop();
      if (!mounted) return;
      if (widget.returnProductIdOnSuccess) {
        context.pop(product.id);
        return;
      }
      context.pushReplacement(
        VendorBarcodeProductDetailScreen.routePath(product.id),
      );
    } catch (e) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Scan',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final codes = capture.barcodes;
    if (codes.isEmpty) return;
    final b = codes.first;
    final v = b.rawValue ?? b.displayValue;
    if (v == null || v.isEmpty) return;
    _lookup(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Scan barcode',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Torch',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final scanRect = _barcodeScanWindow(size);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      scanWindow: scanRect,
                      tapToFocus: true,
                    ),
                    IgnorePointer(
                      child: _ViewfinderOverlay(
                        scanRect: scanRect,
                        scanProgress: _scanLineController,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 20.h,
                      child: Text(
                        'Align barcode inside the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_busy)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          _ManualEntryPanel(
            controller: _manual,
            busy: _busy,
            onSubmit: () => _lookup(_manual.text),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay({
    required this.scanRect,
    required this.scanProgress,
  });

  final Rect scanRect;
  final Animation<double> scanProgress;

  static const _dimColor = Color(0x99000000);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: scanRect.top,
          child: const ColoredBox(color: _dimColor),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: scanRect.bottom,
          bottom: 0,
          child: const ColoredBox(color: _dimColor),
        ),
        Positioned(
          left: 0,
          top: scanRect.top,
          width: scanRect.left,
          height: scanRect.height,
          child: const ColoredBox(color: _dimColor),
        ),
        Positioned(
          left: scanRect.right,
          top: scanRect.top,
          right: 0,
          height: scanRect.height,
          child: const ColoredBox(color: _dimColor),
        ),
        AnimatedBuilder(
          animation: scanProgress,
          builder: (context, _) {
            return CustomPaint(
              painter: _FramePainter(
                scanRect: scanRect,
                lineY: scanRect.top + scanRect.height * scanProgress.value,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ],
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.scanRect,
    required this.lineY,
  });

  final Rect scanRect;
  final double lineY;

  @override
  void paint(Canvas canvas, Size size) {
    if (scanRect.isEmpty) return;

    const radius = 6.0;
    const cornerLen = 26.0;
    const stroke = 3.5;
    final rrect = RRect.fromRectAndRadius(
      scanRect,
      const Radius.circular(radius),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final accent = Paint()
      ..color = AllColor.loginButtomColor
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void drawCorner(
      Offset origin,
      Offset h,
      Offset v, {
      bool accentH = false,
      bool accentV = false,
    }) {
      canvas.drawLine(origin, origin + h * cornerLen, accentH ? accent : corner);
      canvas.drawLine(origin, origin + v * cornerLen, accentV ? accent : corner);
    }

    final r = scanRect;
    drawCorner(r.topLeft, const Offset(1, 0), const Offset(0, 1), accentH: true);
    drawCorner(r.topRight, const Offset(-1, 0), const Offset(0, 1), accentH: true);
    drawCorner(r.bottomLeft, const Offset(1, 0), const Offset(0, -1), accentH: true);
    drawCorner(r.bottomRight, const Offset(-1, 0), const Offset(0, -1), accentH: true);

    final lineLeft = scanRect.left + 18;
    final lineRight = scanRect.right - 18;
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF4ADE80),
          const Color(0xFF4ADE80),
          Colors.transparent,
        ],
        stops: const [0, 0.12, 0.88, 1],
      ).createShader(Rect.fromLTRB(lineLeft, lineY, lineRight, lineY + 2))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(lineLeft, lineY), Offset(lineRight, lineY), linePaint);

    canvas.drawLine(
      Offset(lineLeft, lineY),
      Offset(lineRight, lineY),
      Paint()
        ..color = const Color(0x664ADE80)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) {
    return oldDelegate.scanRect != scanRect || oldDelegate.lineY != lineY;
  }
}

class _ManualEntryPanel extends StatelessWidget {
  const _ManualEntryPanel({
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 16.h + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AllColor.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Icon(
                Icons.keyboard_outlined,
                size: 18.sp,
                color: AllColor.grey500,
              ),
              SizedBox(width: 8.w),
              Text(
                'Enter code manually',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                  color: AllColor.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: busy ? null : (_) => onSubmit(),
            style: TextStyle(fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'Paste or type barcode',
              hintStyle: TextStyle(color: AllColor.grey500, fontSize: 14.sp),
              filled: true,
              fillColor: const Color(0xFFF5F6F8),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: AllColor.grey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: AllColor.loginButtomColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 48.h,
            child: FilledButton.icon(
              onPressed: busy ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AllColor.loginButtomColor,
                disabledBackgroundColor: AllColor.loginButtomColor.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.search, size: 20),
              label: Text(
                'Look up product',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
