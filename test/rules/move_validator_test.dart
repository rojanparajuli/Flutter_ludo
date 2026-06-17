import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

List<LudoPlayer> _players() => const [
      LudoPlayer(name: 'A', color: Colors.red),
      LudoPlayer(name: 'B', color: Colors.green),
      LudoPlayer(name: 'C', color: Colors.yellow),
      LudoPlayer(name: 'D', color: Colors.blue),
    ];

List<LudoPiece> _pieces(List<LudoPlayer> players) => [
      for (var p = 0; p < players.length; p++)
        for (var i = 0; i < 4; i++) LudoPiece(id: p * 4 + i, playerIndex: p),
    ];

void main() {
  group('computeLegalMoves', () {
    test('home pieces can only start when the dice allows it', () {
      final players = _players();
      final state = LudoGameState(
        players: players,
        pieces: _pieces(players),
        currentPlayerIndex: 0,
        phase: LudoTurnPhase.awaitingRoll,
      );
      const rules = LudoDiceRules(startAllowedValues: [6]);

      expect(computeLegalMoves(state, rules, 3), isEmpty);

      final moves = computeLegalMoves(state, rules, 6);
      expect(moves.length, 4);
      expect(moves.every((m) => m.fromPosition == LudoPiece.home), isTrue);
      expect(moves.every((m) => m.toPosition == 0), isTrue);
    });

    test('a piece already on the board can move without the start rule', () {
      final players = _players();
      final pieces = [
        for (final piece in _pieces(players))
          piece.id == 0 ? piece.copyWith(trackPosition: 10) : piece,
      ];
      final state = LudoGameState(
        players: players,
        pieces: pieces,
        currentPlayerIndex: 0,
        phase: LudoTurnPhase.awaitingRoll,
      );

      final moves = computeLegalMoves(state, const LudoDiceRules(), 3);
      final moveForPieceZero = moves.firstWhere((m) => m.pieceId == 0);
      expect(moveForPieceZero.fromPosition, 10);
      expect(moveForPieceZero.toPosition, 13);
    });

    test('a move that would overshoot the final cell is illegal', () {
      final players = _players();
      final pieces = [
        for (final piece in _pieces(players))
          piece.id == 0 ? piece.copyWith(trackPosition: 53) : piece,
      ];
      final state = LudoGameState(
        players: players,
        pieces: pieces,
        currentPlayerIndex: 0,
        phase: LudoTurnPhase.awaitingRoll,
      );
      const rules = LudoDiceRules();

      // 53 + 6 = 59, past the final cell (56) -> illegal.
      expect(
        computeLegalMoves(state, rules, 6).where((m) => m.pieceId == 0),
        isEmpty,
      );

      // 53 + 3 = 56 exactly -> legal, and finishes the piece.
      final ok = computeLegalMoves(state, rules, 3);
      expect(ok.firstWhere((m) => m.pieceId == 0).toPosition, 56);
    });

    test('finished pieces never produce a move', () {
      final players = _players();
      final pieces = [
        for (final piece in _pieces(players))
          piece.id == 0
              ? piece.copyWith(trackPosition: LudoPiece.finished)
              : piece,
      ];
      final state = LudoGameState(
        players: players,
        pieces: pieces,
        currentPlayerIndex: 0,
        phase: LudoTurnPhase.awaitingRoll,
      );

      final moves = computeLegalMoves(state, const LudoDiceRules(), 6);
      expect(moves.where((m) => m.pieceId == 0), isEmpty);
    });

    test('only the current player\'s pieces are ever considered', () {
      final players = _players();
      final state = LudoGameState(
        players: players,
        pieces: _pieces(players),
        currentPlayerIndex: 1,
        phase: LudoTurnPhase.awaitingRoll,
      );

      final moves = computeLegalMoves(state, const LudoDiceRules(), 6);
      expect(moves, isNotEmpty);
      expect(moves.every((m) => m.playerIndex == 1), isTrue);
    });
  });
}