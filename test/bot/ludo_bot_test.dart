import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
// ignore: deprecated_member_use_from_same_package
import 'package:flutter_ludo/bot/ludo_bot_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

const _allPlayers = [
  LudoPlayer(name: 'A', color: Colors.red),
  LudoPlayer(name: 'B', color: Colors.green),
  LudoPlayer(name: 'C', color: Colors.yellow),
  LudoPlayer(name: 'D', color: Colors.blue),
];

LudoController _botGame({
  required int players,
  required Set<int> bots,
  required int seed,
  LudoBotDifficulty difficulty = LudoBotDifficulty.medium,
  LudoBotStrategy? strategy,
  List<LudoTeam>? teams,
  LudoDiceRules diceRules = const LudoDiceRules(),
  Duration stepAnimationDuration = Duration.zero,
  void Function(List<int>)? onGameFinished,
}) {
  final random = Random(seed);
  return LudoController(
    players: _allPlayers.take(players).toList(),
    botPlayers: bots,
    botDifficulty: difficulty,
    botStrategy: strategy,
    teams: teams,
    diceRules: diceRules,
    diceRoller: () => 1 + random.nextInt(6),
    botThinkDuration: const Duration(milliseconds: 10),
    stepAnimationDuration: stepAnimationDuration,
    onGameFinished: onGameFinished,
  );
}

/// Lets bots play until the game ends, or fails after [limit].
void _playOut(
  FakeAsync async,
  LudoController c, {
  Duration limit = const Duration(hours: 2),
}) {
  var elapsed = Duration.zero;
  const step = Duration(seconds: 10);
  while (!c.state.isFinished && elapsed < limit) {
    async.elapse(step);
    elapsed += step;
  }
  expect(
    c.state.isFinished,
    isTrue,
    reason:
        'Bots stalled: phase=${c.state.phase}, '
        'player=${c.state.currentPlayerIndex}, rolls=${c.state.rollCount}',
  );
}

void main() {
  group('all-bot games run to completion', () {
    for (final difficulty in LudoBotDifficulty.values) {
      for (final count in [2, 3, 4]) {
        test('$count players, $difficulty', () {
          fakeAsync((async) {
            List<int>? winners;
            final c = _botGame(
              players: count,
              bots: {for (var i = 0; i < count; i++) i},
              seed: count * 31 + difficulty.index,
              difficulty: difficulty,
              onGameFinished: (w) => winners = w,
            );
            _playOut(async, c);

            expect(winners, isNotNull);
            expect(winners!.toSet().length, count);
            c.dispose();
          });
        });
      }
    }

    test('teams mode', () {
      fakeAsync((async) {
        final c = _botGame(
          players: 4,
          bots: {0, 1, 2, 3},
          seed: 7,
          difficulty: LudoBotDifficulty.hard,
          teams: kDefaultTeams,
        );
        _playOut(async, c);
        expect(c.state.winningTeam, isNotNull);
        c.dispose();
      });
    });

    test('modern rules with step animation', () {
      fakeAsync((async) {
        final c = _botGame(
          players: 4,
          bots: {0, 1, 2, 3},
          seed: 11,
          diceRules: const LudoDiceRules.modern(),
          stepAnimationDuration: const Duration(milliseconds: 5),
        );
        _playOut(async, c);
        c.dispose();
      });
    });

    test('many random seeds never stall', () {
      fakeAsync((async) {
        for (var seed = 100; seed < 120; seed++) {
          final c = _botGame(
            players: 4,
            bots: {0, 1, 2, 3},
            seed: seed,
            difficulty: LudoBotDifficulty.values[seed % 3],
          );
          _playOut(async, c);
          c.dispose();
        }
      });
    });
  });

  group('mixed human and bot seats', () {
    test('bots play in turn and hand control back to the human', () {
      fakeAsync((async) {
        // Human rolls a 3 (no move). Bots 1-3 then play. Control must
        // come back to seat 0 without the human doing anything.
        const rolls = [3, 6, 2, 6, 1, 5, 4];
        var i = 0;
        final c = LudoController(
          players: _allPlayers,
          botPlayers: {1, 2, 3},
          diceRoller: () => i < rolls.length ? rolls[i++] : 1,
          stepAnimationDuration: Duration.zero,
          botThinkDuration: const Duration(milliseconds: 100),
        );

        expect(c.canRoll, isTrue);
        c.rollDice();
        expect(c.state.currentPlayerIndex, 1);
        expect(c.canRoll, isFalse);

        async.elapse(const Duration(seconds: 10));
        expect(c.state.currentPlayerIndex, 0);
        expect(c.canRoll, isTrue);
        // Bot 1 rolled 6: it should have moved a piece out and then rolled
        // again (extra turn) — the old controller froze exactly here.
        expect(c.state.piecesOf(1).any((p) => !p.isHome), isTrue);
        c.dispose();
      });
    });

    test('a bot seat that starts first plays immediately', () {
      fakeAsync((async) {
        final c = LudoController(
          players: _allPlayers.take(2).toList(),
          botPlayers: {0},
          diceRoller: () => 3,
          botThinkDuration: const Duration(milliseconds: 100),
        );
        async.elapse(const Duration(milliseconds: 150));
        expect(c.state.rollCount, 1);
        expect(c.state.currentPlayerIndex, 1);
        c.dispose();
      });
    });

    test('humans cannot act during a bot turn', () {
      final c = LudoController(
        players: _allPlayers.take(2).toList(),
        botPlayers: {0},
        botThinkDuration: const Duration(hours: 1),
      );
      expect(c.canRoll, isFalse);
      expect(() => c.rollDice(), throwsStateError);
      c.dispose();
    });

    test('setBot hands a seat over to the bot mid-game', () {
      fakeAsync((async) {
        final c = LudoController(
          players: _allPlayers.take(2).toList(),
          diceRoller: () => 3,
          botThinkDuration: const Duration(milliseconds: 100),
        );
        async.elapse(const Duration(seconds: 1));
        expect(c.state.rollCount, 0, reason: 'humans never auto-roll');

        c.setBot(0, true);
        c.setBot(1, true);
        async.elapse(const Duration(seconds: 1));
        expect(c.state.rollCount, greaterThan(2));

        c.setBot(0, false);
        c.setBot(1, false);
        final count = c.state.rollCount;
        async.elapse(const Duration(seconds: 1));
        expect(c.state.rollCount, count);
        c.dispose();
      });
    });

    test('pause stops bots and resume restarts them', () {
      fakeAsync((async) {
        final c = _botGame(players: 2, bots: {0, 1}, seed: 1);
        c.pause();
        async.elapse(const Duration(seconds: 5));
        expect(c.state.rollCount, 0);

        c.resume();
        async.elapse(const Duration(seconds: 1));
        expect(c.state.rollCount, greaterThan(0));
        c.dispose();
      });
    });

    test('reset restarts bot play', () {
      fakeAsync((async) {
        final c = _botGame(players: 2, bots: {0, 1}, seed: 2);
        _playOut(async, c);
        c.reset();
        expect(c.state.isFinished, isFalse);
        _playOut(async, c);
        c.dispose();
      });
    });

    test('no timers survive dispose', () {
      fakeAsync((async) {
        final c = _botGame(players: 4, bots: {0, 1, 2, 3}, seed: 3);
        async.elapse(const Duration(seconds: 3));
        c.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('strategies', () {
    test('a broken custom strategy falls back to a legal move', () {
      fakeAsync((async) {
        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = previous);

        final c = _botGame(
          players: 2,
          bots: {0, 1},
          seed: 4,
          strategy: const _ThrowingBot(),
        );
        _playOut(async, c);
        expect(errors, isNotEmpty);
        c.dispose();
      });
    });

    LudoGameState stateWith(Map<int, int> positions, int dice) {
      final base = LudoGameState.initial(_allPlayers);
      final pieces = [
        for (final p in base.pieces)
          p.copyWith(trackPosition: positions[p.id] ?? p.trackPosition),
      ];
      final state = base.copyWith(pieces: pieces);
      return state.copyWith(
        phase: LudoTurnPhase.awaitingPieceSelection,
        diceValue: dice,
        legalMoves: computeLegalMoves(state, const LudoDiceRules(), dice),
      );
    }

    test('medium and hard bots take an available capture', () {
      // Piece 0 at 10 can capture player 1's piece at global cell 14
      // (player 1 track 1) with a 4. Piece 1 at 20 has a quiet move.
      final state = stateWith({0: 10, 1: 20, 4: 1}, 4);
      for (final bot in [const LudoMediumBot(), const LudoHardBot()]) {
        expect(bot.chooseMove(state).pieceId, 0, reason: '$bot');
      }
    });

    test('hard bot prefers capturing the more advanced piece', () {
      // With a 4, lead piece 0 (40 -> global 44) can hit player 3's piece
      // at track 5, while piece 1 (10 -> global 14) can hit player 2's
      // piece at track 40. Medium favours its lead piece; hard takes the
      // more valuable capture.
      final state = stateWith({0: 40, 1: 10, 12: 5, 8: 40}, 4);
      expect(const LudoMediumBot().chooseMove(state).pieceId, 0);
      expect(const LudoHardBot().chooseMove(state).pieceId, 1);
    });

    test('hard bot moves a threatened piece to safety', () {
      // Piece 0 at track 5 (global 5) has player 3's piece two cells
      // behind it (global 3 = player 3 track 16). Rolling a 3 takes piece
      // 0 to the global-8 star; piece 1 at 30 has a quiet move.
      final state = stateWith({0: 5, 1: 30, 12: 16}, 3);
      expect(const LudoHardBot().chooseMove(state).pieceId, 0);
    });

    test('easy bot is deterministic with a seeded Random', () {
      final state = stateWith({0: 10, 1: 20, 2: 30}, 2);
      final a = LudoEasyBot(random: Random(1));
      final b = LudoEasyBot(random: Random(1));
      for (var i = 0; i < 10; i++) {
        expect(a.chooseMove(state), b.chooseMove(state));
      }
    });
  });

  test('deprecated LudoBotController still drives bots', () {
    fakeAsync((async) {
      final random = Random(9);
      // ignore: deprecated_member_use_from_same_package
      final c = LudoBotController(
        players: _allPlayers,
        botPlayerIndices: {0, 1, 2, 3},
        diceRoller: () => 1 + random.nextInt(6),
        thinkDuration: const Duration(milliseconds: 10),
        stepAnimationDuration: Duration.zero,
      );
      expect(c.innerController, same(c));
      _playOut(async, c);
      c.dispose();
    });
  });
}

class _ThrowingBot extends LudoBotStrategy {
  const _ThrowingBot();

  @override
  LudoLegalMove chooseMove(LudoGameState state) => throw StateError('boom');
}
