import 'dart:convert';

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
      expect(result.state.pieces.firstWhere((p) => p.id == 4).isHome, isTrue);
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

    test('ends the game and auto-places the last player once 3 have won', () {
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

  group('rule variants', () {
    LudoGameState withPieces(Map<int, int> positions) {
      final state = _freshState();
      return state.copyWith(
        pieces: [
          for (final p in state.pieces)
            p.copyWith(trackPosition: positions[p.id] ?? p.trackPosition),
        ],
      );
    }

    LudoEngineMoveResult rollAndMove(
      LudoEngine engine,
      LudoGameState state,
      int dice,
      int pieceId,
    ) {
      final rolled = engine.roll(state, dice).state;
      return engine.move(rolled, pieceId);
    }

    test('extraTurnOnCapture grants another roll after a capture', () {
      // Piece 0 at 10 captures player 1's piece at global 14 with a 4.
      final state = withPieces({0: 10, 4: 1});
      final classic = rollAndMove(
        const LudoEngine(LudoDiceRules()),
        state,
        4,
        0,
      );
      expect(classic.capturedPieces, hasLength(1));
      expect(classic.extraTurn, isFalse);
      expect(classic.state.currentPlayerIndex, 1);

      final modern = rollAndMove(
        const LudoEngine(LudoDiceRules(extraTurnOnCapture: true)),
        state,
        4,
        0,
      );
      expect(modern.extraTurn, isTrue);
      expect(modern.state.currentPlayerIndex, 0);
    });

    test('extraTurnOnFinish grants another roll after finishing a piece', () {
      final state = withPieces({0: 53});
      const engine = LudoEngine(LudoDiceRules(extraTurnOnFinish: true));
      final result = rollAndMove(engine, state, 3, 0);
      expect(result.movedPiece.isFinished, isTrue);
      expect(result.state.currentPlayerIndex, 0);
    });

    test('forfeitStreak passes the turn on the Nth consecutive 6', () {
      const engine = LudoEngine(LudoDiceRules(forfeitStreak: 3));
      var state = withPieces({0: 0});
      for (var i = 0; i < 2; i++) {
        state = engine.move(engine.roll(state, 6).state, 0).state;
        expect(state.currentPlayerIndex, 0);
      }
      expect(state.rollStreak, 2);

      final third = engine.roll(state, 6);
      expect(third.forfeited, isTrue);
      expect(third.passed, isTrue);
      expect(third.state.currentPlayerIndex, 1);
      expect(third.state.rollStreak, 0);
      expect(third.state.lastRoll, 6);
    });

    test('a non-6 roll resets the streak', () {
      const engine = LudoEngine(LudoDiceRules(forfeitStreak: 2));
      var state = withPieces({0: 0});
      state = engine.move(engine.roll(state, 6).state, 0).state;
      expect(state.rollStreak, 1);
      state = engine.roll(state, 3).state;
      expect(state.rollStreak, 0);
    });

    test('a player who just finished never gets an extra turn', () {
      // Player 0 has three pieces home; the last one finishes with a 6.
      final state = withPieces({0: 56, 1: 56, 2: 56, 3: 50});
      final result = rollAndMove(
        const LudoEngine(LudoDiceRules()),
        state,
        6,
        3,
      );
      expect(result.playerWon, isTrue);
      expect(result.extraTurn, isFalse);
      expect(result.state.currentPlayerIndex, 1);
    });

    test('rolling in the wrong phase or out of range throws', () {
      const engine = LudoEngine(LudoDiceRules());
      final rolled = engine.roll(_freshState(), 6).state;
      expect(() => engine.roll(rolled, 6), throwsStateError);
      expect(() => engine.roll(_freshState(), 0), throwsRangeError);
      expect(() => engine.move(_freshState(), 0), throwsStateError);
      expect(() => engine.move(rolled, 99), throwsArgumentError);
    });
  });

  group('LudoGameState JSON', () {
    test('round-trips every field', () {
      const engine = LudoEngine(LudoDiceRules());
      final state = engine
          .roll(_freshState().copyWith(teams: kDefaultTeams), 6)
          .state
          .copyWith(
            winners: [2],
            lastMovedPiece: const LudoPiece(id: 5, playerIndex: 1),
          );

      final json =
          jsonDecode(jsonEncode(state.toJson())) as Map<String, Object?>;
      final back = LudoGameState.fromJson(json);

      expect(back.players, state.players);
      expect(back.pieces, state.pieces);
      expect(back.currentPlayerIndex, state.currentPlayerIndex);
      expect(back.phase, state.phase);
      expect(back.diceValue, state.diceValue);
      expect(back.legalMoves, state.legalMoves);
      expect(back.winners, state.winners);
      expect(back.teams, state.teams);
      expect(back.lastRoll, state.lastRoll);
      expect(back.lastRollPlayerIndex, state.lastRollPlayerIndex);
      expect(back.rollStreak, state.rollStreak);
      expect(back.rollCount, state.rollCount);
      expect(back.lastMovedPiece?.id, 5);
    });
  });
}
