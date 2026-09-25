import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

List<LudoPlayer> _players() => const [
  LudoPlayer(name: 'A', color: Colors.red),
  LudoPlayer(name: 'B', color: Colors.green),
  LudoPlayer(name: 'C', color: Colors.yellow),
  LudoPlayer(name: 'D', color: Colors.blue),
];

/// Builds a controller whose dice rolls are scripted, for deterministic
/// tests. flutter_ludo's [LudoController] accepts a `diceRoller` override
/// for exactly this purpose.
LudoController _controllerWithRolls(
  List<int> rolls, {
  LudoDiceRules diceRules = const LudoDiceRules(
    startAllowedValues: [6],
    extraTurnValues: [6],
  ),
  Duration stepAnimationDuration = Duration.zero,
  bool autoMoveSingleChoice = false,
  void Function(int)? onDiceRolled,
  void Function(LudoPiece, int, int)? onPieceMoved,
  void Function(LudoPiece, LudoPiece)? onPieceCaptured,
  void Function(int)? onTurnChanged,
  void Function(int, int)? onPlayerWon,
  void Function(List<int>)? onGameFinished,
  void Function(int, int)? onTurnForfeited,
}) {
  var i = 0;
  return LudoController(
    players: _players(),
    diceRules: diceRules,
    diceRoller: () => rolls[i++],
    stepAnimationDuration: stepAnimationDuration,
    autoMoveSingleChoice: autoMoveSingleChoice,
    onDiceRolled: onDiceRolled,
    onPieceMoved: onPieceMoved,
    onPieceCaptured: onPieceCaptured,
    onTurnChanged: onTurnChanged,
    onPlayerWon: onPlayerWon,
    onGameFinished: onGameFinished,
    onTurnForfeited: onTurnForfeited,
  );
}

void main() {
  test('rolling a non-start value with all pieces home passes the turn', () {
    final controller = _controllerWithRolls([3]);
    controller.rollDice();
    expect(controller.state.currentPlayerIndex, 1);
    expect(controller.state.legalMoves, isEmpty);
    expect(controller.state.lastRoll, 3);
    expect(controller.state.lastRollPlayerIndex, 0);
  });

  test(
    'rolling a 6 lets a piece leave home, and grants an extra turn',
    () async {
      final controller = _controllerWithRolls([6]);
      controller.rollDice();
      expect(controller.state.legalMoves, isNotEmpty);

      await controller.selectPiece(controller.state.legalMoves.first.pieceId);

      expect(controller.state.currentPlayerIndex, 0); // extra turn
      expect(
        controller.state.pieces.where((p) => p.trackPosition == 0).length,
        1,
      );
    },
  );

  test('selecting an illegal piece throws', () {
    final controller = _controllerWithRolls([6]);
    controller.rollDice();
    expect(() => controller.selectPiece(9999), throwsArgumentError);
  });

  test('rolling before the previous selection is resolved throws', () {
    final controller = _controllerWithRolls([6, 6]);
    controller.rollDice();
    expect(() => controller.rollDice(), throwsStateError);
  });

  test('diceRoller values outside 1..6 are rejected', () {
    final controller = _controllerWithRolls([7]);
    expect(() => controller.rollDice(), throwsRangeError);
  });

  test('reset returns to a fresh game with the same players', () async {
    final controller = _controllerWithRolls([6]);
    controller.rollDice();
    await controller.selectPiece(controller.state.legalMoves.first.pieceId);
    controller.reset();

    expect(controller.state.currentPlayerIndex, 0);
    expect(controller.state.pieces.every((p) => p.isHome), isTrue);
    expect(controller.state.players, _players());
    expect(controller.state.lastRoll, isNull);
  });

  test('events fire in the expected order for a simple move', () async {
    final events = <String>[];
    final controller = _controllerWithRolls(
      [6],
      onDiceRolled: (v) => events.add('dice:$v'),
      onPieceMoved: (piece, from, to) => events.add('moved:${piece.id}'),
    );

    controller.rollDice();
    await controller.selectPiece(controller.state.legalMoves.first.pieceId);

    expect(events, ['dice:6', 'moved:0']);
  });

  test('notifies listeners on every state change', () async {
    var notifications = 0;
    final controller = _controllerWithRolls([6])
      ..addListener(() => notifications++);

    controller.rollDice();
    await controller.selectPiece(controller.state.legalMoves.first.pieceId);

    expect(notifications, 2);
  });

  test('onTurnForfeited fires when the forfeit streak is reached', () async {
    final forfeits = <int>[];
    final controller = _controllerWithRolls(
      [6, 6, 6],
      diceRules: const LudoDiceRules(forfeitStreak: 3),
      onTurnForfeited: (player, streak) => forfeits.add(player),
    );

    for (var i = 0; i < 2; i++) {
      controller.rollDice();
      await controller.selectPiece(controller.state.legalMoves.first.pieceId);
    }
    controller.rollDice();

    expect(forfeits, [0]);
    expect(controller.state.currentPlayerIndex, 1);
  });

  group('step animation', () {
    test('animates one cell at a time, then commits', () {
      fakeAsync((async) {
        final controller = _controllerWithRolls([
          6,
        ], stepAnimationDuration: const Duration(milliseconds: 100));
        controller.rollDice();
        final id = controller.state.legalMoves.first.pieceId;
        controller.selectPiece(id);

        expect(controller.isAnimating, isTrue);
        expect(controller.animatingPiece?.trackPosition, 0);

        async.elapse(const Duration(milliseconds: 100));
        expect(controller.isAnimating, isFalse);
        expect(controller.state.pieceById(id).trackPosition, 0);
      });
    });

    test('reset during an animation abandons the move', () {
      fakeAsync((async) {
        final controller = _controllerWithRolls([
          6,
        ], stepAnimationDuration: const Duration(milliseconds: 100));
        controller.rollDice();
        controller.selectPiece(controller.state.legalMoves.first.pieceId);
        controller.reset();

        async.elapse(const Duration(seconds: 1));
        expect(controller.state.pieces.every((p) => p.isHome), isTrue);
        expect(controller.isAnimating, isFalse);
      });
    });

    test('dispose during an animation does not throw', () {
      fakeAsync((async) {
        final controller = _controllerWithRolls([
          6,
        ], stepAnimationDuration: const Duration(milliseconds: 100));
        controller.rollDice();
        controller.selectPiece(controller.state.legalMoves.first.pieceId);
        controller.dispose();

        async.elapse(const Duration(seconds: 1));
      });
    });
  });

  group('auto-move', () {
    test('plays the move when every choice is equivalent', () {
      fakeAsync((async) {
        final controller = _controllerWithRolls([
          6,
        ], autoMoveSingleChoice: true);
        controller.rollDice(); // 4 home pieces, all -> position 0
        expect(controller.state.phase, LudoTurnPhase.awaitingPieceSelection);

        async.elapse(controller.autoMoveDelay);
        expect(controller.state.phase, LudoTurnPhase.awaitingRoll);
        expect(
          controller.state.pieces.where((p) => p.trackPosition == 0).length,
          1,
        );
      });
    });

    test('waits for the human when the choices differ', () {
      fakeAsync((async) {
        final controller = _controllerWithRolls([
          6,
          6,
        ], autoMoveSingleChoice: true);
        controller.rollDice();
        async.elapse(controller.autoMoveDelay); // piece 0 -> start
        controller.rollDice(); // move piece 0 by 6, or bring out another

        async.elapse(const Duration(seconds: 5));
        expect(controller.state.phase, LudoTurnPhase.awaitingPieceSelection);
      });
    });
  });

  group('save and restore', () {
    test('restore resumes a serialized game', () async {
      final controller = _controllerWithRolls([6, 4]);
      controller.rollDice();
      await controller.selectPiece(0);
      controller.rollDice();

      final saved = controller.state.toJson();

      final other = _controllerWithRolls([]);
      other.restore(LudoGameState.fromJson(saved));

      expect(other.state.phase, LudoTurnPhase.awaitingPieceSelection);
      expect(other.state.diceValue, 4);
      expect(other.state.legalMoves, controller.state.legalMoves);
      expect(other.state.pieces, controller.state.pieces);
      expect(other.state.lastMovedPiece, controller.state.lastMovedPiece);

      await other.selectPiece(0);
      expect(other.state.pieceById(0).trackPosition, 4);
    });

    test('restore rejects teams mode with fewer than 4 players', () {
      final controller = _controllerWithRolls([]);
      final state = LudoGameState.initial(
        _players().take(2).toList(),
        teams: kDefaultTeams,
      );
      expect(() => controller.restore(state), throwsArgumentError);
    });
  });

  test('suggestMove is null until a roll is pending', () {
    final controller = _controllerWithRolls([6]);
    expect(controller.suggestMove(), isNull);
    controller.rollDice();
    expect(controller.state.legalMoves, contains(controller.suggestMove()));
  });

  test('pause blocks human actions until resume', () {
    final controller = _controllerWithRolls([3]);
    controller.pause();
    expect(controller.canRoll, isFalse);
    expect(() => controller.rollDice(), throwsStateError);

    controller.resume();
    expect(controller.canRoll, isTrue);
    controller.rollDice();
  });

  test('using a disposed controller throws', () {
    final controller = _controllerWithRolls([3])..dispose();
    expect(() => controller.rollDice(), throwsStateError);
  });
}
