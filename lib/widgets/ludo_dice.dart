
import 'package:flutter/material.dart';

import '../controller/ludo_controller.dart';
import '../model/ludo_game_state.dart';

class LudoDice extends StatefulWidget {
  const LudoDice({
    super.key,
    required this.controller,
    this.showAudioToggle = true,
  });

  final LudoController controller;
  final bool showAudioToggle;

  @override
  State<LudoDice> createState() => _LudoDiceState();
}

class _LudoDiceState extends State<LudoDice>
    with SingleTickerProviderStateMixin {
  late AnimationController _shake;
  late Animation<double>   _dx;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _dx = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -5.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -3.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _roll() {
    if (widget.controller.isAnimating) return;
    _shake.forward(from: 0);
    widget.controller.rollDice();
  }

  @override
  Widget build(BuildContext context) {
    final state       = widget.controller.state;
    final canRoll     = !state.isFinished &&
                        state.phase == LudoTurnPhase.awaitingRoll &&
                        !widget.controller.isAnimating;
    final playerColor = state.isFinished
        ? Colors.grey.shade400
        : state.players[state.currentPlayerIndex].color;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dice face
          AnimatedBuilder(
            animation: _dx,
            builder: (_, child) =>
                Transform.translate(offset: Offset(_dx.value, 0), child: child),
            child: _DiceFace(value: state.diceValue, color: playerColor),
          ),

          const SizedBox(width: 20),

          // Roll / Moving button
          _RollButton(
            canRoll: canRoll,
            isAnimating: widget.controller.isAnimating,
            color: playerColor,
            onPressed: _roll,
          ),

          // // Audio toggle
          // if (widget.showAudioToggle) ...[
          //   const SizedBox(width: 10),
          //   // _AudioToggle(controller: widget.controller),
          // ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flat dice face with pip dots – no shadows, no gradients
// ─────────────────────────────────────────────────────────────────────────────

class _DiceFace extends StatelessWidget {
  const _DiceFace({required this.value, required this.color});

  final int?  value;
  final Color color;

  // Pip grid positions [row 0-2, col 0-2]
  static const Map<int, List<List<int>>> _pips = {
    1: [[1,1]],
    2: [[0,0],[2,2]],
    3: [[0,0],[1,1],[2,2]],
    4: [[0,0],[0,2],[2,0],[2,2]],
    5: [[0,0],[0,2],[1,1],[2,0],[2,2]],
    6: [[0,0],[0,2],[1,0],[1,2],[2,0],[2,2]],
  };

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: value != null ? color : Colors.grey.shade300,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: value == null
          ? Center(
              child: Text(
                '–',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : CustomPaint(
              painter: _PipPainter(
                pips: _pips[value!]!,
                color: color,
              ),
            ),
    );
  }
}

class _PipPainter extends CustomPainter {
  const _PipPainter({required this.pips, required this.color});

  final List<List<int>> pips;
  final Color           color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const pad   = 8.0;
    final step  = (size.width - pad * 2) / 2;
    final r     = size.width * 0.09;

    for (final pip in pips) {
      final cx = pad + pip[1] * step;
      final cy = pad + pip[0] * step;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_PipPainter old) =>
      old.pips != pips || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Roll button – flat style, no elevation
// ─────────────────────────────────────────────────────────────────────────────

class _RollButton extends StatelessWidget {
  const _RollButton({
    required this.canRoll,
    required this.isAnimating,
    required this.color,
    required this.onPressed,
  });

  final bool     canRoll;
  final bool     isAnimating;
  final Color    color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label  = isAnimating ? 'Moving…' : 'Roll';
    final active = canRoll;

    return GestureDetector(
      onTap: active ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: active ? color : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade500,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio toggle – icon button
// ─────────────────────────────────────────────────────────────────────────────

// class _AudioToggle extends StatefulWidget {
//   const _AudioToggle({required this.controller});
//   final LudoController controller;

//   @override
//   State<_AudioToggle> createState() => _AudioToggleState();
// }

// class _AudioToggleState extends State<_AudioToggle> {
//   late bool _on;

//   @override
//   void initState() {
//     super.initState();
//     _on = widget.controller.enableAudio;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return IconButton(
//       icon: Icon(_on ? Icons.volume_up : Icons.volume_off),
//       color: _on ? Colors.blueGrey : Colors.grey.shade400,
//       iconSize: 22,
//       tooltip: _on ? 'Mute' : 'Unmute',
//       onPressed: () {
//         setState(() => _on = !_on);
//         widget.controller.toggleAudio(_on);
//       },
//     );
//   }
// }