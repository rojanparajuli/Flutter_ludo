import 'package:flutter/foundation.dart';

/// Defines a team in teams mode.
///
/// Teams are fixed as:
///  - Team A: player 0 (Red) + player 3 (Yellow)  — diagonal corners
///  - Team B: player 1 (Blue) + player 2 (Green)  — diagonal corners
@immutable
class LudoTeam {
  const LudoTeam({
    required this.name,
    required this.playerIndices,
  });

  final String    name;
  final List<int> playerIndices;

  /// Returns true if [playerIndex] belongs to this team.
  bool contains(int playerIndex) => playerIndices.contains(playerIndex);

  /// Returns the teammate index for [playerIndex].
  /// Throws if [playerIndex] is not in this team.
  int teammateOf(int playerIndex) {
    assert(contains(playerIndex), 'Player $playerIndex is not in $name.');
    return playerIndices.firstWhere((i) => i != playerIndex);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LudoTeam &&
          other.name == name &&
          other.playerIndices.length == playerIndices.length &&
          other.playerIndices.every((i) => playerIndices.contains(i)));

  @override
  int get hashCode => Object.hash(name, Object.hashAll(playerIndices));

  @override
  String toString() => 'LudoTeam($name: $playerIndices)';
}

/// The two fixed teams used in 2v2 teams mode.
///
/// Team A: player 0 (Red)  + player 3 (Yellow)
/// Team B: player 1 (Blue) + player 2 (Green)
const List<LudoTeam> kDefaultTeams = [
  LudoTeam(name: 'Team A', playerIndices: [0, 3]),
  LudoTeam(name: 'Team B', playerIndices: [1, 2]),
];

/// Returns the [LudoTeam] that [playerIndex] belongs to, from [teams].
/// Returns null if [teams] is null (i.e. not in teams mode).
LudoTeam? teamOf(int playerIndex, List<LudoTeam>? teams) {
  if (teams == null) return null;
  for (final t in teams) {
    if (t.contains(playerIndex)) return t;
  }
  return null;
}

/// Returns true if [a] and [b] are teammates.
bool areTeammates(int a, int b, List<LudoTeam>? teams) {
  if (teams == null) return false;
  for (final t in teams) {
    if (t.contains(a) && t.contains(b)) return true;
  }
  return false;
}