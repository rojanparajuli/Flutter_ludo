import 'package:flutter_ludo/rules/capture_rules.dart';
import 'package:flutter_ludo/rules/move_validator.dart';
import 'package:flutter_ludo/rules/win_rules.dart';
import 'package:flutter_ludo/service/ludo_team.dart';

import '../model/ludo_dice_rules.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_piece.dart';


class LudoEngineRollResult {
  const LudoEngineRollResult({required this.state, required this.passed});
  final LudoGameState state;
  final bool passed;
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
  });

  final LudoGameState  state;
  final LudoPiece      movedPiece;
  final int            fromPosition;
  final int            toPosition;
  final List<LudoPiece> capturedPieces;

  /// True if the individual player just placed their 4th piece home.
  final bool playerWon;

  /// True if this move caused the whole TEAM to win (teams mode only).
  final bool teamWon;

  final bool turnPassed;
  final bool gameFinished;
}

/// Pure stateless engine. Pass [teams] to enable teams mode.
class LudoEngine {
  const LudoEngine(this.diceRules, {this.teams});

  final LudoDiceRules   diceRules;

  /// Non-null → teams mode active.
  final List<LudoTeam>? teams;

  // ── roll ─────────────────────────────────────────────────────────

  LudoEngineRollResult roll(LudoGameState state, int diceValue) {
    final moves = computeLegalMoves(
      state, diceRules, diceValue,
      teams: teams,
    );

    if (moves.isEmpty) {
      return LudoEngineRollResult(
        state: state.copyWith(
          currentPlayerIndex: _nextPlayer(state, state.currentPlayerIndex),
          phase: LudoTurnPhase.awaitingRoll,
          legalMoves: const [],
          clearDiceValue: true,
        ),
        passed: true,
      );
    }

    return LudoEngineRollResult(
      state: state.copyWith(
        diceValue: diceValue,
        legalMoves: moves,
        phase: LudoTurnPhase.awaitingPieceSelection,
      ),
      passed: false,
    );
  }

  // ── move ─────────────────────────────────────────────────────────

  LudoEngineMoveResult move(LudoGameState state, int pieceId) {
    final chosen    = state.legalMoves.firstWhere((m) => m.pieceId == pieceId);
    final piece     = state.pieces.firstWhere((p) => p.id == pieceId);
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

    final diceValue    = state.diceValue!;
    final totalPlayers = state.players.length;

    // ── individual player win ─────────────────────────────────────
    final justWon = hasPlayerWon(pieces, movedPiece.playerIndex) &&
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
      final last = List<int>.generate(totalPlayers, (i) => i)
          .firstWhere((i) => !winners.contains(i));
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

    final extraTurn  = !gameFinished && diceRules.grantsExtraTurn(diceValue);
    final turnPassed = !gameFinished && !extraTurn;

    final nextPlayerIndex = gameFinished || extraTurn
        ? state.currentPlayerIndex
        : _nextPlayer(
            state.copyWith(winners: winners),
            state.currentPlayerIndex,
          );

    final newState = state.copyWith(
      pieces: pieces,
      winners: winners,
      currentPlayerIndex: nextPlayerIndex,
      phase: gameFinished ? LudoTurnPhase.gameOver : LudoTurnPhase.awaitingRoll,
      legalMoves: const [],
      clearDiceValue: true,
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
    );
  }

  // ── next player ───────────────────────────────────────────────────
  // Turn order is always Red→Blue→Green→Yellow (interleaved) regardless
  // of teams. Finished players are skipped.
  int _nextPlayer(LudoGameState state, int from) {
    final total = state.players.length;
    var next  = (from + 1) % total;
    var guard = 0;
    while (state.winners.contains(next) && guard < total) {
      next  = (next + 1) % total;
      guard++;
    }
    return next;
  }
}