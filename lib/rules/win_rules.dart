import 'package:flutter_ludo/service/ludo_team.dart';

import '../model/ludo_piece.dart';

/// Returns true if [playerIndex]'s own 4 pieces have all finished.
bool hasPlayerWon(List<LudoPiece> pieces, int playerIndex) {
  return pieces
      .where((p) => p.playerIndex == playerIndex)
      .every((p) => p.isFinished);
}

/// In **teams mode**: returns true if both players on [team] have all 4
/// pieces finished (8 pieces total).
///
/// In standard mode ([teams] == null) this is never called — use
/// [hasPlayerWon] directly.
bool hasTeamWon(List<LudoPiece> pieces, LudoTeam team) {
  return team.playerIndices.every((pi) => hasPlayerWon(pieces, pi));
}

/// Returns true if the overall game is finished.
///
/// - Standard mode: [winnersCount] >= [totalPlayers] - 1
/// - Teams mode: at least one full team has all 8 pieces home
bool isGameFinished(
  int winnersCount,
  int totalPlayers, {
  List<LudoTeam>? teams,
  List<LudoPiece>? pieces,
}) {
  if (teams != null && pieces != null) {
    // Teams mode: game ends the moment one full team finishes.
    return teams.any((t) => hasTeamWon(pieces, t));
  }
  // Standard mode: all but one player have finished.
  return winnersCount >= totalPlayers - 1;
}