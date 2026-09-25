import 'package:flutter/material.dart';

/// Visual styling for [LudoBoard], [LudoDice], and [LudoGame].
///
/// Game rules and board geometry are fixed by the package specification —
/// only appearance is themeable. Use [LudoTheme.defaultTheme] or
/// [LudoTheme.dark], or tweak either with [copyWith].
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
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.panelColor = const Color(0xFFFFFFFF),
    this.textColor = const Color(0xFF212121),
    this.mutedTextColor = const Color(0xFF9E9E9E),
    this.dividerColor = const Color(0xFFE0E0E0),
    this.lastMovedColor = const Color(0xFFFFB300),
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

  /// Background of the [LudoGame] screen.
  final Color backgroundColor;

  /// Background of the dice bar, cards, and dialogs.
  final Color panelColor;

  /// Primary text color for status and dialogs.
  final Color textColor;

  /// Secondary text and inactive icon color.
  final Color mutedTextColor;

  /// Borders of inactive chips, buttons, and panels.
  final Color dividerColor;

  /// Ring drawn around the most recently moved piece.
  final Color lastMovedColor;

  static const LudoTheme defaultTheme = LudoTheme();

  /// A dark variant suited to dark-mode apps.
  static const LudoTheme dark = LudoTheme(
    boardBackgroundColor: Color(0xFF1E1E24),
    pathCellColor: Color(0xFF2C2C34),
    safeCellColor: Color(0xFF3A3A44),
    gridLineColor: Color(0xFF4A4A55),
    centerCellColor: Color(0xFF2C2C34),
    starIconColor: Color(0xFFBDBDBD),
    homeBorderColor: Color(0xFF9E9E9E),
    homePartitionColor: Color(0xFF757575),
    movementTrailColor: Color(0x40000000),
    backgroundColor: Color(0xFF121216),
    panelColor: Color(0xFF1E1E24),
    textColor: Color(0xFFF1F1F1),
    mutedTextColor: Color(0xFF8A8A94),
    dividerColor: Color(0xFF3A3A44),
    lastMovedColor: Color(0xFFFFCA28),
  );

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
    Color? backgroundColor,
    Color? panelColor,
    Color? textColor,
    Color? mutedTextColor,
    Color? dividerColor,
    Color? lastMovedColor,
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
      backgroundColor: backgroundColor ?? this.backgroundColor,
      panelColor: panelColor ?? this.panelColor,
      textColor: textColor ?? this.textColor,
      mutedTextColor: mutedTextColor ?? this.mutedTextColor,
      dividerColor: dividerColor ?? this.dividerColor,
      lastMovedColor: lastMovedColor ?? this.lastMovedColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LudoTheme &&
          other.boardBackgroundColor == boardBackgroundColor &&
          other.pathCellColor == pathCellColor &&
          other.safeCellColor == safeCellColor &&
          other.gridLineColor == gridLineColor &&
          other.centerCellColor == centerCellColor &&
          other.starIconColor == starIconColor &&
          other.homeBorderColor == homeBorderColor &&
          other.homePartitionColor == homePartitionColor &&
          other.movementTrailColor == movementTrailColor &&
          other.backgroundColor == backgroundColor &&
          other.panelColor == panelColor &&
          other.textColor == textColor &&
          other.mutedTextColor == mutedTextColor &&
          other.dividerColor == dividerColor &&
          other.lastMovedColor == lastMovedColor);

  @override
  int get hashCode => Object.hash(
    boardBackgroundColor,
    pathCellColor,
    safeCellColor,
    gridLineColor,
    centerCellColor,
    starIconColor,
    homeBorderColor,
    homePartitionColor,
    movementTrailColor,
    backgroundColor,
    panelColor,
    textColor,
    mutedTextColor,
    dividerColor,
    lastMovedColor,
  );
}
