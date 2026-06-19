import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constant/board_constants.dart';
import '../controller/ludo_controller.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_piece.dart';
import '../model/ludo_player.dart';
import '../themes/ludo_theme.dart';

class LudoBoard extends StatelessWidget {
  const LudoBoard({
    super.key,
    required this.controller,
    this.theme = LudoTheme.defaultTheme,
  });

  final LudoController controller;
  final LudoTheme theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide.isFinite
            ? constraints.biggest.shortestSide
            : 360.0;
        final cell = size / kBoardGridSize;
        final state = controller.state;
        final legalIds = state.legalMoves.map((m) => m.pieceId).toSet();

        final visiblePieces = _mergeAnimating(
          state.pieces,
          controller.animatingPiece,
        );

        // Z-order: current player's pieces always on top
        final currentIdx = state.currentPlayerIndex;
        final sorted = [
          ...visiblePieces.where((p) => p.playerIndex != currentIdx),
          ...visiblePieces.where((p) => p.playerIndex == currentIdx),
        ];

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              // Board
              CustomPaint(
                size: Size(size, size),
                painter: _BoardPainter(theme: theme, players: state.players),
              ),
              // Pieces
              for (final piece in sorted)
                _FlatPiece(
                  key: ValueKey(piece.id),
                  piece: piece,
                  cell: cell,
                  color: state.players[piece.playerIndex].color,
                  isLegal: legalIds.contains(piece.id),
                  isLastMoved:
                      state.lastMovedPiece?.id == piece.id &&
                      controller.animatingPiece == null,
                  allPieces: visiblePieces,
                  onTap: () => _onTap(piece, state),
                ),
            ],
          ),
        );
      },
    );
  }

  List<LudoPiece> _mergeAnimating(List<LudoPiece> pieces, LudoPiece? anim) {
    if (anim == null) return pieces;
    return [for (final p in pieces) p.id == anim.id ? anim : p];
  }

  void _onTap(LudoPiece piece, LudoGameState state) {
    if (controller.isAnimating) return;
    if (piece.playerIndex != state.currentPlayerIndex) return;

    final legalHere = state.legalMoves
        .map((m) => state.pieces.firstWhere((p) => p.id == m.pieceId))
        .where(
          (p) =>
              p.playerIndex == state.currentPlayerIndex && _sameCell(p, piece),
        )
        .toList();

    if (legalHere.isEmpty) return;
    final pick = legalHere.any((p) => p.id == piece.id)
        ? piece
        : legalHere.first;
    controller.selectPiece(pick.id);
  }

  bool _sameCell(LudoPiece a, LudoPiece b) {
    if (a.isHome != b.isHome || a.isFinished != b.isFinished) return false;
    if (a.isHome || a.isFinished) return a.id == b.id;
    return a.trackPosition == b.trackPosition && a.playerIndex == b.playerIndex;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flat 2D piece
// ─────────────────────────────────────────────────────────────────────────────

class _FlatPiece extends StatefulWidget {
  const _FlatPiece({
    super.key,
    required this.piece,
    required this.cell,
    required this.color,
    required this.isLegal,
    required this.isLastMoved,
    required this.allPieces,
    required this.onTap,
  });

  final LudoPiece piece;
  final double cell;
  final Color color;
  final bool isLegal;
  final bool isLastMoved;
  final List<LudoPiece> allPieces;
  final VoidCallback onTap;

  @override
  State<_FlatPiece> createState() => _FlatPieceState();
}

class _FlatPieceState extends State<_FlatPiece>
    with SingleTickerProviderStateMixin {
  late AnimationController _pop;
  late Animation<double> _scale;
  Offset? _lastCenter;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_FlatPiece old) {
    super.didUpdateWidget(old);
    final c = _center(widget.piece, widget.cell);
    if (_lastCenter != null && _lastCenter != c) _pop.forward(from: 0);
    _lastCenter = c;
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _center(widget.piece, widget.cell);
    final radius = widget.cell * 0.36;
    final offset = _stackOffset(radius);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      left: center.dx - radius + offset.dx,
      top: center.dy - radius + offset.dy,
      width: radius * 2,
      height: radius * 2,
      child: GestureDetector(
        onTap: widget.isLegal ? widget.onTap : null,
        behavior: widget.isLegal
            ? HitTestBehavior.opaque
            : HitTestBehavior.translucent,
        child: ScaleTransition(
          scale: _scale,
          child: _TokenBody(
            color: widget.color,
            isLegal: widget.isLegal,
            isLastMoved: widget.isLastMoved,
            inStack: _inStack,
            isTop: _isTop,
            pieceLabel: '${widget.piece.id % 4 + 1}',
          ),
        ),
      ),
    );
  }

  // ── stack helpers ────────────────────────────────────────────────

  bool get _inStack {
    return widget.allPieces
            .where(
              (p) => _sameCell(p, widget.piece) && !p.isHome && !p.isFinished,
            )
            .length >
        1;
  }

  bool get _isTop {
    final peers = widget.allPieces
        .where((p) => _sameCell(p, widget.piece) && !p.isHome && !p.isFinished)
        .toList();
    return peers.length > 1 && peers.last.id == widget.piece.id;
  }

  Offset _stackOffset(double radius) {
    final peers = widget.allPieces
        .where((p) => _sameCell(p, widget.piece) && !p.isHome && !p.isFinished)
        .toList();
    if (peers.length <= 1) return Offset.zero;
    final idx = peers.indexOf(widget.piece);
    final total = peers.length;
    final angle = (idx / total) * 2 * math.pi + math.pi / 4;
    return Offset(
      radius * 0.46 * math.cos(angle),
      radius * 0.46 * math.sin(angle),
    );
  }

  bool _sameCell(LudoPiece a, LudoPiece b) {
    if (a.isHome != b.isHome || a.isFinished != b.isFinished) return false;
    if (a.isHome || a.isFinished) return a.id == b.id;
    return a.trackPosition == b.trackPosition && a.playerIndex == b.playerIndex;
  }

  // ── center resolution ────────────────────────────────────────────

  static Offset _center(LudoPiece piece, double cell) {
    if (piece.isHome) {
      final origin = kHomeBaseOrigins[piece.playerIndex];
      final slot = kHomeYardSlots[piece.id % 4];
      return Offset(
        (origin[1] + slot[1] + 0.5) * cell,
        (origin[0] + slot[0] + 0.5) * cell,
      );
    }
    if (piece.isFinished) {
      const nudge = [
        Offset(-0.55, -0.55),
        Offset(0.55, -0.55),
        Offset(0.55, 0.55),
        Offset(-0.55, 0.55),
      ];
      final base = nudge[piece.playerIndex];
      final fan = (piece.id % 4 - 1.5) * 0.12;
      return Offset(
        (kCenterCell[1] + base.dx + fan + 0.5) * cell,
        (kCenterCell[0] + base.dy + fan + 0.5) * cell,
      );
    }
    final coord = piece.trackPosition < LudoPiece.sharedPathSpan
        ? kPathCells[globalCellOf(piece.playerIndex, piece.trackPosition)]
        : kHomeStretchCells[piece.playerIndex][piece.trackPosition -
              LudoPiece.sharedPathSpan];
    return Offset((coord[1] + 0.5) * cell, (coord[0] + 0.5) * cell);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flat 2D token body  – NO shadows, NO gradients
// ─────────────────────────────────────────────────────────────────────────────

class _TokenBody extends StatelessWidget {
  const _TokenBody({
    required this.color,
    required this.isLegal,
    required this.isLastMoved,
    required this.inStack,
    required this.isTop,
    required this.pieceLabel,
  });

  final Color color;
  final bool isLegal;
  final bool isLastMoved;
  final bool inStack;
  final bool isTop;
  final String pieceLabel;

  @override
  Widget build(BuildContext context) {
    // Outline colour
    final outlineColor = isLastMoved
        ? Colors.amber.shade700
        : isLegal
        ? Colors.white
        : Colors.black.withValues(alpha: 0.35);

    final outlineWidth = isLastMoved || isLegal ? 2.5 : 1.5;

    return CustomPaint(
      painter: _FlatTokenPainter(
        fill: color,
        outlineColor: outlineColor,
        outlineWidth: outlineWidth,
        isLegal: isLegal,
        isLastMoved: isLastMoved,
        label: inStack ? pieceLabel : null,
      ),
    );
  }
}

/// Draws the 2D flat Ludo token:
///  - Filled circle in [fill] colour
///  - Thin white inner ring (classic Ludo look, flat version)
///  - Coloured centre dot
///  - Optional piece number label when stacked
///  - Dashed outline when legal (drawn as a solid contrasting ring instead
///    of actual dashes for performance)
class _FlatTokenPainter extends CustomPainter {
  _FlatTokenPainter({
    required this.fill,
    required this.outlineColor,
    required this.outlineWidth,
    required this.isLegal,
    required this.isLastMoved,
    this.label,
  });

  final Color fill;
  final Color outlineColor;
  final double outlineWidth;
  final bool isLegal;
  final bool isLastMoved;
  final String? label;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);

    // ── outer disc ──────────────────────────────────────────────
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = fill);

    // ── outline ring ────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r - outlineWidth / 2,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth,
    );

    // ── inner white ring ────────────────────────────────────────
    final innerR = r * 0.62;
    canvas.drawCircle(
      Offset(cx, cy),
      innerR,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // ── centre dot in fill colour ────────────────────────────────
    canvas.drawCircle(Offset(cx, cy), r * 0.28, Paint()..color = fill);

    // ── label (piece number) when stacked ────────────────────────
    if (label != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: fill,
            fontSize: r * 0.52,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }

    // ── last-moved amber tick mark ───────────────────────────────
    if (isLastMoved) {
      canvas.drawCircle(
        Offset(cx, cy),
        r - 1,
        Paint()
          ..color = Colors.amber.shade600
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(_FlatTokenPainter old) =>
      old.fill != fill ||
      old.outlineColor != outlineColor ||
      old.isLegal != isLegal ||
      old.isLastMoved != isLastMoved ||
      old.label != label;
}

// ─────────────────────────────────────────────────────────────────────────────
// Board painter – flat 2D, supports 2–4 players
// ─────────────────────────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  _BoardPainter({required this.theme, required this.players});

  final LudoTheme theme;
  final List<LudoPlayer> players;

  // Which player index "owns" each of the 4 board quadrants.
  // Quadrant order matches kHomeBaseOrigins: TL, TR, BR, BL.
  static const List<int> _quadrantPlayer = [0, 1, 2, 3];

  // For the centre triangles the mapping is rotated by one position.
  static const List<int> _trianglePlayer = [1, 2, 3, 0];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / kBoardGridSize;

    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = theme.boardBackgroundColor,
    );

    _paintHomeBases(canvas, cell);
    _paintSharedPath(canvas, cell);
    _paintHomeStretches(canvas, cell);
    _paintCenter(canvas, cell);
    _paintOuterBorder(canvas, size);
  }

  // ── home bases ───────────────────────────────────────────────────

  void _paintHomeBases(Canvas canvas, double cell) {
    for (var q = 0; q < 4; q++) {
      final playerIdx = _quadrantPlayer[q];
      final origin = kHomeBaseOrigins[q];

      // If this quadrant has no player in the current game, render it grey.
      final color = playerIdx < players.length
          ? players[playerIdx].color
          : Colors.grey.shade300;

      final outer = Rect.fromLTWH(
        origin[1] * cell,
        origin[0] * cell,
        cell * 6,
        cell * 6,
      );

      // Fill
      canvas.drawRect(outer, Paint()..color = color.withValues(alpha: 0.15));

      // Border
      canvas.drawRect(
        outer,
        Paint()
          ..color = color.withValues(
            alpha: playerIdx < players.length ? 0.8 : 0.3,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      if (playerIdx >= players.length) {
        continue; // No inner content for empty quadrant
      }

      // Inner yard
      final yard = Rect.fromLTWH(
        (origin[1] + 1) * cell,
        (origin[0] + 1) * cell,
        cell * 4,
        cell * 4,
      );
      canvas.drawRect(
        yard,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
      canvas.drawRect(
        yard,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Slot circles
      for (final slot in kHomeYardSlots) {
        final cx = (origin[1] + slot[1] + 0.5) * cell;
        final cy = (origin[0] + slot[0] + 0.5) * cell;
        final r = cell * 0.36;
        // Slot fill
        canvas.drawCircle(
          Offset(cx, cy),
          r,
          Paint()..color = color.withValues(alpha: 0.18),
        );
        // Slot border
        canvas.drawCircle(
          Offset(cx, cy),
          r,
          Paint()
            ..color = color.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  // ── shared path ──────────────────────────────────────────────────

  void _paintSharedPath(Canvas canvas, double cell) {
    for (var i = 0; i < kPathCells.length; i++) {
      final c = kPathCells[i];
      final rect = Rect.fromLTWH(c[1] * cell, c[0] * cell, cell, cell);
      final safe = kSafeIndices.contains(i);
      canvas.drawRect(
        rect,
        Paint()..color = safe ? theme.safeCellColor : theme.pathCellColor,
      );
      _grid(canvas, rect);
      if (safe) _star(canvas, rect.center, cell * 0.24, theme.starIconColor);
    }
  }

  // ── home stretches ───────────────────────────────────────────────

  void _paintHomeStretches(Canvas canvas, double cell) {
    for (var p = 0; p < players.length; p++) {
      final color = players[p].color;
      final cells = kHomeStretchCells[p];
      for (var i = 0; i < cells.length; i++) {
        final c = cells[i];
        final rect = Rect.fromLTWH(c[1] * cell, c[0] * cell, cell, cell);
        // Flat gradient-free fill: blend from light to solid
        final alpha = 0.28 + (i / cells.length) * 0.38;
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: alpha));
        _grid(canvas, rect);
      }
    }
  }

  // ── centre ───────────────────────────────────────────────────────

  void _paintCenter(Canvas canvas, double cell) {
    final rect = Rect.fromLTWH(6 * cell, 6 * cell, 3 * cell, 3 * cell);
    canvas.drawRect(rect, Paint()..color = Colors.white);

    final c = rect.center;
    final corners = [
      [rect.topLeft, rect.topRight],
      [rect.topRight, rect.bottomRight],
      [rect.bottomRight, rect.bottomLeft],
      [rect.bottomLeft, rect.topLeft],
    ];

    for (var i = 0; i < 4; i++) {
      final pi = _trianglePlayer[i];
      // If not enough players, render grey triangle.
      final color = pi < players.length
          ? players[pi].color
          : Colors.grey.shade200;
      final pts = corners[i];
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.65));
    }

    // Flat centre star
    _star(canvas, c, cell * 0.42, Colors.white.withValues(alpha: 0.85));
    _grid(canvas, rect, strokeWidth: 1.5);
  }

  // ── outer board border ───────────────────────────────────────────

  void _paintOuterBorder(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = theme.gridLineColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  // ── helpers ──────────────────────────────────────────────────────

  void _grid(Canvas canvas, Rect rect, {double strokeWidth = 0.8}) {
    canvas.drawRect(
      rect,
      Paint()
        ..color = theme.gridLineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  void _star(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = (i * math.pi / 5) - math.pi / 2;
      final pt = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      old.theme != theme || old.players != players;
}
