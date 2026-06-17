
import 'package:flutter_ludo/model/ludo_dice_rules.dart';
import 'package:flutter_ludo/model/ludo_game_state.dart';
import 'package:flutter_ludo/model/ludo_piece.dart';

import '../rules/capture_rules.dart';
import '../rules/move_validator.dart';
import '../rules/win_rules.dart';

/// Result of [LudoEngine.roll].
class LudoEngineRollResult {
  const LudoEngineRollResult({required this.state, required this.passed});

  /// State after the roll. If [passed] is true, this already reflects the
  /// turn having moved on to the next player.
  final LudoGameState state;

  /// True if the roll produced no legal moves and the turn was passed
  /// automatically.
  final bool passed;
}

/// Result of [LudoEngine.move].
class LudoEngineMoveResult {
  const LudoEngineMoveResult({
    required this.state,
    required this.movedPiece,
    required this.fromPosition,
    required this.toPosition,
    required this.capturedPieces,
    required this.playerWon,
    required this.turnPassed,
    required this.gameFinished,
  });

  final LudoGameState state;
  final LudoPiece movedPiece;
  final int fromPosition;
  final int toPosition;
  final List<LudoPiece> capturedPieces;

  /// True if this move caused [movedPiece]'s player to win.
  final bool playerWon;

  /// True if the turn passed to the next player as a result of this move
  /// (false if the same player gets an extra turn, or the game just
  /// finished).
  final bool turnPassed;

  /// True if this move caused the overall game to finish.
  final bool gameFinished;
}

/// Pure, stateless rules engine implementing the turn flow from the
/// specification: roll dice -> determine legal moves -> select piece ->
/// move piece -> apply captures -> check win state -> apply extra-turn
/// rule -> pass turn.
///
/// Every method takes an immutable [LudoGameState] and returns a new one.
/// None of flutter_ludo's mutable bookkeeping (events, [ChangeNotifier],
/// randomness) lives here, which is what makes this straightforward to
/// unit test in isolation from [LudoController].
class LudoEngine {
  const LudoEngine(this.diceRules);

  final LudoDiceRules diceRules;

  /// Applies a dice roll: computes legal moves for [diceValue] and updates
  /// [LudoGameState.phase] accordingly. If there are no legal moves, the
  /// turn is passed immediately (see [LudoEngineRollResult.passed]).
  LudoEngineRollResult roll(LudoGameState state, int diceValue) {
    final moves = computeLegalMoves(state, diceRules, diceValue);

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

  /// Applies the move of [pieceId], which must be among
  /// `state.legalMoves`. Handles captures, win detection, the extra-turn
  /// rule, and passing the turn.
  LudoEngineMoveResult move(LudoGameState state, int pieceId) {
    final chosen = state.legalMoves.firstWhere((m) => m.pieceId == pieceId);
    final piece = state.pieces.firstWhere((p) => p.id == pieceId);
    final movedPiece = piece.copyWith(trackPosition: chosen.toPosition);

    var pieces = [
      for (final p in state.pieces) p.id == pieceId ? movedPiece : p,
    ];

    final captured = captureOpponents(pieces: pieces, mover: movedPiece);
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
    final justWon = hasPlayerWon(pieces, movedPiece.playerIndex) &&
        !state.winners.contains(movedPiece.playerIndex);

    var winners = state.winners;
    if (justWon) {
      winners = [...winners, movedPiece.playerIndex];
    }

    final totalPlayers = state.players.length;
    final gameFinished = isGameFinished(winners, totalPlayers);
    if (gameFinished && winners.length == totalPlayers - 1) {
      // Standard Ludo convention: once all-but-one player has finished,
      // the last remaining player is automatically awarded last place.
      final last = List<int>.generate(totalPlayers, (i) => i)
          .firstWhere((i) => !winners.contains(i));
      winners = [...winners, last];
    }

    final extraTurn = !gameFinished && diceRules.grantsExtraTurn(diceValue);
    final turnPassed = !gameFinished && !extraTurn;

    final nextPlayerIndex = gameFinished || extraTurn
        ? state.currentPlayerIndex
        : _nextPlayer(state.copyWith(winners: winners),
            state.currentPlayerIndex);

    final newState = state.copyWith(
      pieces: pieces,
      winners: winners,
      currentPlayerIndex: nextPlayerIndex,
      phase:
          gameFinished ? LudoTurnPhase.gameOver : LudoTurnPhase.awaitingRoll,
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
      turnPassed: turnPassed,
      gameFinished: gameFinished,
    );
  }

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