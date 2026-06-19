import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Audio service for playing game sounds.
///
/// Each sound uses a dedicated [AudioPlayer] instance so sounds can overlap
/// without the previous clip being cut off (e.g. rapid dice rolls).
///
/// Asset paths assume the following entries in pubspec.yaml:
/// ```yaml
/// flutter:
///   assets:
///     - assets/audio/dice_roll.mp3
///     - assets/audio/piece_move.mp3
///     - assets/audio/piece_capture.mp3
///     - assets/audio/piece_home.mp3
///     - assets/audio/player_win.mp3
///     - assets/audio/game_over.mp3
/// ```
class AudioService {
  AudioService({this._enabled = true});

  bool _enabled;

  /// Whether sounds are currently played.
  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    if (!_enabled) _stopAll();
  }

  // One player per sound type so concurrent sounds don't cancel each other.
  final AudioPlayer _dicePlayer    = AudioPlayer();
  final AudioPlayer _movePlayer    = AudioPlayer();
  final AudioPlayer _capturePlayer = AudioPlayer();
  final AudioPlayer _homePlayer    = AudioPlayer();
  final AudioPlayer _winPlayer     = AudioPlayer();
  final AudioPlayer _gameOverPlayer= AudioPlayer();

  /// Dice-roll sound – called in [LudoController.rollDice].
  Future<void> playDiceRoll() => _play(_dicePlayer, 'audio/dice_roll.mp3');

  /// Piece-move tick – call once per step in the step-by-step animation.
  Future<void> playPieceMove() => _play(_movePlayer, 'audio/piece_move.mp3', volume: 0.5);

  /// Opponent piece sent back to home.
  Future<void> playCapture() => _play(_capturePlayer, 'audio/piece_capture.mp3');

  /// Piece reaches its home stretch finish cell.
  Future<void> playPieceHome() => _play(_homePlayer, 'audio/piece_home.mp3');

  /// A player has placed all 4 pieces in the centre.
  Future<void> playWin() => _play(_winPlayer, 'audio/player_win.mp3');

  /// All players have finished — overall game over.
  Future<void> playGameOver() => _play(_gameOverPlayer, 'audio/game_over.mp3');

  Future<void> _play(AudioPlayer player, String assetPath, {double volume = 0.8}) async {
    if (!_enabled) return;
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
    } catch (e) {
      if (kDebugMode) print('[AudioService] playback failed for $assetPath: $e');
    }
  }

  void _stopAll() {
    for (final p in _players) {
      p.stop();
    }
  }

  List<AudioPlayer> get _players => [
    _dicePlayer, _movePlayer, _capturePlayer,
    _homePlayer, _winPlayer, _gameOverPlayer,
  ];

  /// Release all native resources. Call from [LudoController.dispose].
  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
  }
}