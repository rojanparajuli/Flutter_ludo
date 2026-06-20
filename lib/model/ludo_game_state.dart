import 'package:flutter/foundation.dart';
import 'package:flutter_ludo/service/ludo_team.dart';

import 'ludo_player.dart';
import 'ludo_piece.dart';
import 'legal_move.dart';

enum LudoTurnPhase { awaitingRoll, awaitingPieceSelection, gameOver }

/// Immutable snapshot of the entire game.
///
/// [teams] is non-null when teams mode is active.
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
    this.lastMovedPiece,
    this.teams,
  });

  final List<LudoPlayer>    players;
  final List<LudoPiece>     pieces;
  final int                 currentPlayerIndex;
  final LudoTurnPhase       phase;
  final int?                diceValue;
  final List<LudoLegalMove> legalMoves;
  final List<int>           winners;
  final LudoPiece?          lastMovedPiece;

  /// Non-null when the game was started in teams mode.
  final List<LudoTeam>? teams;

  bool get isFinished  => phase == LudoTurnPhase.gameOver;
  bool get isTeamsMode => teams != null;

  /// Returns the winning team (teams mode), or null.
  LudoTeam? get winningTeam {
    if (teams == null || winners.isEmpty) return null;
    for (final t in teams!) {
      if (t.playerIndices.every((i) => winners.contains(i))) return t;
    }
    return null;
  }

  /// Returns the team [playerIndex] belongs to, or null.
  LudoTeam? teamOf(int playerIndex) {
    if (teams == null) return null;
    for (final t in teams!) {
      if (t.contains(playerIndex)) return t;
    }
    return null;
  }

  /// Whether [a] and [b] are teammates.
  bool areTeammates(int a, int b) => teamOf(a) == teamOf(b) && teamOf(a) != null;

  List<LudoPiece> piecesOf(int playerIndex) =>
      pieces.where((p) => p.playerIndex == playerIndex).toList();

  LudoGameState copyWith({
    List<LudoPlayer>?    players,
    List<LudoPiece>?     pieces,
    int?                 currentPlayerIndex,
    LudoTurnPhase?       phase,
    int?                 diceValue,
    bool                 clearDiceValue = false,
    List<LudoLegalMove>? legalMoves,
    List<int>?           winners,
    LudoPiece?           lastMovedPiece,
    bool                 clearLastMovedPiece = false,
    List<LudoTeam>?      teams,
  }) {
    return LudoGameState(
      players:            players            ?? this.players,
      pieces:             pieces             ?? this.pieces,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      phase:              phase              ?? this.phase,
      diceValue:          clearDiceValue ? null : (diceValue ?? this.diceValue),
      legalMoves:         legalMoves         ?? this.legalMoves,
      winners:            winners            ?? this.winners,
      lastMovedPiece:     clearLastMovedPiece ? null : (lastMovedPiece ?? this.lastMovedPiece),
      teams:              teams              ?? this.teams,
    );
  }
}