import 'package:flutter/material.dart';

/// Describes a single Ludo player.
///
/// Per the flutter_ludo specification, a player is intentionally a thin
/// model exposing only [name] and [color] — every rule and board-geometry
/// behaviour is fixed and handled internally by the engine, so there is
/// nothing else for a developer to configure here.
@immutable
class LudoPlayer {
  const LudoPlayer({required this.name, required this.color});

  /// Display name shown in the UI (e.g. in [LudoGame]'s status bar).
  final String name;

  /// Color used to render this player's pieces, home base, and home
  /// stretch.
  final Color color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LudoPlayer && other.name == name && other.color == color);

  @override
  int get hashCode => Object.hash(name, color);

  @override
  String toString() => 'LudoPlayer($name)';
}