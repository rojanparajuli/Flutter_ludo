import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

void main() {
  group('captureOpponents', () {
    test('captures an opponent piece sharing the same global cell', () {
      // Player 1 starts at global index 13; trackPosition 2 -> global cell
      // 15, which is NOT a safe cell.
      final opponent =
          const LudoPiece(id: 4, playerIndex: 1, trackPosition: 2);
      // Player 0 starts at global index 0; trackPosition 15 -> global
      // cell 15 too, landing exactly on the opponent.
      const mover = LudoPiece(id: 0, playerIndex: 0, trackPosition: 15);

      final captured =
          captureOpponents(pieces: [mover, opponent], mover: mover);

      expect(captured, [opponent]);
    });

    test('never captures on a safe cell', () {
      // Player 1's start cell (trackPosition 0) is global index 13, a
      // designated safe cell.
      final opponentOnStart =
          const LudoPiece(id: 4, playerIndex: 1, trackPosition: 0);
      // Player 0 landing on global cell 13 -> trackPosition 13.
      const mover = LudoPiece(id: 0, playerIndex: 0, trackPosition: 13);

      final captured =
          captureOpponents(pieces: [mover, opponentOnStart], mover: mover);

      expect(captured, isEmpty);
    });

    test('never captures a piece belonging to the same player', () {
      const ownPiece = LudoPiece(id: 1, playerIndex: 0, trackPosition: 15);
      const mover = LudoPiece(id: 0, playerIndex: 0, trackPosition: 15);

      final captured =
          captureOpponents(pieces: [mover, ownPiece], mover: mover);

      expect(captured, isEmpty);
    });

    test('pieces in a home stretch can never be captured', () {
      const mover = LudoPiece(id: 0, playerIndex: 0, trackPosition: 52);
      final captured = captureOpponents(pieces: [mover], mover: mover);
      expect(captured, isEmpty);
    });
  });
}