import 'package:flutter/foundation.dart';

/// A single playing piece.
///
/// [trackPosition] encodes where the piece sits using one relative integer,
/// relative to its own player's start cell:
///
/// * `-1` ([home])             : sitting at home, not yet on the board.
/// * `0` .. `50`                : on the 51-cell shared section of the
///   path (see [isOnSharedPath]).
/// * `51` .. `55`               : on the player's own 5-cell colored home
///   stretch (see [isOnHomeStretch]).
/// * `56` ([finished])          : reached the final home cell.
@immutable
class LudoPiece {
  const LudoPiece({
    required this.id,
    required this.playerIndex,
    this.trackPosition = home,
  });

  /// Position constant meaning "sitting in the home base".
  static const int home = -1;

  /// Position constant meaning "finished" (reached the center).
  static const int finished = 56;

  /// Number of relative positions (`0..50`, 51 cells) on the shared,
  /// 52-cell board loop before a piece turns into its own colored home
  /// stretch.
  static const int sharedPathSpan = 51;

  /// Unique id of this piece. By convention, ids are assigned as
  /// `playerIndex * 4 + localIndex` (localIndex `0..3`), which is what
  /// [LudoController] does internally.
  final int id;

  /// Index (`0..3`) of the owning player.
  final int playerIndex;

  /// See the class doc for the full encoding.
  final int trackPosition;

  bool get isHome => trackPosition == home;

  bool get isFinished => trackPosition == finished;

  bool get isOnSharedPath =>
      trackPosition >= 0 && trackPosition < sharedPathSpan;

  bool get isOnHomeStretch =>
      trackPosition >= sharedPathSpan && trackPosition < finished;

  LudoPiece copyWith({int? trackPosition}) => LudoPiece(
        id: id,
        playerIndex: playerIndex,
        trackPosition: trackPosition ?? this.trackPosition,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LudoPiece &&
          other.id == id &&
          other.playerIndex == playerIndex &&
          other.trackPosition == trackPosition);

  @override
  int get hashCode => Object.hash(id, playerIndex, trackPosition);

  @override
  String toString() =>
      'LudoPiece(player: $playerIndex, id: $id, pos: $trackPosition)';
}