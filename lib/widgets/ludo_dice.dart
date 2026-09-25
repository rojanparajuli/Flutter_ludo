import 'package:flutter/material.dart';

import '../controller/ludo_controller.dart';
import '../model/ludo_game_state.dart';
import '../themes/ludo_theme.dart';

/// Dice face plus a roll button, bound to a [LudoController].
///
/// Rebuilds automatically, shakes on every roll (human or bot), keeps
/// showing the last value after the turn passes, and disables itself while
/// a bot is playing, a piece is moving, or the game is paused. Tapping the
/// die itself also rolls.
class LudoDice extends StatefulWidget {
  const LudoDice({
    super.key,
    required this.controller,
    this.theme = LudoTheme.defaultTheme,
    @Deprecated('Audio was removed in 0.1.0. This flag has no effect.')
    this.showAudioToggle = false,
  });

  final LudoController controller;
  final LudoTheme theme;
  final bool showAudioToggle;

  @override
  State<LudoDice> createState() => _LudoDiceState();
}

class _LudoDiceState extends State<LudoDice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;
  late final Animation<double> _dx;
  late int _seenRollCount;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _dx = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -5.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -3.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeInOut));
    _seenRollCount = widget.controller.state.rollCount;
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(LudoDice old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _seenRollCount = widget.controller.state.rollCount;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _shake.dispose();
    super.dispose();
  }

  void _onChanged() {
    final count = widget.controller.state.rollCount;
    if (count != _seenRollCount) {
      _seenRollCount = count;
      _shake.forward(from: 0);
    }
    setState(() {});
  }

  void _roll() {
    if (widget.controller.canRoll) widget.controller.rollDice();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final theme = widget.theme;
    final state = ctrl.state;
    final canRoll = ctrl.canRoll && !state.isFinished;

    final activeColor = state.isFinished
        ? theme.mutedTextColor
        : state.players[state.currentPlayerIndex].color;

    // Show the pending roll, or the most recent one in its roller's color.
    final shownValue = state.diceValue ?? state.lastRoll;
    final rollerIndex = state.diceValue != null
        ? state.currentPlayerIndex
        : state.lastRollPlayerIndex;
    final faceColor = rollerIndex != null && rollerIndex < state.players.length
        ? state.players[rollerIndex].color
        : theme.mutedTextColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.panelColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: shownValue == null ? 'Dice' : 'Dice showing $shownValue',
            child: GestureDetector(
              onTap: canRoll ? _roll : null,
              child: AnimatedBuilder(
                animation: _dx,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_dx.value, 0),
                  child: child,
                ),
                child: LudoDiceFace(
                  value: shownValue,
                  color: faceColor,
                  dimmed: state.diceValue == null,
                  backgroundColor: theme.panelColor,
                  emptyColor: theme.dividerColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          _RollButton(
            label: _label(ctrl, state),
            enabled: canRoll,
            color: activeColor,
            theme: theme,
            onTap: _roll,
          ),
        ],
      ),
    );
  }

  String _label(LudoController ctrl, LudoGameState state) {
    if (state.isFinished) return 'Game over';
    if (ctrl.isPaused) return 'Paused';
    if (ctrl.isAnimating) return 'Moving…';
    if (ctrl.isCurrentPlayerBot) return 'Bot thinking…';
    if (state.phase == LudoTurnPhase.awaitingPieceSelection) {
      return 'Pick a piece';
    }
    return 'Roll';
  }
}

/// A flat die face with pips. Shows a dash when [value] is `null`.
class LudoDiceFace extends StatelessWidget {
  const LudoDiceFace({
    super.key,
    required this.value,
    required this.color,
    this.size = 52,
    this.dimmed = false,
    this.backgroundColor = Colors.white,
    this.emptyColor = const Color(0xFFE0E0E0),
  }) : assert(value == null || (value >= 1 && value <= 6));

  final int? value;
  final Color color;
  final double size;

  /// Draws the face at reduced opacity, e.g. for a roll from a previous
  /// turn.
  final bool dimmed;
  final Color backgroundColor;
  final Color emptyColor;

  // Pip grid positions [row 0-2, col 0-2]
  static const Map<int, List<List<int>>> _pips = {
    1: [
      [1, 1],
    ],
    2: [
      [0, 0],
      [2, 2],
    ],
    3: [
      [0, 0],
      [1, 1],
      [2, 2],
    ],
    4: [
      [0, 0],
      [0, 2],
      [2, 0],
      [2, 2],
    ],
    5: [
      [0, 0],
      [0, 2],
      [1, 1],
      [2, 0],
      [2, 2],
    ],
    6: [
      [0, 0],
      [0, 2],
      [1, 0],
      [1, 2],
      [2, 0],
      [2, 2],
    ],
  };

  @override
  Widget build(BuildContext context) {
    final c = dimmed ? color.withValues(alpha: 0.45) : color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: value != null ? c : emptyColor, width: 2.0),
        borderRadius: BorderRadius.circular(size * 0.16),
      ),
      child: value == null
          ? Center(
              child: Text(
                '–',
                style: TextStyle(
                  fontSize: size * 0.38,
                  color: emptyColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : CustomPaint(
              painter: _PipPainter(pips: _pips[value!]!, color: c),
            ),
    );
  }
}

class _PipPainter extends CustomPainter {
  const _PipPainter({required this.pips, required this.color});

  final List<List<int>> pips;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final pad = size.width * 0.16;
    final step = (size.width - pad * 2) / 2;
    final r = size.width * 0.09;

    for (final pip in pips) {
      canvas.drawCircle(
        Offset(pad + pip[1] * step, pad + pip[0] * step),
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PipPainter old) => old.pips != pips || old.color != color;
}

class _RollButton extends StatelessWidget {
  const _RollButton({
    required this.label,
    required this.enabled,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final Color color;
  final LudoTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled ? 'Roll dice' : label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? color : theme.dividerColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: enabled ? color : theme.dividerColor),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: enabled ? Colors.white : theme.mutedTextColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
