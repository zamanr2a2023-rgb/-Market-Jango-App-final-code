import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Distinct POS continuous-scanner beeps (open / new line / qty++).
class PosScanSounds {
  PosScanSounds._();
  static final PosScanSounds instance = PosScanSounds._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> _play(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> scannerOpened() => _play('sounds/scan_open.wav');

  Future<void> productAddedNew() async {
    HapticFeedback.lightImpact();
    await _play('sounds/scan_new.wav');
  }

  Future<void> productQtyIncreased() async {
    HapticFeedback.selectionClick();
    await _play('sounds/scan_qty.wav');
  }
}
