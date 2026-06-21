import 'package:flutter_ludo/service/ludo_team.dart';

import '../constant/board_constants.dart';
import '../model/legal_move.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_piece.dart';

/// Scores a single [LudoLegalMove] for the current [LudoGameState] using
/// medium-level heuristics.
///
/// All heuristics are additive. The move with the highest total score is
/// chosen by [LudoMoveScorer.bestMove].
///
/// **Heuristics (in priority order):**
///
/// | Score  | Rule |
/// |--------|------|
/// | +50    | Captures an opponent piece |
/// | +40    | Enters the home stretch (trackPosition >= 51) |
/// | +30    | Leaves home base (piece was at home, moves to track) |
/// | +25    | Lands on a safe cell |
/// | +20    | Advances the piece closest to home (furthest along track) |
/// | +10    | General forward progress (per move) |
/// | −30    | Lands in danger zone (1–6 steps behind any opponent) |
/// | −10    | Moves a piece already sitting on a safe cell unnecessarily |
///
/// Tie-breaking: prefer the piece furthest along the track.
class LudoMoveScorer {
  const LudoMoveScorer();

  // ── score weights ────────────────────────────────────────────────
  static const int _captureScore      =  50;
  static const int _enterStretchScore =  40;
  static const int _leaveHomeScore    =  30;
  static const int _safeLandScore     =  25;
  static const int _leadPieceBonus    =  20;
  static const int _progressScore     =  10;
  static const int _dangerPenalty     = -30;
  static const int _leaveSafePenalty  = -10;

  /// Returns the best [LudoLegalMove] from [state.legalMoves] according to
  /// the heuristic scoring. Never returns null — there is always at least one
  /// legal move when this is called.
  LudoLegalMove bestMove(LudoGameState state) {
    assert(state.legalMoves.isNotEmpty, 'No legal moves to score.');

    LudoLegalMove? best;
    int bestScore = -9999;

    for (final move in state.legalMoves) {
      final score = _score(move, state);
      // Tie-break: prefer the piece furthest along the track.
      if (score > bestScore ||
          (score == bestScore && _tieBreak(move, best, state))) {
        best      = move;
        bestScore = score;
      }
    }

    return best!;
  }

  // ── internal scorer ──────────────────────────────────────────────

  int _score(LudoLegalMove move, LudoGameState state) {
    int score = 0;

    final piece    = state.pieces.firstWhere((p) => p.id == move.pieceId);
    final toPos    = move.toPosition;
    final fromPos  = move.fromPosition;
    final myIndex  = state.currentPlayerIndex;
    final pieces   = state.pieces;
    final teams    = state.teams;

    // ── 1. Capture ───────────────────────────────────────────────
    if (_wouldCapture(myIndex, toPos, pieces, teams)) {
      score += _captureScore;
    }

    // ── 2. Enter home stretch ────────────────────────────────────
    final wasOnStretch = fromPos >= LudoPiece.sharedPathSpan && fromPos > 0;
    final nowOnStretch = toPos   >= LudoPiece.sharedPathSpan;
    if (nowOnStretch && !wasOnStretch) {
      score += _enterStretchScore;
    }

    // ── 3. Leave home base ───────────────────────────────────────
    if (piece.isHome) {
      score += _leaveHomeScore;
    }

    // ── 4. Land on safe cell ─────────────────────────────────────
    if (_isSafe(myIndex, toPos)) {
      score += _safeLandScore;
    }

    // ── 5. Moving from a safe cell unnecessarily ─────────────────
    if (!piece.isHome && _isSafe(myIndex, fromPos) && !_isSafe(myIndex, toPos)) {
      score += _leaveSafePenalty;
    }

    // ── 6. Lead piece bonus ───────────────────────────────────────
    final leadPos = _leadPiecePosition(myIndex, pieces);
    if (!piece.isHome && fromPos == leadPos) {
      score += _leadPieceBonus;
    }

    // ── 7. General forward progress ──────────────────────────────
    score += _progressScore;

    // ── 8. Danger zone penalty ───────────────────────────────────
    if (_isInDangerZone(myIndex, toPos, pieces, teams)) {
      score += _dangerPenalty;
    }

    return score;
  }

  // ── heuristic helpers ────────────────────────────────────────────

  /// True if landing at [toTrackPos] for [playerIndex] would capture at
  /// least one opponent piece (non-safe cell, opponent present).
  bool _wouldCapture(
    int playerIndex,
    int toTrackPos,
    List<LudoPiece> pieces,
    List<LudoTeam>? teams,
  ) {
    // Home-base entry (trackPos == home) or home-stretch — no captures.
    if (toTrackPos < 0 || toTrackPos >= LudoPiece.sharedPathSpan) return false;

    final globalIdx = globalCellOf(playerIndex, toTrackPos);
    if (isSafeCellIndex(globalIdx)) return false;

    for (final p in pieces) {
      if (p.playerIndex == playerIndex) continue;
      if (areTeammates(p.playerIndex, playerIndex, teams)) continue;
      if (p.isHome || p.isFinished) continue;
      if (p.trackPosition >= LudoPiece.sharedPathSpan) continue;
      final pGlobal = globalCellOf(p.playerIndex, p.trackPosition);
      if (pGlobal == globalIdx) return true;
    }
    return false;
  }

  /// True if [toTrackPos] for [playerIndex] is a safe cell on the shared path.
  bool _isSafe(int playerIndex, int toTrackPos) {
    if (toTrackPos < 0 || toTrackPos >= LudoPiece.sharedPathSpan) return false;
    return isSafeCellIndex(globalCellOf(playerIndex, toTrackPos));
  }

  /// Returns the track position of the furthest-along on-board piece for
  /// [playerIndex], or -1 if all are home.
  int _leadPiecePosition(int playerIndex, List<LudoPiece> pieces) {
    int lead = -1;
    for (final p in pieces) {
      if (p.playerIndex != playerIndex) continue;
      if (p.isHome || p.isFinished) continue;
      if (p.trackPosition > lead) lead = p.trackPosition;
    }
    return lead;
  }

  /// True if [toTrackPos] is within 1–6 steps behind any living opponent
  /// piece on the shared path (i.e. an opponent could capture us next turn).
  bool _isInDangerZone(
    int playerIndex,
    int toTrackPos,
    List<LudoPiece> pieces,
    List<LudoTeam>? teams,
  ) {
    if (toTrackPos < 0 || toTrackPos >= LudoPiece.sharedPathSpan) return false;
    if (_isSafe(playerIndex, toTrackPos)) return false;

    final myGlobal = globalCellOf(playerIndex, toTrackPos);

    for (final p in pieces) {
      if (p.playerIndex == playerIndex) continue;
      if (areTeammates(p.playerIndex, playerIndex, teams)) continue;
      if (p.isHome || p.isFinished) continue;
      if (p.trackPosition >= LudoPiece.sharedPathSpan) continue;

      // Check if opponent can reach myGlobal in 1–6 rolls.
      for (var roll = 1; roll <= 6; roll++) {
        final opponentNextPos = p.trackPosition + roll;
        if (opponentNextPos >= LudoPiece.sharedPathSpan) continue;
        final opponentGlobal = globalCellOf(p.playerIndex, opponentNextPos);
        if (opponentGlobal == myGlobal) return true;
      }
    }
    return false;
  }

  /// Tie-break: prefer the piece furthest along the track.
  bool _tieBreak(
    LudoLegalMove candidate,
    LudoLegalMove? current,
    LudoGameState state,
  ) {
    if (current == null) return true;
    final candPiece = state.pieces.firstWhere((p) => p.id == candidate.pieceId);
    final currPiece = state.pieces.firstWhere((p) => p.id == current.pieceId);
    return candPiece.trackPosition > currPiece.trackPosition;
  }
}