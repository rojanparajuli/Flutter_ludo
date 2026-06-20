import 'package:flutter_ludo/service/ludo_team.dart';

import '../constant/board_constants.dart';
import '../model/ludo_piece.dart';

/// Determines which opponent pieces are captured when [mover] lands on a cell.
///
/// **Teams mode rules:**
/// - Teammates are never captured by each other.
/// - If an opponent lands on a cell containing a teammate stack (1 or 2
///   pieces), ALL pieces on that cell are sent home together.
/// - Safe cells still protect everyone on them.
///
/// [teams] — pass null for standard (non-teams) mode.
List<LudoPiece> captureOpponents({
  required List<LudoPiece> pieces,
  required LudoPiece mover,
  List<LudoTeam>? teams,
}) {
  // Finished or home pieces are never on the shared path.
  if (mover.isFinished || mover.isHome) return const [];

  // Pieces in the home stretch cannot be captured.
  if (mover.trackPosition >= LudoPiece.sharedPathSpan) return const [];

  // Check if the landing cell is safe.
  final globalIdx = globalCellOf(mover.playerIndex, mover.trackPosition);
  if (isSafeCellIndex(globalIdx)) return const [];

  // Collect all pieces at the same global cell that belong to opponents
  // (or enemy teams in teams mode).
  final captured = <LudoPiece>[];

  for (final p in pieces) {
    if (p.id == mover.id) continue;
    if (p.isHome || p.isFinished) continue;
    if (p.trackPosition >= LudoPiece.sharedPathSpan) continue;

    // Same player — never capture own pieces.
    if (p.playerIndex == mover.playerIndex) continue;

    // In teams mode, never capture a teammate.
    if (areTeammates(p.playerIndex, mover.playerIndex, teams)) continue;

    // Check if p is on the same global cell as mover.
    final pGlobal = globalCellOf(p.playerIndex, p.trackPosition);
    if (pGlobal != globalIdx) continue;

    // p is an opponent on the same non-safe cell — captured.
    captured.add(p);
  }

  return captured;
}