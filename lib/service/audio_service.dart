import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Audio service for playing game sounds
class AudioService {
  AudioService({
    this._enabled = true,
    AudioPlayer? audioPlayer,
  })  : _audioPlayer = audioPlayer ?? AudioPlayer();

  bool _enabled;
  final AudioPlayer _audioPlayer;

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    if (!_enabled) {
      _audioPlayer.stop();
    }
  }

  /// Play dice roll sound
  Future<void> playDiceRoll() async {
    if (!_enabled) return;
    
    try {
      await _audioPlayer.play(
        AssetSource('dice/dice_roll.mp3'),
        volume: 0.8,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Audio playback failed: $e');
      }
    }
  }

  /// Play capture sound (optional)
  Future<void> playCapture() async {
    if (!_enabled) return;
    // Add capture sound if desired
  }

  /// Play win sound (optional)
  Future<void> playWin() async {
    if (!_enabled) return;
    // Add win sound if desired
  }

  /// Dispose audio player
  void dispose() {
    _audioPlayer.dispose();
  }
}