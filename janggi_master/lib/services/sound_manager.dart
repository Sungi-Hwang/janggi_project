import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound effects manager for game audio
class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _player = AudioPlayer();

  bool _soundEnabled = true;
  double _volume = 1.0;

  /// Enable or disable sound effects
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// Set global volume (0.0 to 1.0)
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _player.setVolume(_volume);
  }

  Future<void> _playSound(String assetPath) async {
    if (!_soundEnabled) return;
    try {
      await _player.stop();
      await _player.setVolume(_volume);
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('[SoundManager] Error playing $assetPath: $e');
    }
  }

  /// Play piece move sound
  Future<void> playMove() => _playSound('sounds/move.mp3');

  /// Play capture sound
  Future<void> playCapture() => _playSound('sounds/capture.mp3');

  /// Play check (장군) sound
  Future<void> playCheck() => _playSound('sounds/check.mp3');

  /// Play escape check (멍군) sound
  Future<void> playEscapeCheck() => _playSound('sounds/monggun.mp3');

  /// Play victory sound
  Future<void> playVictory() => _playSound('sounds/win.mp3');

  /// Play defeat sound
  Future<void> playDefeat() => _playSound('sounds/lose.mp3');

  /// Stop sound
  Future<void> stop() => _player.stop();

  /// Dispose resources
  void dispose() {
    _player.dispose();
  }
}
