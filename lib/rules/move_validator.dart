

import 'package:flutter_ludo/model/legal_move.dart';
import 'package:flutter_ludo/model/ludo_dice_rules.dart';
import 'package:flutter_ludo/model/ludo_game_state.dart';
import 'package:flutter_ludo/model/ludo_piece.dart';

/// Computes every legal move available to `state.currentPlayerIndex` given
/// that [diceValue] was just rolled.
///
/// This enforces every rule from the specification's move-validation
/// section: a piece that is already finished never produces a move; a
/// piece still at home can only move if [diceRules] allows starting with
/// [diceValue]; and a piece already on the board can never move past the
/// final cell (position 56) — overshooting moves are simply omitted, which
/// is what requires an exact roll to finish.
List<LudoLegalMove> computeLegalMoves(
  LudoGameState state,
  LudoDiceRules diceRules,
  int diceValue,
) {
  final moves = <LudoLegalMove>[];
  final playerIndex = state.currentPlayerIndex;

  for (final piece in state.pieces) {
    if (piece.playerIndex != playerIndex) continue;
    if (piece.isFinished) continue;

    if (piece.isHome) {
      if (diceRules.canStartWith(diceValue)) {
        moves.add(LudoLegalMove(
          pieceId: piece.id,
          playerIndex: playerIndex,
          fromPosition: LudoPiece.home,
          toPosition: 0,
        ));
      }
      continue;
    }

    final destination = piece.trackPosition + diceValue;
    if (destination <= LudoPiece.finished) {
      moves.add(LudoLegalMove(
        pieceId: piece.id,
        playerIndex: playerIndex,
        fromPosition: piece.trackPosition,
        toPosition: destination,
      ));
    }
  }

  return moves;
}