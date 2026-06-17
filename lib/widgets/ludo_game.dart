import 'package:flutter/material.dart';
import 'package:flutter_ludo/model/ludo_game_state.dart';

import '../controller/ludo_controller.dart';
import '../themes/ludo_theme.dart';
import 'ludo_board.dart';
import 'ludo_dice.dart';

/// Top-level widget that renders a full Ludo game: a turn/result status
/// bar, the board, and the dice control — all driven by [controller].
///
/// ```dart
/// LudoGame(
///   controller: LudoController(
///     players: players,
///     diceRules: const LudoDiceRules(
///       startAllowedValues: [6],
///       extraTurnValues: [6],
///     ),
///   ),
/// )
/// ```
///
/// [controller] is owned by the caller — create it in `initState` (or a
/// state-management layer of your choice) and dispose of it yourself.
class LudoGame extends StatelessWidget {
  const LudoGame({
    super.key,
    required this.controller,
    this.theme = LudoTheme.defaultTheme,
    this.showDice = true,
    this.showStatusBar = true,
  });

  final LudoController controller;
  final LudoTheme theme;

  /// Whether to show the built-in [LudoDice] control below the board.
  /// Set to `false` if you want to build your own dice UI and call
  /// [LudoController.rollDice] yourself.
  final bool showDice;

  /// Whether to show the built-in turn/result status bar above the board.
  final bool showStatusBar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showStatusBar) _StatusBar(state: state),
            Expanded(
              child: LudoBoard(controller: controller, theme: theme),
            ),
            if (showDice) LudoDice(controller: controller),
          ],
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state});

  final LudoGameState state;

  @override
  Widget build(BuildContext context) {
    final text = state.isFinished
        ? 'Game finished'
        : "${state.players[state.currentPlayerIndex].name}'s turn";
    final color = state.isFinished
        ? Colors.black87
        : state.players[state.currentPlayerIndex].color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
      ),
    );
  }
}