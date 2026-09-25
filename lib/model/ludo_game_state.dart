import 'package:flutter/foundation.dart';
import 'package:flutter_ludo/service/ludo_team.dart';

import 'ludo_player.dart';
import 'ludo_piece.dart';
import 'legal_move.dart';

enum LudoTurnPhase { awaitingRoll, awaitingPieceSelection, gameOver }

/// Immutable snapshot of the entire game.
///
/// [teams] is non-null when teams mode is active.
///
/// A state can be persisted with [toJson] and later resumed with
/// [LudoGameState.fromJson] + `LudoController.restore`.
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
    this.lastRoll,
    this.lastRollPlayerIndex,
    this.rollStreak = 0,
    this.rollCount = 0,
  });

  /// A fresh game: every piece at home, player 0 to roll.
  factory LudoGameState.initial(
    List<LudoPlayer> players, {
    List<LudoTeam>? teams,
  }) {
    return LudoGameState(
      players: List.unmodifiable(players),
      pieces: List.unmodifiable([
        for (var p = 0; p < players.length; p++)
          for (var l = 0; l < 4; l++) LudoPiece(id: p * 4 + l, playerIndex: p),
      ]),
      currentPlayerIndex: 0,
      phase: LudoTurnPhase.awaitingRoll,
      teams: teams,
    );
  }

  final List<LudoPlayer> players;
  final List<LudoPiece> pieces;
  final int currentPlayerIndex;
  final LudoTurnPhase phase;

  /// The value rolled for the move currently awaiting selection. `null`
  /// while waiting for a roll. See [lastRoll] for the most recent roll
  /// regardless of phase.
  final int? diceValue;
  final List<LudoLegalMove> legalMoves;
  final List<int> winners;
  final LudoPiece? lastMovedPiece;

  /// Non-null when the game was started in teams mode.
  final List<LudoTeam>? teams;

  /// The most recent dice value rolled by anyone, kept even after the turn
  /// passes (unlike [diceValue]). `null` before the first roll.
  final int? lastRoll;

  /// Index of the player who rolled [lastRoll].
  final int? lastRollPlayerIndex;

  /// How many extra-turn values (e.g. 6s) the current player has rolled
  /// in a row this turn. Used by `LudoDiceRules.forfeitStreak`.
  final int rollStreak;

  /// Total number of dice rolls made this game.
  final int rollCount;

  bool get isFinished => phase == LudoTurnPhase.gameOver;
  bool get isTeamsMode => teams != null;

  LudoPlayer get currentPlayer => players[currentPlayerIndex];

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
  bool areTeammates(int a, int b) =>
      teamOf(a) == teamOf(b) && teamOf(a) != null;

  List<LudoPiece> piecesOf(int playerIndex) =>
      pieces.where((p) => p.playerIndex == playerIndex).toList();

  /// Looks up a piece by id.
  LudoPiece pieceById(int id) => pieces.firstWhere((p) => p.id == id);

  /// Number of [playerIndex]'s pieces that have reached the center.
  int finishedCountOf(int playerIndex) =>
      pieces.where((p) => p.playerIndex == playerIndex && p.isFinished).length;

  /// Overall progress of [playerIndex] from `0.0` (all home) to `1.0`
  /// (all finished).
  double progressOf(int playerIndex) {
    var total = 0;
    for (final p in pieces) {
      if (p.playerIndex == playerIndex) total += p.trackPosition + 1;
    }
    return total / (4 * (LudoPiece.finished + 1));
  }

  LudoGameState copyWith({
    List<LudoPlayer>? players,
    List<LudoPiece>? pieces,
    int? currentPlayerIndex,
    LudoTurnPhase? phase,
    int? diceValue,
    bool clearDiceValue = false,
    List<LudoLegalMove>? legalMoves,
    List<int>? winners,
    LudoPiece? lastMovedPiece,
    bool clearLastMovedPiece = false,
    List<LudoTeam>? teams,
    int? lastRoll,
    int? lastRollPlayerIndex,
    int? rollStreak,
    int? rollCount,
  }) {
    return LudoGameState(
      players: players ?? this.players,
      pieces: pieces ?? this.pieces,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      phase: phase ?? this.phase,
      diceValue: clearDiceValue ? null : (diceValue ?? this.diceValue),
      legalMoves: legalMoves ?? this.legalMoves,
      winners: winners ?? this.winners,
      lastMovedPiece: clearLastMovedPiece
          ? null
          : (lastMovedPiece ?? this.lastMovedPiece),
      teams: teams ?? this.teams,
      lastRoll: lastRoll ?? this.lastRoll,
      lastRollPlayerIndex: lastRollPlayerIndex ?? this.lastRollPlayerIndex,
      rollStreak: rollStreak ?? this.rollStreak,
      rollCount: rollCount ?? this.rollCount,
    );
  }

  /// Serializes the full game state to JSON-compatible values, e.g. for
  /// `jsonEncode` and local storage.
  Map<String, Object?> toJson() => {
    'version': 1,
    'players': [for (final p in players) p.toJson()],
    'pieces': [for (final p in pieces) p.toJson()],
    'current': currentPlayerIndex,
    'phase': phase.name,
    'dice': diceValue,
    'legalMoves': [for (final m in legalMoves) m.toJson()],
    'winners': winners,
    'lastMoved': lastMovedPiece?.id,
    'teams': teams == null ? null : [for (final t in teams!) t.toJson()],
    'lastRoll': lastRoll,
    'lastRollPlayer': lastRollPlayerIndex,
    'rollStreak': rollStreak,
    'rollCount': rollCount,
  };

  /// Inverse of [toJson].
  factory LudoGameState.fromJson(Map<String, Object?> json) {
    List<Map<String, Object?>> list(String key) => [
      for (final e in (json[key] as List? ?? const []))
        (e as Map).cast<String, Object?>(),
    ];

    final pieces = List<LudoPiece>.unmodifiable(
      list('pieces').map(LudoPiece.fromJson),
    );
    final lastMovedId = json['lastMoved'] as int?;
    final rawTeams = json['teams'] as List?;

    return LudoGameState(
      players: List.unmodifiable(list('players').map(LudoPlayer.fromJson)),
      pieces: pieces,
      currentPlayerIndex: json['current']! as int,
      phase: LudoTurnPhase.values.byName(json['phase']! as String),
      diceValue: json['dice'] as int?,
      legalMoves: List.unmodifiable(
        list('legalMoves').map(LudoLegalMove.fromJson),
      ),
      winners: List<int>.unmodifiable(json['winners'] as List? ?? const []),
      lastMovedPiece: lastMovedId == null
          ? null
          : pieces.where((p) => p.id == lastMovedId).firstOrNull,
      teams: rawTeams == null
          ? null
          : List.unmodifiable(list('teams').map(LudoTeam.fromJson)),
      lastRoll: json['lastRoll'] as int?,
      lastRollPlayerIndex: json['lastRollPlayer'] as int?,
      rollStreak: json['rollStreak'] as int? ?? 0,
      rollCount: json['rollCount'] as int? ?? 0,
    );
  }
}
