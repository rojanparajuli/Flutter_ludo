import 'dart:math';

import 'package:flutter/foundation.dart';

import '../engine/ludo_engine.dart';
import '../model/ludo_dice_rules.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_piece.dart';
import '../model/ludo_player.dart';

/// Fired right after the dice is rolled, with the value (1-6) that came up.
typedef LudoDiceRolledCallback = void Function(int value);

/// Fired right after a piece finishes moving.
typedef LudoPieceMovedCallback = void Function(
  LudoPiece piece,
  int fromPosition,
  int toPosition,
);

/// Fired once per opponent piece captured as a result of a move.
typedef LudoPieceCapturedCallback = void Function(
  LudoPiece capturedPiece,
  LudoPiece byPiece,
);

/// Fired whenever the active player changes (including automatic passes
/// when a roll produces no legal moves).
typedef LudoTurnChangedCallback = void Function(int currentPlayerIndex);

/// Fired the moment a player wins (all 4 pieces finished). [place] is
/// 1-based (1 = first to finish).
typedef LudoPlayerWonCallback = void Function(int playerIndex, int place);

/// Fired once the overall game is over. [winnersInOrder] lists every
/// player index from first to last place.
typedef LudoGameFinishedCallback = void Function(List<int> winnersInOrder);

/// Owns and mutates all Ludo game state, and is the single entry point
/// developers should use to drive a game.
///
/// Internal state should never be mutated directly — use [rollDice] and
/// [selectPiece]. Listen to a [LudoController] like any other
/// [ChangeNotifier] (e.g. via `ListenableBuilder`), or rely on the
/// [LudoGame] widget, which already does this for you.
///
/// ```dart
/// final controller = LudoController(
///   players: const [
///     LudoPlayer(name: 'Red', color: Colors.red),
///     LudoPlayer(name: 'Green', color: Colors.green),
///     LudoPlayer(name: 'Yellow', color: Colors.yellow),
///     LudoPlayer(name: 'Blue', color: Colors.blue),
///   ],
///   diceRules: const LudoDiceRules(startAllowedValues: [6]),
///   onPlayerWon: (playerIndex, place) { ... },
/// );
/// ```
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
  })  : assert(
          players.length == 4,
          'flutter_ludo is fixed to exactly 4 players, per the '
          'specification.',
        ),
        assert(
          diceRules.startAllowedValues.isNotEmpty,
          'diceRules.startAllowedValues must contain at least one value, '
          'otherwise no piece could ever leave home.',
        ),
        _diceRoller = diceRoller ?? _defaultDiceRoller,
        _engine = LudoEngine(diceRules) {
    _state = _initialState(players);
  }

  static int _defaultDiceRoller() => 1 + Random().nextInt(6);

  /// Configurable dice behaviour. Board geometry and capture/win rules are
  /// fixed and not exposed here.
  final LudoDiceRules diceRules;

  final int Function() _diceRoller;
  final LudoEngine _engine;

  final LudoDiceRolledCallback? onDiceRolled;
  final LudoPieceMovedCallback? onPieceMoved;
  final LudoPieceCapturedCallback? onPieceCaptured;
  final LudoTurnChangedCallback? onTurnChanged;
  final LudoPlayerWonCallback? onPlayerWon;
  final LudoGameFinishedCallback? onGameFinished;

  late LudoGameState _state;

  /// Current, immutable snapshot of the whole game.
  LudoGameState get state => _state;

  static LudoGameState _initialState(List<LudoPlayer> players) {
    final pieces = <LudoPiece>[
      for (var player = 0; player < players.length; player++)
        for (var local = 0; local < 4; local++)
          LudoPiece(id: player * 4 + local, playerIndex: player),
    ];
    return LudoGameState(
      players: players,
      pieces: pieces,
      currentPlayerIndex: 0,
      phase: LudoTurnPhase.awaitingRoll,
    );
  }

  /// Rolls the dice (1-6) for the current player and computes the legal
  /// moves available with that value. If there are no legal moves, the
  /// turn is passed automatically and [onTurnChanged] fires.
  ///
  /// Returns the value rolled.
  int rollDice() {
    if (_state.isFinished) {
      throw StateError('Cannot roll dice: the game has already finished.');
    }
    if (_state.phase == LudoTurnPhase.awaitingPieceSelection) {
      throw StateError('Cannot roll dice: select a piece for the current '
          'roll first.');
    }

    final value = _diceRoller();
    onDiceRolled?.call(value);

    final result = _engine.roll(_state, value);
    _state = result.state;

    if (result.passed) {
      onTurnChanged?.call(_state.currentPlayerIndex);
    }

    notifyListeners();
    return value;
  }

  /// Moves the piece with [pieceId]. [pieceId] must be one of
  /// `state.legalMoves` for the current roll, or this throws.
  void selectPiece(int pieceId) {
    if (_state.phase != LudoTurnPhase.awaitingPieceSelection) {
      throw StateError('Cannot select a piece: roll the dice first, or the '
          'game has already finished.');
    }
    final isLegal = _state.legalMoves.any((m) => m.pieceId == pieceId);
    if (!isLegal) {
      throw ArgumentError(
          'Piece $pieceId is not a legal move for the current roll.');
    }

    final result = _engine.move(_state, pieceId);
    _state = result.state;

    onPieceMoved?.call(
      result.movedPiece,
      result.fromPosition,
      result.toPosition,
    );
    for (final captured in result.capturedPieces) {
      onPieceCaptured?.call(captured, result.movedPiece);
    }
    if (result.playerWon) {
      final place = _state.winners.indexOf(result.movedPiece.playerIndex) + 1;
      onPlayerWon?.call(result.movedPiece.playerIndex, place);
    }
    if (result.gameFinished) {
      onGameFinished?.call(List.unmodifiable(_state.winners));
    } else if (result.turnPassed) {
      onTurnChanged?.call(_state.currentPlayerIndex);
    }

    notifyListeners();
  }

  /// Resets the game to a fresh state, keeping the same players and rules.
  void reset() {
    _state = _initialState(_state.players);
    notifyListeners();
  }
}