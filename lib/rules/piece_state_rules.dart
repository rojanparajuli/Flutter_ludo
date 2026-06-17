
import 'package:flutter_ludo/constant/board_constants.dart';
import 'package:flutter_ludo/model/ludo_piece.dart';
import 'package:flutter_ludo/model/piece_state.dart';

/// Derives [piece]'s current [LudoPieceState], using the fixed board
/// geometry to determine whether it currently sits on a safe cell.
LudoPieceState resolvePieceState(LudoPiece piece) {
  if (piece.isHome) return LudoPieceState.home;
  if (piece.isFinished) return LudoPieceState.finished;
  if (piece.isOnHomeStretch) return LudoPieceState.safe;

  final cell = globalCellOf(piece.playerIndex, piece.trackPosition);
  return isSafeCellIndex(cell) ? LudoPieceState.safe : LudoPieceState.active;
}