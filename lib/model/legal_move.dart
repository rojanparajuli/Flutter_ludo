import 'package:flutter/foundation.dart';

/// A single legal move available to the current player for the value that
/// was just rolled. See [LudoGameState.legalMoves].
@immutable
class LudoLegalMove {
  const LudoLegalMove({
    required this.pieceId,
    required this.playerIndex,
    required this.fromPosition,
    required this.toPosition,
  });

  final int pieceId;
  final int playerIndex;
  final int fromPosition;
  final int toPosition;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LudoLegalMove &&
          other.pieceId == pieceId &&
          other.playerIndex == playerIndex &&
          other.fromPosition == fromPosition &&
          other.toPosition == toPosition);

  @override
  int get hashCode =>
      Object.hash(pieceId, playerIndex, fromPosition, toPosition);

  @override
  String toString() => 'LudoLegalMove(piece: $pieceId, '
      '$fromPosition -> $toPosition)';
}