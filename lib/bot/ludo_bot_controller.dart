import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_ludo/model/ludo_piece.dart';
import 'package:flutter_ludo/service/ludo_team.dart';

import '../controller/ludo_controller.dart';
import '../model/ludo_dice_rules.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_player.dart';
import 'ludo_move_scorer.dart';

/// Wraps [LudoController] and automatically drives turns for any player
/// index listed in [botPlayerIndices].
///
/// Human players interact normally via [rollDice] and [selectPiece].
/// Bot players have their turns driven automatically after [thinkDuration].
///
/// ```dart
/// final controller = LudoBotController(
///   players: players,
///   botPlayerIndices: {1, 2, 3}, // seats 1-3 are bots, seat 0 is human
///   thinkDuration: Duration(milliseconds: 300),
/// );
/// ```
///
/// Use exactly like [LudoController] in the UI — it extends
/// [ChangeNotifier] and exposes the same [state], [rollDice],
/// [selectPiece], [reset], and [dispose] API.
class LudoBotController extends ChangeNotifier {
  LudoBotController({
    required List<LudoPlayer> players,
    required this.botPlayerIndices,
    LudoDiceRules diceRules         = const LudoDiceRules(),
    int Function()? diceRoller,
    bool enableAudio                = true,
    this.thinkDuration              = const Duration(milliseconds: 300),
    List<LudoTeam>? teams,
    // Forward all callbacks
    LudoDiceRolledCallback?    onDiceRolled,
    LudoPieceMovedCallback?    onPieceMoved,
    LudoPieceCapturedCallback? onPieceCaptured,
    LudoTurnChangedCallback?   onTurnChanged,
    LudoPlayerWonCallback?     onPlayerWon,
    LudoTeamWonCallback?       onTeamWon,
    LudoGameFinishedCallback?  onGameFinished,
    Duration stepAnimationDuration  = const Duration(milliseconds: 180),
  }) : _scorer = const LudoMoveScorer(),
       _inner  = LudoController(
         players:              players,
         diceRules:            diceRules,
         diceRoller:           diceRoller,
         enableAudio:          enableAudio,
         teams:                teams,
         onDiceRolled:         onDiceRolled,
         onPieceMoved:         onPieceMoved,
         onPieceCaptured:      onPieceCaptured,
         onTurnChanged:        onTurnChanged,
         onPlayerWon:          onPlayerWon,
         onTeamWon:            onTeamWon,
         onGameFinished:       onGameFinished,
         stepAnimationDuration: stepAnimationDuration,
       ) {
    // Listen to inner controller and re-notify our own listeners so the
    // board / dice widgets rebuild correctly.
    _inner.addListener(_onInnerChanged);
    // Kick off bot if the first player happens to be a bot.
    _scheduleBotTurnIfNeeded();
  }
  /// Public accessor for the inner controller (used by LudoBoard).
LudoController get innerController => _inner;
  /// Set of player indices that are controlled by the bot.
  final Set<int> botPlayerIndices;

  /// How long the bot "thinks" before rolling or selecting a piece.
  final Duration thinkDuration;

  final LudoController   _inner;
  final LudoMoveScorer   _scorer;
  Timer?                 _thinkTimer;
  bool                   _botBusy = false;

  // ── public API (mirrors LudoController) ─────────────────────────

  LudoGameState  get state          => _inner.state;
  bool           get enableAudio    => _inner.enableAudio;
  bool           get isAnimating    => _inner.isAnimating;
  LudoPiece?     get animatingPiece => _inner.animatingPiece;
  bool           get isTeamsMode    => _inner.isTeamsMode;
  List<LudoTeam>? get teams         => _inner.teams;

  /// True if the current player's seat is a bot.
  bool get isCurrentPlayerBot =>
      botPlayerIndices.contains(state.currentPlayerIndex);

  void toggleAudio(bool enabled) => _inner.toggleAudio(enabled);

  /// For human players only. Throws if called during a bot turn.
  int rollDice() {
    _assertHumanTurn('rollDice');
    return _inner.rollDice();
  }

  /// For human players only. Throws if called during a bot turn.
  Future<void> selectPiece(int pieceId) {
    _assertHumanTurn('selectPiece');
    return _inner.selectPiece(pieceId);
  }

  void reset() {
    _cancelThinkTimer();
    _botBusy = false;
    _inner.reset();
    _scheduleBotTurnIfNeeded();
  }

  @override
  void dispose() {
    _cancelThinkTimer();
    _inner.removeListener(_onInnerChanged);
    _inner.dispose();
    super.dispose();
  }

  // ── inner listener ────────────────────────────────────────────────

  void _onInnerChanged() {
    notifyListeners();
    _scheduleBotTurnIfNeeded();
  }

  // ── bot scheduling ────────────────────────────────────────────────

  void _scheduleBotTurnIfNeeded() {
    if (state.isFinished)       return;
    if (_inner.isAnimating)     return;
    if (_botBusy)               return;
    if (!isCurrentPlayerBot)    return;

    // Only act on clear phase transitions.
    final phase = state.phase;
    if (phase != LudoTurnPhase.awaitingRoll &&
        phase != LudoTurnPhase.awaitingPieceSelection) {
      return;
    }

    _cancelThinkTimer();
    _thinkTimer = Timer(thinkDuration, _executeBotAction);
  }

  Future<void> _executeBotAction() async {
    if (state.isFinished)    return;
    if (_inner.isAnimating)  return;
    if (!isCurrentPlayerBot) return;

    _botBusy = true;

    try {
      final phase = state.phase;

      if (phase == LudoTurnPhase.awaitingRoll) {
        _inner.rollDice();
        // After rolling, _onInnerChanged fires and re-schedules if
        // awaitingPieceSelection with >1 legal moves.
      } else if (phase == LudoTurnPhase.awaitingPieceSelection) {
        if (state.legalMoves.isEmpty) return;

        final best = _scorer.bestMove(state);
        await _inner.selectPiece(best.pieceId);
      }
    } catch (e) {
      if (kDebugMode) print('[LudoBotController] error: $e');
    } finally {
      _botBusy = false;
    }
  }

  void _cancelThinkTimer() {
    _thinkTimer?.cancel();
    _thinkTimer = null;
  }

  void _assertHumanTurn(String method) {
    if (isCurrentPlayerBot) {
      throw StateError(
        '$method called during a bot turn '
        '(player ${state.currentPlayerIndex}). '
        'Only call this for human player seats.',
      );
    }
  }
}

// Re-export the piece type so callers don't need an extra import.
// ignore: unused_element
typedef _LudoPiece = LudoPiece;