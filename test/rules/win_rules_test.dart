import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

void main() {
  test('hasPlayerWon is true only once all 4 pieces are finished', () {
    final allFinished = [
      for (var i = 0; i < 4; i++)
        LudoPiece(id: i, playerIndex: 0, trackPosition: LudoPiece.finished),
    ];
    expect(hasPlayerWon(allFinished, 0), isTrue);

    final notQuite = [
      ...allFinished.take(3),
      const LudoPiece(id: 3, playerIndex: 0, trackPosition: 40),
    ];
    expect(hasPlayerWon(notQuite, 0), isFalse);
  });

  test('isGameFinished once all-but-one player has won', () {
    expect(isGameFinished([0, 1], 4), isFalse);
    expect(isGameFinished([0, 1, 2], 4), isTrue);
  });
}