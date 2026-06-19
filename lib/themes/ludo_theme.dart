import 'package:flutter/material.dart';

/// Visual styling for [LudoBoard] / [LudoGame].
///
/// Game rules and board geometry are fixed by the package specification —
/// only appearance is themeable.
@immutable
class LudoTheme {
  const LudoTheme({
    this.boardBackgroundColor = const Color(0xFFF5F1E8),
    this.pathCellColor = const Color(0xFFFFFFFF),
    this.safeCellColor = const Color(0xFFE8E2D0),
    this.gridLineColor = const Color(0xFFBDBDBD),
    this.centerCellColor = const Color(0xFFFFFFFF),
    this.starIconColor = const Color(0xFF6B6B6B),
    this.homeBorderColor = const Color(0xFF666666),
    this.homePartitionColor = const Color(0xFF888888),
    this.movementTrailColor = const Color(0x40FFFFFF),
  });

  /// Color filling the area outside the playable cells.
  final Color boardBackgroundColor;

  /// Fill color for ordinary (non-safe) shared-path cells.
  final Color pathCellColor;

  /// Fill color for designated safe ("star") cells.
  final Color safeCellColor;

  /// Color of every cell border / grid line.
  final Color gridLineColor;

  /// Fill color for the 3x3 center square, behind the 4 colored home
  /// triangles.
  final Color centerCellColor;

  /// Color of the star icon drawn on each safe cell.
  final Color starIconColor;

  /// Color for home base borders
  final Color homeBorderColor;

  /// Color for home base partitions
  final Color homePartitionColor;

  /// Color for movement trail effect
  final Color movementTrailColor;

  static const LudoTheme defaultTheme = LudoTheme();

  LudoTheme copyWith({
    Color? boardBackgroundColor,
    Color? pathCellColor,
    Color? safeCellColor,
    Color? gridLineColor,
    Color? centerCellColor,
    Color? starIconColor,
    Color? homeBorderColor,
    Color? homePartitionColor,
    Color? movementTrailColor,
  }) {
    return LudoTheme(
      boardBackgroundColor: boardBackgroundColor ?? this.boardBackgroundColor,
      pathCellColor: pathCellColor ?? this.pathCellColor,
      safeCellColor: safeCellColor ?? this.safeCellColor,
      gridLineColor: gridLineColor ?? this.gridLineColor,
      centerCellColor: centerCellColor ?? this.centerCellColor,
      starIconColor: starIconColor ?? this.starIconColor,
      homeBorderColor: homeBorderColor ?? this.homeBorderColor,
      homePartitionColor: homePartitionColor ?? this.homePartitionColor,
      movementTrailColor: movementTrailColor ?? this.movementTrailColor,
    );
  }
}
