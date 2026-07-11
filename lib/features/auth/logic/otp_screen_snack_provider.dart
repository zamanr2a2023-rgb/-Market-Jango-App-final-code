import 'package:flutter_riverpod/flutter_riverpod.dart';

class OtpScreenSnack {
  const OtpScreenSnack({
    required this.title,
    required this.message,
    this.duration = const Duration(seconds: 10),
  });

  final String title;
  final String message;
  final Duration duration;
}

final otpScreenSnackProvider = StateProvider<OtpScreenSnack?>(
  (ref) => null,
);
