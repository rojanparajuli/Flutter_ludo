import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

List<LudoPiece> _pieces(Map<int, int> positions, {int players = 4}) => [
  for (var p = 0; p < players; p++)
    for (var i = 0; i < 4; i++)
      LudoPiece(
        id: p * 4 + i,
        playerIndex: p,
        trackPosition: positions[p * 4 + i] ?? LudoPiece.home,
      ),
];

Map<int, int> _finished(Iterable<int> playerIndices) => {
  for (final p in playerIndices)
    for (var i = 0; i < 4; i++) p * 4 + i: LudoPiece.finished,
};

void main() {
  group('hasPlayerWon', () {
    test('is false until all four pieces are finished', () {
      final almost = _finished([0])..[3] = 50;
      expect(hasPlayerWon(_pieces(almost), 0), isFalse);
      expect(hasPlayerWon(_pieces(_finished([0])), 0), isTrue);
    });

    test('ignores other players', () {
      expect(hasPlayerWon(_pieces(_finished([1])), 0), isFalse);
    });
  });

  group('hasTeamWon', () {
    const team = LudoTeam(name: 'A', playerIndices: [0, 3]);

    test('requires both teammates to finish', () {
      expect(hasTeamWon(_pieces(_finished([0])), team), isFalse);
      expect(hasTeamWon(_pieces(_finished([0, 3])), team), isTrue);
    });
  });

  group('isGameFinished', () {
    test('standard mode ends when all but one player have won', () {
      expect(isGameFinished(2, 4), isFalse);
      expect(isGameFinished(3, 4), isTrue);
      expect(isGameFinished(1, 2), isTrue);
    });

    test('teams mode ends when one team has finished', () {
      expect(
        isGameFinished(
          1,
          4,
          teams: kDefaultTeams,
          pieces: _pieces(_finished([0])),
        ),
        isFalse,
      );
      expect(
        isGameFinished(
          2,
          4,
          teams: kDefaultTeams,
          pieces: _pieces(_finished([1, 2])),
        ),
        isTrue,
      );
    });
  });
}
