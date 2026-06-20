import 'package:flutter_ludo/service/ludo_team.dart';

import '../constant/board_constants.dart';
import '../model/legal_move.dart';
import '../model/ludo_dice_rules.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_piece.dart';

/// Computes all legal moves for the current player given [diceValue].
///
/// Teams mode additions:
/// - A piece may land on a cell occupied by a teammate (friendly stack).
/// - A piece may NOT land on a safe cell occupied by ANY opponent
///   (safe cell protection still applies).
/// - A piece MAY land on a non-safe cell occupied by opponents
///   (triggering a capture).
///
/// [teams] — pass null for standard mode.
List<LudoLegalMove> computeLegalMoves(
  LudoGameState state,
  LudoDiceRules diceRules,
  int diceValue, {
  List<LudoTeam>? teams,
}) {
  final moves       = <LudoLegalMove>[];
  final playerIndex = state.currentPlayerIndex;
  final myPieces    = state.pieces.where((p) => p.playerIndex == playerIndex);

  for (final piece in myPieces) {
    if (piece.isFinished) continue;

    if (piece.isHome) {
      // Can only leave home on an allowed start value.
      if (!diceRules.startAllowedValues.contains(diceValue)) continue;

      // Starting cell — check it's not blocked by an opponent safe-stack.
      if (_isBlockedByOpponent(
        playerIndex: playerIndex,
        trackPosition: 0,
        pieces: state.pieces,
        teams: teams,
      )) {
        continue;
      }

      moves.add(LudoLegalMove(
        pieceId: piece.id,
        playerIndex: playerIndex,
        fromPosition: LudoPiece.home,
        toPosition: 0,
      ));
      continue;
    }

    // On-board piece — advance by diceValue.
    final newPos = piece.trackPosition + diceValue;

    // Cannot overshoot the finish.
    if (newPos > LudoPiece.finished) continue;

    // Cannot land on a cell blocked by an opponent on a safe cell.
    if (newPos < LudoPiece.sharedPathSpan &&
        _isBlockedByOpponent(
          playerIndex: playerIndex,
          trackPosition: newPos,
          pieces: state.pieces,
          teams: teams,
        )) {
      continue;
    }

    moves.add(LudoLegalMove(
      pieceId: piece.id,
      playerIndex: playerIndex,
      fromPosition: piece.trackPosition,
      toPosition: newPos,
    ));
  }

  return moves;
}

/// Returns true if landing on [trackPosition] for [playerIndex] is blocked
/// by an OPPONENT piece sitting on a SAFE cell there.
///
/// In teams mode, teammates never block each other — a cell occupied only
/// by teammates is freely landable (forming a friendly stack).
bool _isBlockedByOpponent({
  required int playerIndex,
  required int trackPosition,
  required List<LudoPiece> pieces,
  required List<LudoTeam>? teams,
}) {
  final globalIdx = globalCellOf(playerIndex, trackPosition);
  if (!isSafeCellIndex(globalIdx)) return false;

  for (final p in pieces) {
    if (p.playerIndex == playerIndex) continue;
    if (areTeammates(p.playerIndex, playerIndex, teams)) continue;
    if (p.isHome || p.isFinished) continue;
    if (p.trackPosition >= LudoPiece.sharedPathSpan) continue;

    final pGlobal = globalCellOf(p.playerIndex, p.trackPosition);
    if (pGlobal == globalIdx) return true;
  }

  return false;
}