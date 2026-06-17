import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

List<LudoPlayer> _players() => const [
      LudoPlayer(name: 'A', color: Colors.red),
      LudoPlayer(name: 'B', color: Colors.green),
      LudoPlayer(name: 'C', color: Colors.yellow),
      LudoPlayer(name: 'D', color: Colors.blue),
    ];

LudoGameState _freshState() {
  final players = _players();
  final pieces = [
    for (var p = 0; p < players.length; p++)
      for (var i = 0; i < 4; i++) LudoPiece(id: p * 4 + i, playerIndex: p),
  ];
  return LudoGameState(
    players: players,
    pieces: pieces,
    currentPlayerIndex: 0,
    phase: LudoTurnPhase.awaitingRoll,
  );
}

void main() {
  group('LudoEngine.roll', () {
    test('passes the turn automatically when there are no legal moves', () {
      const engine = LudoEngine(LudoDiceRules(startAllowedValues: [6]));
      final result = engine.roll(_freshState(), 3); // all home, can't start

      expect(result.passed, isTrue);
      expect(result.state.currentPlayerIndex, 1);
      expect(result.state.phase, LudoTurnPhase.awaitingRoll);
      expect(result.state.diceValue, isNull);
    });

    test('produces legal moves and awaits selection otherwise', () {
      const engine = LudoEngine(LudoDiceRules(startAllowedValues: [6]));
      final result = engine.roll(_freshState(), 6);

      expect(result.passed, isFalse);
      expect(result.state.legalMoves.length, 4);
      expect(result.state.phase, LudoTurnPhase.awaitingPieceSelection);
      expect(result.state.diceValue, 6);
    });
  });

  group('LudoEngine.move', () {
    test('moves the chosen piece and captures an unsafe opponent', () {
      const engine = LudoEngine(LudoDiceRules());
      var state = _freshState();

      // Player 0's piece 0 sits at trackPosition 10 (global cell 10).
      // Player 1's piece 4 sits at trackPosition 1 (global cell 13+1=14,
      // not a safe cell).
      state = state.copyWith(
        pieces: [
          for (final p in state.pieces)
            if (p.id == 0)
              p.copyWith(trackPosition: 10)
            else if (p.id == 4)
              p.copyWith(trackPosition: 1)
            else
              p,
        ],
        diceValue: 4,
        legalMoves: const [
          LudoLegalMove(
            pieceId: 0,
            playerIndex: 0,
            fromPosition: 10,
            toPosition: 14,
          ),
        ],
        phase: LudoTurnPhase.awaitingPieceSelection,
      );

      final result = engine.move(state, 0);

      expect(result.toPosition, 14);
      expect(result.capturedPieces.map((p) => p.id), [4]);
      expect(
        result.state.pieces.firstWhere((p) => p.id == 4).isHome,
        isTrue,
      );
    });

    test('grants an extra turn on a value in extraTurnValues', () {
      const engine = LudoEngine(LudoDiceRules(extraTurnValues: [6]));
      var state = _freshState();
      state = state.copyWith(
        diceValue: 6,
        legalMoves: const [
          LudoLegalMove(
            pieceId: 0,
            playerIndex: 0,
            fromPosition: LudoPiece.home,
            toPosition: 0,
          ),
        ],
        phase: LudoTurnPhase.awaitingPieceSelection,
      );

      final result = engine.move(state, 0);

      expect(result.turnPassed, isFalse);
      expect(result.state.currentPlayerIndex, 0);
    });

    test('declares a winner once all 4 pieces are finished', () {
      const engine = LudoEngine(LudoDiceRules());
      var state = _freshState();

      state = state.copyWith(
        pieces: [
          for (final p in state.pieces)
            if (p.playerIndex == 0 && p.id != 0)
              p.copyWith(trackPosition: LudoPiece.finished)
            else if (p.id == 0)
              p.copyWith(trackPosition: 50)
            else
              p,
        ],
        diceValue: 6,
        legalMoves: const [
          LudoLegalMove(
            pieceId: 0,
            playerIndex: 0,
            fromPosition: 50,
            toPosition: 56,
          ),
        ],
        phase: LudoTurnPhase.awaitingPieceSelection,
      );

      final result = engine.move(state, 0);

      expect(result.playerWon, isTrue);
      expect(result.state.winners, contains(0));
    });

    test('ends the game and auto-places the last player once 3 have won',
        () {
      const engine = LudoEngine(LudoDiceRules());
      var state = _freshState();

      state = state.copyWith(
        pieces: [
          for (final p in state.pieces)
            if (p.playerIndex == 0 && p.id != 0)
              p.copyWith(trackPosition: LudoPiece.finished)
            else if (p.id == 0)
              p.copyWith(trackPosition: 50)
            else
              p,
        ],
        winners: const [1, 2], // players 1 and 2 already finished
        diceValue: 6,
        legalMoves: const [
          LudoLegalMove(
            pieceId: 0,
            playerIndex: 0,
            fromPosition: 50,
            toPosition: 56,
          ),
        ],
        phase: LudoTurnPhase.awaitingPieceSelection,
      );

      final result = engine.move(state, 0);

      expect(result.gameFinished, isTrue);
      // Player 0 finishes 3rd; player 3 is auto-placed last.
      expect(result.state.winners, [1, 2, 0, 3]);
      expect(result.state.phase, LudoTurnPhase.gameOver);
    });
  });
}