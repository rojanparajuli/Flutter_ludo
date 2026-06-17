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
  LudoDiceRules diceRules =
      const LudoDiceRules(startAllowedValues: [6], extraTurnValues: [6]),
  void Function(int)? onDiceRolled,
  void Function(LudoPiece, int, int)? onPieceMoved,
  void Function(LudoPiece, LudoPiece)? onPieceCaptured,
  void Function(int)? onTurnChanged,
  void Function(int, int)? onPlayerWon,
  void Function(List<int>)? onGameFinished,
}) {
  var i = 0;
  return LudoController(
    players: _players(),
    diceRules: diceRules,
    diceRoller: () => rolls[i++],
    onDiceRolled: onDiceRolled,
    onPieceMoved: onPieceMoved,
    onPieceCaptured: onPieceCaptured,
    onTurnChanged: onTurnChanged,
    onPlayerWon: onPlayerWon,
    onGameFinished: onGameFinished,
  );
}

void main() {
  test('rolling a non-start value with all pieces home passes the turn', () {
    final controller = _controllerWithRolls([3]);
    controller.rollDice();
    expect(controller.state.currentPlayerIndex, 1);
    expect(controller.state.legalMoves, isEmpty);
  });

  test('rolling a 6 lets a piece leave home, and grants an extra turn', () {
    final controller = _controllerWithRolls([6]);
    controller.rollDice();
    expect(controller.state.legalMoves, isNotEmpty);

    controller.selectPiece(controller.state.legalMoves.first.pieceId);

    expect(controller.state.currentPlayerIndex, 0); // extra turn
    expect(
      controller.state.pieces.where((p) => p.trackPosition == 0).length,
      1,
    );
  });

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

  test('reset returns to a fresh game with the same players', () {
    final controller = _controllerWithRolls([6]);
    controller.rollDice();
    controller.selectPiece(controller.state.legalMoves.first.pieceId);
    controller.reset();

    expect(controller.state.currentPlayerIndex, 0);
    expect(controller.state.pieces.every((p) => p.isHome), isTrue);
    expect(controller.state.players, _players());
  });

  test('events fire in the expected order for a simple move', () {
    final events = <String>[];
    final controller = _controllerWithRolls(
      [6],
      onDiceRolled: (v) => events.add('dice:$v'),
      onPieceMoved: (piece, from, to) => events.add('moved:${piece.id}'),
    );

    controller.rollDice();
    controller.selectPiece(controller.state.legalMoves.first.pieceId);

    expect(events, ['dice:6', 'moved:0']);
  });

  test('notifies listeners on every state change', () {
    var notifications = 0;
    final controller = _controllerWithRolls([6])
      ..addListener(() => notifications++);

    controller.rollDice();
    controller.selectPiece(controller.state.legalMoves.first.pieceId);

    expect(notifications, 2);
  });
}