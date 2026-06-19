import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/ludo_engine.dart';
import '../model/ludo_dice_rules.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_piece.dart';
import '../model/ludo_player.dart';
import '../service/audio_service.dart';

typedef LudoDiceRolledCallback    = void Function(int value);
typedef LudoPieceMovedCallback    = void Function(LudoPiece piece, int from, int to);
typedef LudoPieceCapturedCallback = void Function(LudoPiece captured, LudoPiece by);
typedef LudoTurnChangedCallback   = void Function(int currentPlayerIndex);
typedef LudoPlayerWonCallback     = void Function(int playerIndex, int place);
typedef LudoGameFinishedCallback  = void Function(List<int> winnersInOrder);

class LudoController extends ChangeNotifier {
  LudoController({
    required List<LudoPlayer> players,
    this.diceRules = const LudoDiceRules(),
    int Function()? diceRoller,
    this.onDiceRolled,
    this.onPieceMoved,
    this.onPieceCaptured,
    this.onTurnChanged,
    this.onPlayerWon,
    this.onGameFinished,
    bool enableAudio = true,
    this.stepAnimationDuration = const Duration(milliseconds: 180),
  })  : assert(
          players.length >= 2 && players.length <= 4,
          'flutter_ludo supports 2 to 4 players.',
        ),
        assert(diceRules.startAllowedValues.isNotEmpty),
        _diceRoller = diceRoller ?? _defaultDiceRoller,
        _engine = LudoEngine(diceRules),
        _audio = AudioService(enabled: enableAudio) {
    _state = _initialState(players);
  }

  static int _defaultDiceRoller() => 1 + Random().nextInt(6);

  final LudoDiceRules diceRules;
  final Duration stepAnimationDuration;

  final int Function() _diceRoller;
  final LudoEngine _engine;
  final AudioService _audio;

  final LudoDiceRolledCallback?    onDiceRolled;
  final LudoPieceMovedCallback?    onPieceMoved;
  final LudoPieceCapturedCallback? onPieceCaptured;
  final LudoTurnChangedCallback?   onTurnChanged;
  final LudoPlayerWonCallback?     onPlayerWon;
  final LudoGameFinishedCallback?  onGameFinished;

  late LudoGameState _state;

  LudoPiece? _animatingPiece;
  int?       _animatingStep;
  bool       _isAnimating = false;

  LudoGameState get state          => _state;
  bool          get enableAudio    => _audio.enabled;
  bool          get isAnimating    => _isAnimating;
  LudoPiece?    get animatingPiece => _animatingPiece;

  void toggleAudio(bool enabled) {
    _audio.enabled = enabled;
    notifyListeners();
  }

  static LudoGameState _initialState(List<LudoPlayer> players) {
    // Only create pieces for the players that are actually in the game.
    // Unused home quadrants (indices >= players.length) are left empty.
    final pieces = [
      for (var p = 0; p < players.length; p++)
        for (var l = 0; l < 4; l++)
          LudoPiece(id: p * 4 + l, playerIndex: p),
    ];
    return LudoGameState(
      players: players,
      pieces: pieces,
      currentPlayerIndex: 0,
      phase: LudoTurnPhase.awaitingRoll,
      lastMovedPiece: null,
    );
  }

  int rollDice() {
    if (_state.isFinished) throw StateError('Game already finished.');
    if (_state.phase == LudoTurnPhase.awaitingPieceSelection) {
      throw StateError('Select a piece first.');
    }
    if (_isAnimating) throw StateError('Animation in progress.');

    final value = _diceRoller();
    _audio.playDiceRoll();
    onDiceRolled?.call(value);

    final result = _engine.roll(_state, value);
    _state = result.state;

    if (result.passed) {
      _state = _state.copyWith(clearLastMovedPiece: true);
      onTurnChanged?.call(_state.currentPlayerIndex);
      notifyListeners();
      return value;
    }

    notifyListeners();

    if (_state.legalMoves.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_state.phase == LudoTurnPhase.awaitingPieceSelection &&
            _state.legalMoves.length == 1) {
          selectPiece(_state.legalMoves.first.pieceId);
        }
      });
    }

    return value;
  }

  Future<void> selectPiece(int pieceId) async {
    if (_state.phase != LudoTurnPhase.awaitingPieceSelection) {
      throw StateError('Roll the dice first.');
    }
    if (_isAnimating) return;

    final move = _state.legalMoves.firstWhere(
      (m) => m.pieceId == pieceId,
      orElse: () => throw ArgumentError('Piece $pieceId is not a legal move.'),
    );

    final piece = _state.pieces.firstWhere((p) => p.id == pieceId);
    final steps = move.toPosition - move.fromPosition;

    _isAnimating    = true;
    _animatingPiece = piece;

    for (var step = 1; step <= steps; step++) {
      _animatingStep  = piece.trackPosition + step;
      _animatingPiece = piece.copyWith(trackPosition: _animatingStep!);
      notifyListeners();
      await _audio.playPieceMove();
      await Future.delayed(stepAnimationDuration);
    }

    _animatingPiece = null;
    _animatingStep  = null;
    _isAnimating    = false;

    final result = _engine.move(_state, pieceId);
    _state = result.state.copyWith(lastMovedPiece: result.movedPiece);

    onPieceMoved?.call(result.movedPiece, result.fromPosition, result.toPosition);

    for (final captured in result.capturedPieces) {
      _audio.playCapture();
      onPieceCaptured?.call(captured, result.movedPiece);
    }

    if (result.playerWon) {
      _audio.playWin();
      final place = _state.winners.indexOf(result.movedPiece.playerIndex) + 1;
      onPlayerWon?.call(result.movedPiece.playerIndex, place);
    } else if (result.movedPiece.isFinished) {
      _audio.playPieceHome();
    }

    if (result.gameFinished) {
      _audio.playGameOver();
      onGameFinished?.call(List.unmodifiable(_state.winners));
    } else if (result.turnPassed) {
      _state = _state.copyWith(clearLastMovedPiece: true);
      onTurnChanged?.call(_state.currentPlayerIndex);
    }

    notifyListeners();
  }

  void reset() {
    _isAnimating    = false;
    _animatingPiece = null;
    _animatingStep  = null;
    _state = _initialState(_state.players);
    notifyListeners();
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }
}