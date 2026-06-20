import 'package:flutter_ludo/model/ludo_piece.dart';
import 'package:flutter_ludo/service/ludo_team.dart';


/// Returns true if [playerIndex]'s own 4 pieces have all finished.
bool hasPlayerWon(List<LudoPiece> pieces, int playerIndex) {
  return pieces
      .where((p) => p.playerIndex == playerIndex)
      .every((p) => p.isFinished);
}

/// In **teams mode**: returns true if both players on [team] have all 4
/// pieces finished (8 pieces total).
bool hasTeamWon(List<LudoPiece> pieces, LudoTeam team) {
  return team.playerIndices.every((pi) => hasPlayerWon(pieces, pi));
}

/// Returns true if the overall game is finished.
///
/// - Standard mode ([teams] == null):
///   [winnersCount] >= [totalPlayers] - 1
///   (all-but-one have finished; last place is auto-awarded).
///
/// - Teams mode ([teams] != null):
///   At least one full team has all 8 pieces home.
///   [pieces] must be supplied in teams mode.
bool isGameFinished(
  int winnersCount,
  int totalPlayers, {
  List<LudoTeam>? teams,
  List<LudoPiece>? pieces,
}) {
  if (teams != null && pieces != null) {
    return teams.any((t) => hasTeamWon(pieces, t));
  }
  return winnersCount >= totalPlayers - 1;
}