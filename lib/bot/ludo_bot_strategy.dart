import 'dart:math';

import 'package:flutter_ludo/service/ludo_team.dart';

import '../constant/board_constants.dart';
import '../model/legal_move.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_piece.dart';
import '../rules/capture_rules.dart';
import 'ludo_move_scorer.dart';

/// Built-in bot skill levels. See [LudoBotStrategy.forDifficulty].
enum LudoBotDifficulty {
  /// Picks a random legal move.
  easy,

  /// Additive heuristics: capture, leave home, reach safety, push the
  /// lead piece, avoid danger.
  medium,

  /// Medium's heuristics plus threat escape and progress-weighted captures.
  hard,
}

/// Decides which legal move a bot plays.
///
/// Implement this to plug your own AI into `LudoController.botStrategy`:
///
/// ```dart
/// class AlwaysFirstBot extends LudoBotStrategy {
///   const AlwaysFirstBot();
///   @override
///   LudoLegalMove chooseMove(LudoGameState state) => state.legalMoves.first;
/// }
/// ```
abstract class LudoBotStrategy {
  const LudoBotStrategy();

  /// Returns the built-in strategy for [difficulty].
  factory LudoBotStrategy.forDifficulty(LudoBotDifficulty difficulty) {
    switch (difficulty) {
      case LudoBotDifficulty.easy:
        return LudoEasyBot();
      case LudoBotDifficulty.medium:
        return const LudoMediumBot();
      case LudoBotDifficulty.hard:
        return const LudoHardBot();
    }
  }

  /// Picks one of `state.legalMoves`. Called only while
  /// `state.phase == LudoTurnPhase.awaitingPieceSelection`, so there is
  /// always at least one legal move. Returning a move that is not in
  /// `state.legalMoves` makes the controller fall back to the first one.
  LudoLegalMove chooseMove(LudoGameState state);
}

/// Picks uniformly at random among the legal moves.
class LudoEasyBot extends LudoBotStrategy {
  LudoEasyBot({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  LudoLegalMove chooseMove(LudoGameState state) =>
      state.legalMoves[_random.nextInt(state.legalMoves.length)];
}

/// Uses `LudoMoveScorer`'s additive heuristics.
class LudoMediumBot extends LudoBotStrategy {
  const LudoMediumBot();

  @override
  LudoLegalMove chooseMove(LudoGameState state) =>
      const LudoMoveScorer().bestMove(state);
}

/// The strongest built-in bot.
///
/// It scores each legal move with [LudoMoveScorer]'s heuristics (capture,
/// reach the home stretch, leave home, land on safe cells, push the lead
/// piece, avoid landing 1–6 cells ahead of an opponent) and adds:
///
/// * capture value proportional to how far the victim had travelled;
/// * a bonus for moving a currently threatened piece out of danger;
/// * teammate awareness in teams mode.
///
/// Ludo is dominated by dice luck, so skill gaps are modest: in 4,000-game
/// head-to-head simulations this bot beats [LudoMediumBot] about 52% of the
/// time and [LudoEasyBot] about 87–89% of the time.
class LudoHardBot extends LudoBotStrategy {
  const LudoHardBot();

  static const int _pathLength = 52;

  @override
  LudoLegalMove chooseMove(LudoGameState state) {
    final me = state.currentPlayerIndex;
    final lead = _leadPosition(state, me);
    LudoLegalMove? best;
    var bestScore = double.negativeInfinity;
    for (final move in state.legalMoves) {
      final score = evaluate(move, state, lead: lead);
      if (score > bestScore ||
          (score == bestScore && move.toPosition > best!.toPosition)) {
        best = move;
        bestScore = score;
      }
    }
    return best!;
  }

  /// Heuristic value of playing [move] in [state]. Higher is better.
  double evaluate(LudoLegalMove move, LudoGameState state, {int? lead}) {
    final me = state.currentPlayerIndex;
    final teams = state.teams;
    final piece = state.pieceById(move.pieceId);
    final moved = piece.copyWith(trackPosition: move.toPosition);
    final after = [for (final p in state.pieces) p.id == piece.id ? moved : p];
    final captured = captureOpponents(
      pieces: after,
      mover: moved,
      teams: teams,
    );

    var score = 10.0;

    if (captured.isNotEmpty) {
      score += 50;
      for (final c in captured) {
        score += c.trackPosition;
      }
    }

    final wasOnStretch = move.fromPosition >= LudoPiece.sharedPathSpan;
    final nowOnStretch = move.toPosition >= LudoPiece.sharedPathSpan;
    if (nowOnStretch && !wasOnStretch) score += 40;

    if (piece.isHome) score += 30;

    final safeAfter = _isSafe(me, move.toPosition);
    if (safeAfter) score += 25;
    if (!piece.isHome && _isSafe(me, move.fromPosition) && !safeAfter) {
      score -= 10;
    }

    if (!piece.isHome &&
        move.fromPosition == (lead ?? _leadPosition(state, me))) {
      score += 20;
    }

    final threatenedAfter = _threatened(me, move.toPosition, after, teams);
    if (threatenedAfter) score -= 30;

    if (!piece.isHome &&
        !threatenedAfter &&
        _threatened(me, move.fromPosition, state.pieces, teams)) {
      score += 30;
    }

    return score;
  }

  bool _isSafe(int player, int position) =>
      position >= 0 &&
      position < LudoPiece.sharedPathSpan &&
      isSafeCellIndex(globalCellOf(player, position));

  /// Whether an enemy piece sits 1–6 cells behind [position] on the shared
  /// path, i.e. could capture a piece there with its next roll.
  bool _threatened(
    int player,
    int position,
    List<LudoPiece> pieces,
    List<LudoTeam>? teams,
  ) {
    if (position < 0 || position >= LudoPiece.sharedPathSpan) return false;
    if (_isSafe(player, position)) return false;
    final cell = globalCellOf(player, position);
    for (final p in pieces) {
      if (p.playerIndex == player ||
          areTeammates(p.playerIndex, player, teams) ||
          !p.isOnSharedPath) {
        continue;
      }
      final d =
          (cell - globalCellOf(p.playerIndex, p.trackPosition)) % _pathLength;
      if (d >= 1 && d <= 6 && p.trackPosition + d < LudoPiece.sharedPathSpan) {
        return true;
      }
    }
    return false;
  }

  int _leadPosition(LudoGameState state, int player) {
    var lead = -1;
    for (final p in state.pieces) {
      if (p.playerIndex == player &&
          !p.isHome &&
          !p.isFinished &&
          p.trackPosition > lead) {
        lead = p.trackPosition;
      }
    }
    return lead;
  }
}
