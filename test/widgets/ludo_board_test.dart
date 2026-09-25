import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

List<LudoPlayer> _players() => const [
  LudoPlayer(name: 'A', color: Colors.red),
  LudoPlayer(name: 'B', color: Colors.green),
  LudoPlayer(name: 'C', color: Colors.yellow),
  LudoPlayer(name: 'D', color: Colors.blue),
];

LudoController _scripted(List<int> rolls, {Set<int> bots = const {}}) {
  var i = 0;
  return LudoController(
    players: _players(),
    botPlayers: bots,
    diceRoller: () => rolls[i++ % rolls.length],
    botThinkDuration: const Duration(milliseconds: 100),
  );
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('LudoGame renders the board, status bar, and roll button', (
    tester,
  ) async {
    final controller = LudoController(players: _players());
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(LudoGame(controller: controller)));

    expect(find.byType(LudoBoard), findsOneWidget);
    expect(find.text('Roll'), findsOneWidget);
    expect(find.text("A's turn"), findsOneWidget);
  });

  testWidgets('rolling the dice via the UI updates the status bar', (
    tester,
  ) async {
    // Can't start with the default rule ([6]) -> passes.
    final controller = _scripted([3]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(LudoGame(controller: controller)));

    await tester.tap(find.text('Roll'));
    await tester.pump();

    expect(find.text("B's turn"), findsOneWidget);
  });

  testWidgets('tapping a legal piece moves it', (tester) async {
    // 6 brings piece 0 out; the second 6 offers "move piece 0" or
    // "bring out another", so the player must choose.
    final controller = _scripted([6, 6]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 400,
          height: 700,
          child: LudoGame(controller: controller),
        ),
      ),
    );

    await tester.tap(find.text('Roll'));
    await tester.pump(const Duration(seconds: 1)); // auto-move out
    expect(controller.state.pieceById(0).trackPosition, 0);

    await tester.tap(find.text('Roll'));
    await tester.pump();
    expect(find.text('Pick a piece'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('A piece 1'));
    await tester.pump(const Duration(seconds: 2)); // 6 animation steps
    expect(controller.state.pieceById(0).trackPosition, 6);
  });

  testWidgets('the dice is disabled while a bot plays, then bots finish', (
    tester,
  ) async {
    final controller = _scripted([3], bots: {1, 2, 3});
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(LudoGame(controller: controller)));
    await tester.tap(find.text('Roll'));
    await tester.pump();

    expect(find.text('Bot thinking…'), findsOneWidget);
    await tester.tap(find.text('Bot thinking…'));
    expect(controller.state.currentPlayerIndex, 1); // tap ignored

    await tester.pump(const Duration(seconds: 1));
    expect(controller.state.currentPlayerIndex, 0);
    expect(find.text('Roll'), findsOneWidget);
  });

  testWidgets('game over overlay shows results and Play Again resets', (
    tester,
  ) async {
    final controller = LudoController(players: _players().take(2).toList());
    addTearDown(controller.dispose);

    controller.restore(
      LudoGameState.initial(
        controller.state.players,
      ).copyWith(phase: LudoTurnPhase.gameOver, winners: [1, 0]),
    );

    await tester.pumpWidget(_host(LudoGame(controller: controller)));
    expect(find.text('Game Over'), findsOneWidget);
    expect(find.text('Game over'), findsOneWidget); // dice label

    await tester.tap(find.text('Play Again'));
    await tester.pump();
    expect(find.text('Game Over'), findsNothing);
    expect(controller.state.isFinished, isFalse);
  });

  testWidgets('LudoSetup starts a bot game and returns to setup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: LudoSetup(theme: LudoTheme.dark)),
    );

    expect(find.text('Bot difficulty'), findsOneWidget);
    await tester.tap(find.text('Hard'));
    await tester.pump();

    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pump();
    expect(find.byType(LudoGame), findsOneWidget);

    // Seat 0 is human, 1-3 are bots by default.
    await tester.tap(find.text('Roll'));
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Start Game'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // no stray timers
  });

  testWidgets('LudoBoard works standalone and ignores taps on bot turns', (
    tester,
  ) async {
    final controller = _scripted([6, 3], bots: {0});
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: LudoBoard(controller: controller),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 150)); // bot rolls a 6
    expect(controller.state.phase, LudoTurnPhase.awaitingPieceSelection);
    expect(controller.canSelectPiece, isFalse);

    await tester.tap(find.bySemanticsLabel('A piece 1'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 3));
    // The bot, not the tap, decided: out with the 6, then 3 more.
    expect(controller.state.currentPlayerIndex, 1);
    expect(controller.state.piecesOf(0).where((p) => !p.isHome).length, 1);
  });

  testWidgets('fast all-bot games render without errors', (tester) async {
    final random = Random(5);
    final controller = LudoController(
      players: _players(),
      botPlayers: {0, 1, 2, 3},
      diceRoller: () => 1 + random.nextInt(6),
      botThinkDuration: const Duration(milliseconds: 50),
      stepAnimationDuration: Duration.zero,
      teams: kDefaultTeams,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(LudoGame(controller: controller)));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(controller.state.rollCount, greaterThan(20));
    controller.pause();
    await tester.pump(const Duration(seconds: 1));
  });
}
