import 'package:flutter_ludo/rules/capture_rules.dart';
import 'package:flutter_ludo/rules/move_validator.dart';
import 'package:flutter_ludo/rules/win_rules.dart';
import 'package:flutter_ludo/service/ludo_team.dart';

import '../model/ludo_dice_rules.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_piece.dart';

class LudoEngineRollResult {
  const LudoEngineRollResult({
    required this.state,
    required this.passed,
    this.forfeited = false,
  });
  final LudoGameState state;

  /// True if the turn passed to the next player without a move (no legal
  /// moves, or the roll was [forfeited]).
  final bool passed;

  /// True if the roll was forfeited by `LudoDiceRules.forfeitStreak`.
  final bool forfeited;
}

class LudoEngineMoveResult {
  const LudoEngineMoveResult({
    required this.state,
    required this.movedPiece,
    required this.fromPosition,
    required this.toPosition,
    required this.capturedPieces,
    required this.playerWon,
    required this.teamWon,
    required this.turnPassed,
    required this.gameFinished,
    this.extraTurn = false,
  });

  final LudoGameState state;
  final LudoPiece movedPiece;
  final int fromPosition;
  final int toPosition;
  final List<LudoPiece> capturedPieces;

  /// True if the individual player just placed their 4th piece home.
  final bool playerWon;

  /// True if this move caused the whole TEAM to win (teams mode only).
  final bool teamWon;

  final bool turnPassed;
  final bool gameFinished;

  /// True if the same player rolls again.
  final bool extraTurn;
}

/// Pure stateless engine. Pass [teams] to enable teams mode.
class LudoEngine {
  const LudoEngine(this.diceRules, {this.teams});

  final LudoDiceRules diceRules;

  /// Non-null → teams mode active.
  final List<LudoTeam>? teams;

  // ── roll ─────────────────────────────────────────────────────────

  LudoEngineRollResult roll(LudoGameState state, int diceValue) {
    if (state.isFinished) {
      throw StateError('Game already finished.');
    }
    if (state.phase != LudoTurnPhase.awaitingRoll) {
      throw StateError('Cannot roll while a piece selection is pending.');
    }
    if (diceValue < 1 || diceValue > 6) {
      throw RangeError.range(diceValue, 1, 6, 'diceValue');
    }

    final isExtraValue = diceRules.grantsExtraTurn(diceValue);
    final streak = isExtraValue ? state.rollStreak + 1 : 0;
    final rolled = state.copyWith(
      lastRoll: diceValue,
      lastRollPlayerIndex: state.currentPlayerIndex,
      rollCount: state.rollCount + 1,
    );

    final limit = diceRules.forfeitStreak;
    if (isExtraValue && limit != null && streak >= limit) {
      return LudoEngineRollResult(
        state: _passTurn(rolled),
        passed: true,
        forfeited: true,
      );
    }

    final moves = computeLegalMoves(state, diceRules, diceValue, teams: teams);

    if (moves.isEmpty) {
      return LudoEngineRollResult(state: _passTurn(rolled), passed: true);
    }

    return LudoEngineRollResult(
      state: rolled.copyWith(
        diceValue: diceValue,
        legalMoves: List.unmodifiable(moves),
        phase: LudoTurnPhase.awaitingPieceSelection,
        rollStreak: streak,
      ),
      passed: false,
    );
  }

  LudoGameState _passTurn(LudoGameState state) => state.copyWith(
    currentPlayerIndex: _nextPlayer(state, state.currentPlayerIndex),
    phase: LudoTurnPhase.awaitingRoll,
    legalMoves: const [],
    clearDiceValue: true,
    rollStreak: 0,
  );

  // ── move ─────────────────────────────────────────────────────────

  LudoEngineMoveResult move(LudoGameState state, int pieceId) {
    if (state.phase != LudoTurnPhase.awaitingPieceSelection) {
      throw StateError('Roll the dice before moving a piece.');
    }
    final chosen = state.legalMoves.firstWhere(
      (m) => m.pieceId == pieceId,
      orElse: () => throw ArgumentError.value(
        pieceId,
        'pieceId',
        'Piece is not a legal move',
      ),
    );
    final piece = state.pieces.firstWhere((p) => p.id == pieceId);
    final movedPiece = piece.copyWith(trackPosition: chosen.toPosition);

    var pieces = [
      for (final p in state.pieces) p.id == pieceId ? movedPiece : p,
    ];

    // ── captures ─────────────────────────────────────────────────
    final captured = captureOpponents(
      pieces: pieces,
      mover: movedPiece,
      teams: teams,
    );
    if (captured.isNotEmpty) {
      final capturedIds = captured.map((c) => c.id).toSet();
      pieces = [
        for (final p in pieces)
          capturedIds.contains(p.id)
              ? p.copyWith(trackPosition: LudoPiece.home)
              : p,
      ];
    }

    final diceValue = state.diceValue!;
    final totalPlayers = state.players.length;

    // ── individual player win ─────────────────────────────────────
    final justWon =
        hasPlayerWon(pieces, movedPiece.playerIndex) &&
        !state.winners.contains(movedPiece.playerIndex);

    var winners = state.winners;
    if (justWon) {
      winners = [...winners, movedPiece.playerIndex];
    }

    // ── team win check ────────────────────────────────────────────
    bool teamJustWon = false;
    if (teams != null && justWon) {
      final myTeam = teamOf(movedPiece.playerIndex, teams);
      if (myTeam != null && hasTeamWon(pieces, myTeam)) {
        teamJustWon = true;
        // Also add teammate to winners list if not already there
        final mate = myTeam.teammateOf(movedPiece.playerIndex);
        if (!winners.contains(mate)) {
          winners = [...winners, mate];
        }
      }
    }

    // ── game finished ─────────────────────────────────────────────
    final gameFinished = isGameFinished(
      winners.length,
      totalPlayers,
      teams: teams,
      pieces: pieces,
    );

    // Auto-add last-place player(s) in standard mode
    if (gameFinished && teams == null && winners.length == totalPlayers - 1) {
      final last = List<int>.generate(
        totalPlayers,
        (i) => i,
      ).firstWhere((i) => !winners.contains(i));
      winners = [...winners, last];
    }

    // In teams mode, auto-add losing team to winners (last place)
    if (gameFinished && teams != null) {
      for (final t in teams!) {
        for (final pi in t.playerIndices) {
          if (!winners.contains(pi)) winners = [...winners, pi];
        }
      }
    }

    // A player who has just finished all their pieces never rolls again.
    final extraTurn =
        !gameFinished &&
        !justWon &&
        (diceRules.grantsExtraTurn(diceValue) ||
            (diceRules.extraTurnOnCapture && captured.isNotEmpty) ||
            (diceRules.extraTurnOnFinish && movedPiece.isFinished));
    final turnPassed = !gameFinished && !extraTurn;

    final nextPlayerIndex = gameFinished || extraTurn
        ? state.currentPlayerIndex
        : _nextPlayer(
            state.copyWith(winners: winners),
            state.currentPlayerIndex,
          );

    final newState = state.copyWith(
      pieces: List.unmodifiable(pieces),
      winners: List.unmodifiable(winners),
      currentPlayerIndex: nextPlayerIndex,
      phase: gameFinished ? LudoTurnPhase.gameOver : LudoTurnPhase.awaitingRoll,
      legalMoves: const [],
      clearDiceValue: true,
      rollStreak: extraTurn ? state.rollStreak : 0,
    );

    return LudoEngineMoveResult(
      state: newState,
      movedPiece: movedPiece,
      fromPosition: chosen.fromPosition,
      toPosition: chosen.toPosition,
      capturedPieces: captured,
      playerWon: justWon,
      teamWon: teamJustWon,
      turnPassed: turnPassed,
      gameFinished: gameFinished,
      extraTurn: extraTurn,
    );
  }

  // ── next player ───────────────────────────────────────────────────
  // Turn order is always Red→Blue→Green→Yellow (interleaved) regardless
  // of teams. Finished players are skipped.
  int _nextPlayer(LudoGameState state, int from) {
    final total = state.players.length;
    var next = (from + 1) % total;
    var guard = 0;
    while (state.winners.contains(next) && guard < total) {
      next = (next + 1) % total;
      guard++;
    }
    return next;
  }
}
