import 'package:flutter/foundation.dart';

import 'ludo_player.dart';
import 'ludo_piece.dart';
import 'legal_move.dart';

/// Game phase, useful for driving UI (e.g. disabling the dice button while
/// a piece selection is pending).
enum LudoTurnPhase {
  /// Waiting for the current player to roll the dice.
  awaitingRoll,

  /// Dice has been rolled; waiting for the current player to pick a piece
  /// from [LudoGameState.legalMoves].
  awaitingPieceSelection,

  /// The whole game has finished. See [LudoGameState.isFinished] and
  /// [LudoGameState.winners].
  gameOver,
}

/// Immutable snapshot of the entire game, as exposed by [LudoController].
///
/// Exposes players, current turn, dice value, legal moves, winners, and
/// completion status, per the package specification.
@immutable
class LudoGameState {
  const LudoGameState({
    required this.players,
    required this.pieces,
    required this.currentPlayerIndex,
    required this.phase,
    this.diceValue,
    this.legalMoves = const [],
    this.winners = const [],
  });

  final List<LudoPlayer> players;
  final List<LudoPiece> pieces;
  final int currentPlayerIndex;
  final LudoTurnPhase phase;

  /// Value of the most recent dice roll for the current player, or `null`
  /// if the dice has not been rolled yet this turn.
  final int? diceValue;

  /// Moves the current player may legally make with [diceValue]. Empty if
  /// the dice hasn't been rolled yet, or if the most recent roll produced
  /// no legal moves (in which case the turn is passed automatically).
  final List<LudoLegalMove> legalMoves;

  /// Player indices in the order they finished (won), first to last. Once
  /// this contains `players.length - 1` entries the game is over and the
  /// one remaining player index is appended automatically in last place.
  final List<int> winners;

  bool get isFinished => phase == LudoTurnPhase.gameOver;

  List<LudoPiece> piecesOf(int playerIndex) =>
      pieces.where((p) => p.playerIndex == playerIndex).toList();

  LudoGameState copyWith({
    List<LudoPlayer>? players,
    List<LudoPiece>? pieces,
    int? currentPlayerIndex,
    LudoTurnPhase? phase,
    int? diceValue,
    bool clearDiceValue = false,
    List<LudoLegalMove>? legalMoves,
    List<int>? winners,
  }) {
    return LudoGameState(
      players: players ?? this.players,
      pieces: pieces ?? this.pieces,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      phase: phase ?? this.phase,
      diceValue: clearDiceValue ? null : (diceValue ?? this.diceValue),
      legalMoves: legalMoves ?? this.legalMoves,
      winners: winners ?? this.winners,
    );
  }
}