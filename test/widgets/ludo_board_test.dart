import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

List<LudoPlayer> _players() => const [
      LudoPlayer(name: 'A', color: Colors.red),
      LudoPlayer(name: 'B', color: Colors.green),
      LudoPlayer(name: 'C', color: Colors.yellow),
      LudoPlayer(name: 'D', color: Colors.blue),
    ];

void main() {
  testWidgets('LudoGame renders the board, status bar, and roll button',
      (tester) async {
    final controller = LudoController(players: _players());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LudoGame(controller: controller)),
      ),
    );

    expect(find.text('Roll'), findsOneWidget);
    expect(find.text("A's turn"), findsOneWidget);
  });

  testWidgets('rolling the dice via the UI updates the status bar',
      (tester) async {
    var i = 0;
    final rolls = [3]; // can't start with the default rule ([6]) -> passes
    final controller = LudoController(
      players: _players(),
      diceRoller: () => rolls[i++],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LudoGame(controller: controller)),
      ),
    );

    await tester.tap(find.text('Roll'));
    await tester.pump();

    expect(find.text("B's turn"), findsOneWidget);
  });

  testWidgets('tapping a legal piece moves it', (tester) async {
    var i = 0;
    final rolls = [6];
    final controller = LudoController(
      players: _players(),
      diceRoller: () => rolls[i++],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 360,
            child: LudoGame(controller: controller),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Roll'));
    await tester.pump();
    expect(controller.state.legalMoves, isNotEmpty);

    final pieceId = controller.state.legalMoves.first.pieceId;
    controller.selectPiece(pieceId);
    await tester.pump();

    final piece = controller.state.pieces.firstWhere((p) => p.id == pieceId);
    expect(piece.trackPosition, 0);
  });
}