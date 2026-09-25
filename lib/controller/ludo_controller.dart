import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_ludo/service/ludo_team.dart';

import '../bot/ludo_bot_strategy.dart';
import '../engine/ludo_engine.dart';
import '../model/legal_move.dart';
import '../model/ludo_dice_rules.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_piece.dart';
import '../model/ludo_player.dart';

typedef LudoDiceRolledCallback = void Function(int value);
typedef LudoPieceMovedCallback =
    void Function(LudoPiece piece, int from, int to);
typedef LudoPieceCapturedCallback =
    void Function(LudoPiece captured, LudoPiece by);
typedef LudoTurnChangedCallback = void Function(int currentPlayerIndex);
typedef LudoPlayerWonCallback = void Function(int playerIndex, int place);

/// Fired when a full team wins in teams mode.
typedef LudoTeamWonCallback = void Function(LudoTeam team);

typedef LudoGameFinishedCallback = void Function(List<int> winnersInOrder);

/// Fired when a roll is forfeited by [LudoDiceRules.forfeitStreak].
typedef LudoTurnForfeitedCallback = void Function(int playerIndex, int streak);

/// Owns a game of Ludo: holds the current [LudoGameState], applies rolls
/// and moves through [LudoEngine], animates piece movement step by step,
/// and plays turns automatically for bot seats.
///
/// ```dart
/// final controller = LudoController(
///   players: players,
///   botPlayers: {1, 2, 3},               // seat 0 is human
///   botDifficulty: LudoBotDifficulty.hard,
/// );
/// ```
///
/// The controller is a [ChangeNotifier]; the bundled widgets listen to it
/// automatically. Call [dispose] when you're done with it.
class LudoController extends ChangeNotifier {
  LudoController({
    required List<LudoPlayer> players,
    this.diceRules = const LudoDiceRules(),
    int Function()? diceRoller,
    this.onDiceRolled,
    this.onPieceMoved,
    this.onPieceCaptured,
    this.onTurnChanged,
    this.onPlayerWon,
    this.onTeamWon,
    this.onGameFinished,
    this.onTurnForfeited,
    @Deprecated('Audio was removed in 0.1.0. This flag has no effect.')
    bool enableAudio = true,
    this.stepAnimationDuration = const Duration(milliseconds: 180),
    // Teams mode — pass kDefaultTeams or a custom list to enable.
    List<LudoTeam>? teams,
    Set<int> botPlayers = const {},
    LudoBotDifficulty botDifficulty = LudoBotDifficulty.medium,
    LudoBotStrategy? botStrategy,
    this.botThinkDuration = const Duration(milliseconds: 500),
    this.autoMoveSingleChoice = true,
    this.autoMoveDelay = const Duration(milliseconds: 250),
  }) : assert(
         players.length >= 2 && players.length <= 4,
         'flutter_ludo supports 2 to 4 players.',
       ),
       assert(
         teams == null || players.length == 4,
         'Teams mode requires exactly 4 players.',
       ),
       assert(diceRules.startAllowedValues.isNotEmpty),
       assert(
         botPlayers.every((i) => i >= 0 && i < players.length),
         'botPlayers contains an index outside 0..${players.length - 1}.',
       ),
       _diceRoller = diceRoller ?? _defaultDiceRoller,
       _engine = LudoEngine(diceRules, teams: teams),
       _bots = {...botPlayers},
       botStrategy =
           botStrategy ?? LudoBotStrategy.forDifficulty(botDifficulty) {
    _state = LudoGameState.initial(players, teams: teams);
    _scheduleNext();
  }

  static final Random _random = Random();
  static int _defaultDiceRoller() => 1 + _random.nextInt(6);

  final LudoDiceRules diceRules;

  /// Delay between each cell while a piece moves. [Duration.zero] commits
  /// moves immediately (useful for tests and simulations).
  final Duration stepAnimationDuration;

  /// How long a bot waits before rolling or picking a piece.
  final Duration botThinkDuration;

  /// When a human rolls and every legal move leads to the same result
  /// (a single legal move, or several pieces stacked on the same cell),
  /// play it automatically after [autoMoveDelay].
  final bool autoMoveSingleChoice;

  /// Delay before an automatic single-choice move, so the rolled value is
  /// visible first.
  final Duration autoMoveDelay;

  final int Function() _diceRoller;
  LudoEngine _engine;
  final Set<int> _bots;

  /// The strategy bots use to pick moves. Can be swapped at any time.
  LudoBotStrategy botStrategy;

  final LudoDiceRolledCallback? onDiceRolled;
  final LudoPieceMovedCallback? onPieceMoved;
  final LudoPieceCapturedCallback? onPieceCaptured;
  final LudoTurnChangedCallback? onTurnChanged;
  final LudoPlayerWonCallback? onPlayerWon;
  final LudoTeamWonCallback? onTeamWon;
  final LudoGameFinishedCallback? onGameFinished;
  final LudoTurnForfeitedCallback? onTurnForfeited;

  late LudoGameState _state;

  LudoPiece? _animatingPiece;
  bool _isAnimating = false;
  bool _paused = false;
  bool _disposed = false;
  Timer? _timer;

  /// Incremented whenever in-flight work (animations, timers) must be
  /// abandoned: on [reset], [restore], and [dispose].
  int _generation = 0;

  // ── public getters ────────────────────────────────────────────────
  LudoGameState get state => _state;
  bool get isAnimating => _isAnimating;
  LudoPiece? get animatingPiece => _animatingPiece;
  bool get isTeamsMode => _state.teams != null;
  List<LudoTeam>? get teams => _state.teams;

  /// Whether automatic play (bots and auto-moves) is suspended.
  bool get isPaused => _paused;

  /// Seats currently played by the bot.
  Set<int> get botPlayers => Set.unmodifiable(_bots);

  /// Whether [playerIndex] is played by the bot.
  bool isBot(int playerIndex) => _bots.contains(playerIndex);

  /// Whether the player to move is a bot.
  bool get isCurrentPlayerBot => _bots.contains(_state.currentPlayerIndex);

  /// Whether a human may call [rollDice] right now.
  bool get canRoll =>
      !_disposed &&
      !_paused &&
      !_isAnimating &&
      !isCurrentPlayerBot &&
      _state.phase == LudoTurnPhase.awaitingRoll;

  /// Whether a human may call [selectPiece] right now.
  bool get canSelectPiece =>
      !_disposed &&
      !_paused &&
      !_isAnimating &&
      !isCurrentPlayerBot &&
      _state.phase == LudoTurnPhase.awaitingPieceSelection;

  /// Switches every bot to the built-in strategy for [difficulty].
  set botDifficulty(LudoBotDifficulty difficulty) =>
      botStrategy = LudoBotStrategy.forDifficulty(difficulty);

  // ── seats & pausing ───────────────────────────────────────────────

  /// Hands [playerIndex] over to the bot (`true`) or to a human (`false`)
  /// — e.g. when a player leaves mid-game.
  void setBot(int playerIndex, bool isBot) {
    RangeError.checkValidIndex(playerIndex, _state.players, 'playerIndex');
    final changed = isBot ? _bots.add(playerIndex) : _bots.remove(playerIndex);
    if (!changed) return;
    _notify();
    _scheduleNext();
  }

  /// Suspends bots and automatic moves, and blocks [rollDice] and
  /// [selectPiece] until [resume] is called. A move already animating
  /// finishes normally.
  void pause() {
    if (_paused) return;
    _paused = true;
    _cancelTimer();
    _notify();
  }

  /// Resumes play after [pause].
  void resume() {
    if (!_paused) return;
    _paused = false;
    _notify();
    _scheduleNext();
  }

  /// The move the hard bot would play now, for showing a hint to a human.
  /// `null` unless a piece selection is pending.
  LudoLegalMove? suggestMove() {
    if (_state.phase != LudoTurnPhase.awaitingPieceSelection ||
        _state.legalMoves.isEmpty) {
      return null;
    }
    return const LudoHardBot().chooseMove(_state);
  }

  // ── roll ──────────────────────────────────────────────────────────

  /// Rolls the dice for the current (human) player and returns the value.
  ///
  /// Throws a [StateError] if it is a bot's turn, the game is paused or
  /// over, a piece selection is pending, or a move is animating.
  int rollDice() {
    _checkHumanTurn('rollDice');
    return _roll();
  }

  int _roll() {
    _checkNotDisposed();
    if (_state.isFinished) throw StateError('Game already finished.');
    if (_state.phase == LudoTurnPhase.awaitingPieceSelection) {
      throw StateError('Select a piece first.');
    }
    if (_isAnimating) throw StateError('Animation in progress.');
    if (_paused) throw StateError('Game is paused.');

    _cancelTimer();
    final value = _diceRoller();
    if (value < 1 || value > 6) {
      throw RangeError.range(value, 1, 6, 'diceRoller()');
    }

    final gen = _generation;
    final roller = _state.currentPlayerIndex;
    final result = _engine.roll(_state, value);
    _state = result.state;

    onDiceRolled?.call(value);
    if (gen != _generation) return value;
    if (result.forfeited) {
      onTurnForfeited?.call(roller, diceRules.forfeitStreak!);
      if (gen != _generation) return value;
    }
    if (result.passed) onTurnChanged?.call(_state.currentPlayerIndex);
    if (gen != _generation) return value;

    _notify();
    _scheduleNext();
    return value;
  }

  // ── select piece ──────────────────────────────────────────────────

  /// Moves [pieceId] using the current roll, animating it one cell at a
  /// time. Completes once the move is committed.
  ///
  /// Throws a [StateError] if it is a bot's turn or no roll is pending,
  /// and an [ArgumentError] if [pieceId] is not a legal move. Calls made
  /// while another move is animating are ignored.
  Future<void> selectPiece(int pieceId) async {
    _checkHumanTurn('selectPiece');
    await _select(pieceId);
  }

  Future<void> _select(int pieceId) async {
    _checkNotDisposed();
    if (_state.phase != LudoTurnPhase.awaitingPieceSelection) {
      throw StateError('Roll the dice first.');
    }
    if (_isAnimating) return;
    if (_paused) throw StateError('Game is paused.');

    final move = _state.legalMoves.firstWhere(
      (m) => m.pieceId == pieceId,
      orElse: () => throw ArgumentError('Piece $pieceId is not a legal move.'),
    );
    _cancelTimer();
    final gen = _generation;

    if (stepAnimationDuration > Duration.zero) {
      final piece = _state.pieceById(pieceId);
      _isAnimating = true;
      for (var step = 1; step <= move.steps; step++) {
        _animatingPiece = piece.copyWith(
          trackPosition: piece.trackPosition + step,
        );
        _notify();
        await Future<void>.delayed(stepAnimationDuration);
        if (gen != _generation) return; // reset / restore / dispose
      }
      _animatingPiece = null;
      _isAnimating = false;
    }

    _commit(pieceId, gen);
  }

  void _commit(int pieceId, int gen) {
    final result = _engine.move(_state, pieceId);
    _state = result.state.copyWith(lastMovedPiece: result.movedPiece);

    // Callbacks may reset or dispose the controller; stop if they do.
    bool stale() => gen != _generation;

    onPieceMoved?.call(
      result.movedPiece,
      result.fromPosition,
      result.toPosition,
    );
    if (stale()) return;

    for (final captured in result.capturedPieces) {
      onPieceCaptured?.call(captured, result.movedPiece);
      if (stale()) return;
    }

    if (result.playerWon) {
      final place = _state.winners.indexOf(result.movedPiece.playerIndex) + 1;
      onPlayerWon?.call(result.movedPiece.playerIndex, place);
      if (stale()) return;
    }

    if (result.teamWon) {
      final myTeam = teamOf(result.movedPiece.playerIndex, _state.teams);
      if (myTeam != null) onTeamWon?.call(myTeam);
      if (stale()) return;
    }

    if (result.gameFinished) {
      onGameFinished?.call(List.unmodifiable(_state.winners));
    } else if (result.turnPassed) {
      onTurnChanged?.call(_state.currentPlayerIndex);
    }
    if (stale()) return;

    _notify();
    _scheduleNext();
  }

  // ── reset / restore ───────────────────────────────────────────────

  /// Starts a new game with the same players, teams, and bot seats.
  void reset() {
    _checkNotDisposed();
    _abortInFlight();
    _state = LudoGameState.initial(_state.players, teams: _state.teams);
    _notify();
    _scheduleNext();
  }

  /// Replaces the current game with [state] — e.g. one saved earlier with
  /// [LudoGameState.toJson]. Bot seats outside the new player range are
  /// dropped.
  void restore(LudoGameState state) {
    _checkNotDisposed();
    if (state.players.length < 2 || state.players.length > 4) {
      throw ArgumentError.value(
        state.players.length,
        'state.players',
        'Must have 2 to 4 players',
      );
    }
    if (state.teams != null && state.players.length != 4) {
      throw ArgumentError('Teams mode requires exactly 4 players.');
    }
    _abortInFlight();
    _state = state;
    _engine = LudoEngine(diceRules, teams: state.teams);
    _bots.removeWhere((i) => i >= state.players.length);
    _notify();
    _scheduleNext();
  }

  @override
  void dispose() {
    _disposed = true;
    _abortInFlight();
    super.dispose();
  }

  // ── automatic play ────────────────────────────────────────────────

  /// Schedules the next automatic action, if any: a bot roll, a bot move,
  /// or a human's single-choice auto-move.
  void _scheduleNext() {
    _cancelTimer();
    if (_disposed || _paused || _isAnimating || _state.isFinished) return;

    final gen = _generation;
    if (isCurrentPlayerBot) {
      _timer = Timer(botThinkDuration, () {
        if (gen == _generation) _runBotStep();
      });
    } else if (autoMoveSingleChoice &&
        _state.phase == LudoTurnPhase.awaitingPieceSelection &&
        _hasSingleChoice()) {
      final pieceId = _state.legalMoves.first.pieceId;
      _timer = Timer(autoMoveDelay, () {
        if (gen != _generation ||
            _state.phase != LudoTurnPhase.awaitingPieceSelection) {
          return;
        }
        _select(pieceId).catchError(_reportError);
      });
    }
  }

  bool _hasSingleChoice() {
    final moves = _state.legalMoves;
    if (moves.isEmpty) return false;
    final first = moves.first;
    return moves.every(
      (m) =>
          m.fromPosition == first.fromPosition &&
          m.toPosition == first.toPosition,
    );
  }

  void _runBotStep() {
    if (_disposed || _paused || _isAnimating || !isCurrentPlayerBot) return;
    try {
      switch (_state.phase) {
        case LudoTurnPhase.awaitingRoll:
          _roll();
        case LudoTurnPhase.awaitingPieceSelection:
          _select(_chooseBotMove().pieceId).catchError(_reportError);
        case LudoTurnPhase.gameOver:
          break;
      }
    } catch (error, stack) {
      _reportError(error, stack);
    }
  }

  LudoLegalMove _chooseBotMove() {
    final legal = _state.legalMoves;
    try {
      final choice = botStrategy.chooseMove(_state);
      if (legal.contains(choice)) return choice;
    } catch (error, stack) {
      _reportError(error, stack);
    }
    return legal.first;
  }

  // ── helpers ───────────────────────────────────────────────────────

  void _abortInFlight() {
    _generation++;
    _cancelTimer();
    _isAnimating = false;
    _animatingPiece = null;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('LudoController was used after dispose.');
  }

  void _checkHumanTurn(String method) {
    if (isCurrentPlayerBot && !_state.isFinished) {
      throw StateError(
        '$method called during a bot turn (player '
        '${_state.currentPlayerIndex}). Bots play automatically.',
      );
    }
  }

  void _reportError(Object error, [StackTrace? stack]) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'flutter_ludo',
        context: ErrorDescription('during automatic play'),
      ),
    );
  }
}
