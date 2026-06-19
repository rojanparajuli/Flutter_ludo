import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ludo/model/ludo_piece.dart';



/// Drives a single piece through its path one cell at a time, firing
/// [onStepComplete] after every cell so the controller can update
/// [LudoGameState] and the board repaints at the right intermediate
/// position.
///
/// Usage:
/// ```dart
/// final animator = PieceAnimator();
/// await animator.animate(
///   piece: piece,
///   steps: diceValue,
///   cell: cellSize,
///   color: playerColor,
///   onStepComplete: (intermediatePosition) {
///     setState(() => piece = piece.copyWith(trackPosition: intermediatePosition));
///   },
/// );
/// ```
class PieceStepAnimator {
  PieceStepAnimator({this.stepDurationMs = 180});

  /// Duration of each individual step in milliseconds.
  final int stepDurationMs;

  bool _cancelled = false;

  /// Animates [piece] forward by [steps] cells, invoking [onStep] after
  /// each cell lands. Awaiting this future means all steps are complete.
  ///
  /// [onStep] receives the new trackPosition after each step.
  Future<void> animate({
    required LudoPiece piece,
    required int steps,
    required void Function(int newTrackPosition) onStep,
  }) async {
    _cancelled = false;
    int current = piece.trackPosition;

    for (var i = 0; i < steps; i++) {
      if (_cancelled) break;
      current++;
      onStep(current);
      await Future.delayed(Duration(milliseconds: stepDurationMs));
    }
  }

  /// Cancel a running animation early (e.g. on widget dispose).
  void cancel() => _cancelled = true;
}

// ──────────────────────────────────────────────────────────────────
// Animated piece widget – bounces slightly on each step
// ──────────────────────────────────────────────────────────────────

/// An animated version of a Ludo piece that bounces as it moves.
/// Wrap your existing piece positioning in this and drive it by
/// updating [currentPosition] each step.
class AnimatedLudoPiece extends StatefulWidget {
  const AnimatedLudoPiece({
    super.key,
    required this.center,
    required this.radius,
    required this.color,
    required this.isLegal,
    required this.isLastMoved,
    required this.isInStack,
    required this.isTopOfStack,
    required this.stackOffset,
    required this.pieceNumber,
    this.onTap,
  });

  final Offset center;
  final double radius;
  final Color color;
  final bool isLegal;
  final bool isLastMoved;
  final bool isInStack;
  final bool isTopOfStack;
  final Offset stackOffset;
  final int pieceNumber;
  final VoidCallback? onTap;

  @override
  State<AnimatedLudoPiece> createState() => _AnimatedLudoPieceState();
}

class _AnimatedLudoPieceState extends State<AnimatedLudoPiece>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounce;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(AnimatedLudoPiece oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger bounce when piece moves to a new center
    if (oldWidget.center != widget.center) {
      _bounce.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.center.dx - widget.radius + widget.stackOffset.dx;
    final top  = widget.center.dy - widget.radius + widget.stackOffset.dy;
    final size = widget.radius * 2;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      left: left,
      top: top,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: widget.isLegal ? widget.onTap : null,
        behavior: widget.isLegal
            ? HitTestBehavior.opaque
            : HitTestBehavior.translucent,
        child: ScaleTransition(
          scale: _scale,
          child: _PieceBody(
            radius: widget.radius,
            color: widget.color,
            isLegal: widget.isLegal,
            isLastMoved: widget.isLastMoved,
            isInStack: widget.isInStack,
            isTopOfStack: widget.isTopOfStack,
            pieceNumber: widget.pieceNumber,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Pure visual piece body (no positioning, no gesture)
// ──────────────────────────────────────────────────────────────────

class _PieceBody extends StatelessWidget {
  const _PieceBody({
    required this.radius,
    required this.color,
    required this.isLegal,
    required this.isLastMoved,
    required this.isInStack,
    required this.isTopOfStack,
    required this.pieceNumber,
  });

  final double radius;
  final Color color;
  final bool isLegal;
  final bool isLastMoved;
  final bool isInStack;
  final bool isTopOfStack;
  final int pieceNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Outer ring colour is the player colour
        color: color,
        border: Border.all(
          color: _borderColor,
          width: _borderWidth,
        ),
        boxShadow: _shadow,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner white disc with coloured centre dot – "classic" Ludo look
          FractionallySizedBox(
            widthFactor: 0.65,
            heightFactor: 0.65,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: color.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: radius * 0.38,
                  height: radius * 0.38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ),
            ),
          ),

          // Stack indicator dot (bottom-right)
          if (isInStack)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: isTopOfStack
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26, width: 0.5),
                ),
              ),
            ),

          // Legal-move pulse ring
          if (isLegal)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 2.5,
                  ),
                ),
              ),
            ),

          // Last-moved golden ring
          if (isLastMoved)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber, width: 3.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color get _borderColor {
    if (isLastMoved) return Colors.amber;
    if (isLegal)     return Colors.white;
    if (isInStack && isTopOfStack) return Colors.white70;
    if (isInStack)   return Colors.white38;
    return Colors.black38;
  }

  double get _borderWidth {
    if (isLastMoved) return 3.5;
    if (isLegal)     return 3.0;
    if (isInStack && isTopOfStack) return 2.0;
    if (isInStack)   return 1.5;
    return 1.5;
  }

  List<BoxShadow> get _shadow {
    if (isLastMoved) {
      return [
        BoxShadow(color: Colors.amber.withValues(alpha: 0.55), blurRadius: 14, spreadRadius: 5),
        BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 2),
      ];
    }
    if (isLegal) {
      return [
        BoxShadow(color: color.withValues(alpha: 0.65), blurRadius: 8, spreadRadius: 3),
      ];
    }
    return [
      const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
    ];
  }
}