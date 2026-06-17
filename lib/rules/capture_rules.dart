

import 'package:flutter_ludo/constant/board_constants.dart';
import 'package:flutter_ludo/model/ludo_piece.dart';

/// Returns any opposing pieces captured because [mover] just landed on its
/// current cell.
///
/// Per the specification's fixed capture rules: landing on an opponent
/// piece sends it back to home, but pieces on safe cells can never be
/// captured, and this never affects pieces in a home stretch (each
/// player's home stretch is exclusive to them) or pieces belonging to the
/// same player as [mover].
List<LudoPiece> captureOpponents({
  required List<LudoPiece> pieces,
  required LudoPiece mover,
}) {
  if (!mover.isOnSharedPath) return const [];

  final moverCell = globalCellOf(mover.playerIndex, mover.trackPosition);
  if (isSafeCellIndex(moverCell)) return const [];

  return pieces
      .where((p) =>
          p.playerIndex != mover.playerIndex &&
          p.isOnSharedPath &&
          globalCellOf(p.playerIndex, p.trackPosition) == moverCell)
      .toList();
}