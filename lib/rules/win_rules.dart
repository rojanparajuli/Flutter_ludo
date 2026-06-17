
import 'package:flutter_ludo/model/ludo_piece.dart';

/// Whether [playerIndex] has won: all four of their pieces have reached the
/// final home cell.
bool hasPlayerWon(List<LudoPiece> pieces, int playerIndex) {
  final own = pieces.where((p) => p.playerIndex == playerIndex);
  return own.isNotEmpty && own.every((p) => p.isFinished);
}

/// Whether the overall game is finished.
///
/// Once all but one player has won, the game is over and the remaining
/// player is automatically placed last — the standard Ludo convention,
/// since with only one player left there is nothing left to contest.
bool isGameFinished(List<int> winners, int totalPlayers) =>
    winners.length >= totalPlayers - 1;