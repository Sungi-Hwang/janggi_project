import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sound effects manager for game audio
class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  AudioPlayer? _player;
  final Map<String, bool> _assetExistsCache = <String, bool>{};
  bool _pluginUnavailableLogged = false;

  bool _soundEnabled = true;
  double _volume = 1.0;

  AudioPlayer _ensurePlayer() => _player ??= AudioPlayer();

  /// Enable or disable sound effects
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// Set global volume (0.0 to 1.0)
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    final player = _player;
    if (player == null) return;

    try {
      player.setVolume(_volume);
    } on MissingPluginException {
      _logPluginUnavailable();
    } catch (e) {
      debugPrint('[SoundManager] Error setting volume: $e');
    }
  }

  Future<bool> _assetExists(String assetPath) async {
    final cached = _assetExistsCache[assetPath];
    if (cached != null) {
      return cached;
    }

    try {
      await rootBundle.load('assets/$assetPath');
      _assetExistsCache[assetPath] = true;
      return true;
    } catch (_) {
      _assetExistsCache[assetPath] = false;
      return false;
    }
  }

  void _logPluginUnavailable() {
    if (_pluginUnavailableLogged) return;
    _pluginUnavailableLogged = true;
    debugPrint('[SoundManager] Audio plugin unavailable in this environment');
  }

  Future<void> _playSound(List<String> assetPaths) async {
    if (!_soundEnabled) return;

    for (final assetPath in assetPaths) {
      if (!await _assetExists(assetPath)) {
        continue;
      }

      try {
        final player = _ensurePlayer();
        await player.stop();
        await player.play(
          AssetSource(assetPath),
          mode: PlayerMode.lowLatency,
          volume: _volume,
        );
        return;
      } on MissingPluginException {
        _logPluginUnavailable();
        return;
      } catch (e) {
        debugPrint('[SoundManager] Error playing $assetPath: $e');
        return;
      }
    }
  }

  /// Play piece move sound
  Future<void> playMove() =>
      _playSound(const ['sounds/move.wav', 'sounds/move.mp3']);

  /// Play capture sound
  Future<void> playCapture() =>
      _playSound(const ['sounds/move.wav', 'sounds/capture.mp3']);

  /// Play check sound
  Future<void> playCheck() =>
      _playSound(const ['sounds/janggun.wav', 'sounds/check.mp3']);

  /// Play escape check sound
  Future<void> playEscapeCheck() =>
      _playSound(const ['sounds/monggun.mp3']);

  /// Play victory sound
  Future<void> playVictory() =>
      _playSound(const ['sounds/janggun.wav', 'sounds/win.mp3']);

  /// Play defeat sound
  Future<void> playDefeat() =>
      _playSound(const ['sounds/monggun.mp3', 'sounds/lose.mp3']);

  /// Stop sound
  Future<void> stop() async {
    try {
      await _ensurePlayer().stop();
    } on MissingPluginException {
      _logPluginUnavailable();
    } catch (e) {
      debugPrint('[SoundManager] Error stopping audio: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
