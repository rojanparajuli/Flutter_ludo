import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

void main() {
  group('resolvePieceState', () {
    test('home piece', () {
      const piece = LudoPiece(id: 0, playerIndex: 0);
      expect(resolvePieceState(piece), LudoPieceState.home);
    });

    test('finished piece', () {
      const piece =
          LudoPiece(id: 0, playerIndex: 0, trackPosition: LudoPiece.finished);
      expect(resolvePieceState(piece), LudoPieceState.finished);
    });

    test('piece in its own home stretch is always safe', () {
      const piece = LudoPiece(id: 0, playerIndex: 0, trackPosition: 52);
      expect(resolvePieceState(piece), LudoPieceState.safe);
    });

    test('piece on a star/safe cell is safe', () {
      // Player 0's start cell (trackPosition 0) is global index 0, which is
      // a designated safe cell.
      const piece = LudoPiece(id: 0, playerIndex: 0, trackPosition: 0);
      expect(resolvePieceState(piece), LudoPieceState.safe);
    });

    test('piece on an ordinary shared-path cell is active', () {
      const piece = LudoPiece(id: 0, playerIndex: 0, trackPosition: 5);
      expect(resolvePieceState(piece), LudoPieceState.active);
    });
  });
}