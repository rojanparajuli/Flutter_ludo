import 'package:flutter/material.dart';
import 'package:flutter_ludo/model/ludo_game_state.dart';

import '../controller/ludo_controller.dart';

/// A simple dice control: shows the last rolled value and a button to roll.
/// The button disables itself while a piece selection is pending, or once
/// the game has finished.
class LudoDice extends StatelessWidget {
  const LudoDice({
    super.key, 
    required this.controller,
    this.showAudioToggle = true, // Add this
  });

  final LudoController controller;
  final bool showAudioToggle;

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
          // Dice display
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
              style: const TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Roll button
          ElevatedButton(
            onPressed: canRoll ? controller.rollDice : null,
            child: const Text('Roll'),
          ),
          
          // Optional audio toggle
          if (showAudioToggle) ...[
            const SizedBox(width: 12),
            _AudioToggleButton(controller: controller),
          ],
        ],
      ),
    );
  }
}

/// Audio toggle button widget
class _AudioToggleButton extends StatefulWidget {
  const _AudioToggleButton({required this.controller});

  final LudoController controller;

  @override
  State<_AudioToggleButton> createState() => _AudioToggleButtonState();
}

class _AudioToggleButtonState extends State<_AudioToggleButton> {
  bool _isAudioEnabled = true;

  @override
  void initState() {
    super.initState();
    // You would need to expose isAudioEnabled from controller
    // For now, we'll track it locally
    _isAudioEnabled = widget.controller.enableAudio; // Add this getter
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isAudioEnabled ? Icons.volume_up : Icons.volume_off,
        color: _isAudioEnabled ? Colors.blue : Colors.grey,
      ),
      onPressed: () {
        setState(() {
          _isAudioEnabled = !_isAudioEnabled;
          // Toggle audio in controller
          widget.controller.toggleAudio(_isAudioEnabled); // Add this method
        });
      },
      tooltip: _isAudioEnabled ? 'Disable sound' : 'Enable sound',
    );
  }
}