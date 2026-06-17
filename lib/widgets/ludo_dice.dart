import 'package:flutter/material.dart';
import 'package:flutter_ludo/model/ludo_game_state.dart';

import '../controller/ludo_controller.dart';

/// A simple dice control: shows the last rolled value and a button to roll.
/// The button disables itself while a piece selection is pending, or once
/// the game has finished.
class LudoDice extends StatelessWidget {
  const LudoDice({super.key, required this.controller});

  final LudoController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final canRoll =
        !state.isFinished && state.phase == LudoTurnPhase.awaitingRoll;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black54),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              state.diceValue?.toString() ?? '–',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: canRoll ? controller.rollDice : null,
            child: const Text('Roll'),
          ),
        ],
      ),
    );
  }
}