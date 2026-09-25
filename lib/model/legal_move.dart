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

  /// Number of cells this move advances the piece.
  int get steps => toPosition - fromPosition;

  /// Serializes this move for [LudoGameState.toJson].
  Map<String, Object?> toJson() => {
    'piece': pieceId,
    'player': playerIndex,
    'from': fromPosition,
    'to': toPosition,
  };

  /// Inverse of [toJson].
  factory LudoLegalMove.fromJson(Map<String, Object?> json) => LudoLegalMove(
    pieceId: json['piece']! as int,
    playerIndex: json['player']! as int,
    fromPosition: json['from']! as int,
    toPosition: json['to']! as int,
  );

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
  String toString() =>
      'LudoLegalMove(piece: $pieceId, '
      '$fromPosition -> $toPosition)';
}
