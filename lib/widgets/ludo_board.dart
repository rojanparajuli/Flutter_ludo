import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_ludo/service/ludo_team.dart';

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
  final LudoTheme      theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest.shortestSide.isFinite
          ? constraints.biggest.shortestSide
          : 360.0;
      final cell  = size / kBoardGridSize;
      final state = controller.state;
      final legalIds = state.legalMoves.map((m) => m.pieceId).toSet();

      final visible = _mergeAnimating(state.pieces, controller.animatingPiece);

      // Z-order: current player's pieces always on top
      final currentIdx = state.currentPlayerIndex;
      final sorted = [
        ...visible.where((p) => p.playerIndex != currentIdx),
        ...visible.where((p) => p.playerIndex == currentIdx),
      ];

      return SizedBox(
        width: size,
        height: size,
        child: Stack(children: [
          CustomPaint(
            size: Size(size, size),
            painter: _BoardPainter(
              theme: theme,
              players: state.players,
              teams: state.teams,
            ),
          ),
          for (final piece in sorted)
            _FlatPiece(
              key: ValueKey(piece.id),
              piece: piece,
              cell: cell,
              color: state.players[piece.playerIndex].color,
              isLegal: legalIds.contains(piece.id),
              isLastMoved: state.lastMovedPiece?.id == piece.id &&
                           controller.animatingPiece == null,
              allPieces: visible,
              onTap: () => _onTap(piece, state),
              teams: state.teams,
              currentPlayerIndex: currentIdx,
            ),
        ]),
      );
    });
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
        .where((p) =>
            p.playerIndex == state.currentPlayerIndex &&
            _sameCell(p, piece))
        .toList();

    if (legalHere.isEmpty) return;
    final pick =
        legalHere.any((p) => p.id == piece.id) ? piece : legalHere.first;
    controller.selectPiece(pick.id);
  }

  bool _sameCell(LudoPiece a, LudoPiece b) {
    if (a.isHome != b.isHome || a.isFinished != b.isFinished) return false;
    if (a.isHome || a.isFinished) return a.id == b.id;
    return a.trackPosition == b.trackPosition &&
           a.playerIndex   == b.playerIndex;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flat 2D piece widget
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
    required this.currentPlayerIndex,
    this.teams,
  });

  final LudoPiece        piece;
  final double           cell;
  final Color            color;
  final bool             isLegal;
  final bool             isLastMoved;
  final List<LudoPiece>  allPieces;
  final VoidCallback     onTap;
  final List<LudoTeam>?  teams;
  final int              currentPlayerIndex;

  @override
  State<_FlatPiece> createState() => _FlatPieceState();
}

class _FlatPieceState extends State<_FlatPiece>
    with SingleTickerProviderStateMixin {
  late AnimationController _pop;
  late Animation<double>   _scale;
  Offset? _lastCenter;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
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
    final center  = _center(widget.piece, widget.cell);
    final radius  = widget.cell * 0.36;
    final offset  = _stackOffset(radius);
    final inStack = _inStack;
    final isTop   = _isTop;

    // In teams mode, detect if this piece is in a friendly stack
    // (teammate piece sharing the cell).
    final hasFriendlyStackmate = _hasFriendlyStackmate;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      left:   center.dx - radius + offset.dx,
      top:    center.dy - radius + offset.dy,
      width:  radius * 2,
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
            inStack: inStack,
            isTop: isTop,
            pieceLabel: inStack ? '${widget.piece.id % 4 + 1}' : null,
            hasFriendlyStackmate: hasFriendlyStackmate,
          ),
        ),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────

  bool get _inStack {
    return widget.allPieces
        .where((p) => _sameCell(p, widget.piece) && !p.isHome && !p.isFinished)
        .length > 1;
  }

  bool get _isTop {
    final peers = widget.allPieces
        .where((p) => _sameCell(p, widget.piece) && !p.isHome && !p.isFinished)
        .toList();
    return peers.length > 1 && peers.last.id == widget.piece.id;
  }

  /// True if a teammate's piece shares this cell (teams mode only).
  bool get _hasFriendlyStackmate {
    if (widget.teams == null) return false;
    if (widget.piece.isHome || widget.piece.isFinished) return false;
    return widget.allPieces.any((p) =>
        p.id != widget.piece.id &&
        !p.isHome &&
        !p.isFinished &&
        areTeammates(p.playerIndex, widget.piece.playerIndex, widget.teams) &&
        _sameCell(p, widget.piece));
  }

  Offset _stackOffset(double radius) {
    final peers = widget.allPieces
        .where((p) => _sameCell(p, widget.piece) && !p.isHome && !p.isFinished)
        .toList();
    if (peers.length <= 1) return Offset.zero;
    final idx   = peers.indexOf(widget.piece);
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
    return a.trackPosition == b.trackPosition &&
           a.playerIndex   == b.playerIndex;
  }

  static Offset _center(LudoPiece piece, double cell) {
    if (piece.isHome) {
      final origin = kHomeBaseOrigins[piece.playerIndex];
      final slot   = kHomeYardSlots[piece.id % 4];
      return Offset(
        (origin[1] + slot[1] + 0.5) * cell,
        (origin[0] + slot[0] + 0.5) * cell,
      );
    }
    if (piece.isFinished) {
      const nudge = [
        Offset(-0.55, -0.55), Offset(0.55, -0.55),
        Offset(0.55,  0.55),  Offset(-0.55, 0.55),
      ];
      final base = nudge[piece.playerIndex];
      final fan  = (piece.id % 4 - 1.5) * 0.12;
      return Offset(
        (kCenterCell[1] + base.dx + fan + 0.5) * cell,
        (kCenterCell[0] + base.dy + fan + 0.5) * cell,
      );
    }
    final coord = piece.trackPosition < LudoPiece.sharedPathSpan
        ? kPathCells[globalCellOf(piece.playerIndex, piece.trackPosition)]
        : kHomeStretchCells[piece.playerIndex]
              [piece.trackPosition - LudoPiece.sharedPathSpan];
    return Offset((coord[1] + 0.5) * cell, (coord[0] + 0.5) * cell);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flat token body
// ─────────────────────────────────────────────────────────────────────────────

class _TokenBody extends StatelessWidget {
  const _TokenBody({
    required this.color,
    required this.isLegal,
    required this.isLastMoved,
    required this.inStack,
    required this.isTop,
    required this.hasFriendlyStackmate,
    this.pieceLabel,
  });

  final Color   color;
  final bool    isLegal;
  final bool    isLastMoved;
  final bool    inStack;
  final bool    isTop;
  final bool    hasFriendlyStackmate;
  final String? pieceLabel;

  @override
  Widget build(BuildContext context) {
    final outlineColor = isLastMoved
        ? Colors.amber.shade700
        : hasFriendlyStackmate
            ? Colors.white
            : isLegal
                ? Colors.white
                : Colors.black.withValues(alpha: 0.35);

    return CustomPaint(
      painter: _FlatTokenPainter(
        fill: color,
        outlineColor: outlineColor,
        outlineWidth: isLastMoved || isLegal || hasFriendlyStackmate ? 2.5 : 1.5,
        isLegal: isLegal,
        isLastMoved: isLastMoved,
        hasFriendlyStackmate: hasFriendlyStackmate,
        label: pieceLabel,
      ),
    );
  }
}

class _FlatTokenPainter extends CustomPainter {
  const _FlatTokenPainter({
    required this.fill,
    required this.outlineColor,
    required this.outlineWidth,
    required this.isLegal,
    required this.isLastMoved,
    required this.hasFriendlyStackmate,
    this.label,
  });

  final Color   fill;
  final Color   outlineColor;
  final double  outlineWidth;
  final bool    isLegal;
  final bool    isLastMoved;
  final bool    hasFriendlyStackmate;
  final String? label;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy);

    // Outer disc
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = fill);

    // Outline
    canvas.drawCircle(
      Offset(cx, cy),
      r - outlineWidth / 2,
      Paint()
        ..color       = outlineColor
        ..style       = PaintingStyle.stroke
        ..strokeWidth = outlineWidth,
    );

    // Inner white ring
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.62,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // Centre dot
    canvas.drawCircle(Offset(cx, cy), r * 0.28, Paint()..color = fill);

    // Friendly stack indicator — dashed inner ring in white
    // (shows this piece has a teammate sharing the cell)
    if (hasFriendlyStackmate) {
      final dashPaint = Paint()
        ..color       = Colors.white.withValues(alpha: 0.85)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      _drawDashedCircle(canvas, Offset(cx, cy), r * 0.80, dashPaint, 8);
    }

    // Piece number label when in any stack
    if (label != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: fill,
            fontSize: r * 0.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }

    // Last-moved amber ring
    if (isLastMoved) {
      canvas.drawCircle(
        Offset(cx, cy),
        r - 1,
        Paint()
          ..color       = Colors.amber.shade600
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  /// Draws a dashed circle with [dashCount] evenly spaced dashes.
  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
    int dashCount,
  ) {
    final step = (2 * math.pi) / dashCount;
    for (var i = 0; i < dashCount; i++) {
      final startAngle = i * step;
      final sweepAngle = step * 0.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FlatTokenPainter old) =>
      old.fill != fill ||
      old.isLegal != isLegal ||
      old.isLastMoved != isLastMoved ||
      old.hasFriendlyStackmate != hasFriendlyStackmate ||
      old.label != label;
}

// ─────────────────────────────────────────────────────────────────────────────
// Board painter — highlights teammate home bases with a shared border
// ─────────────────────────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.theme,
    required this.players,
    this.teams,
  });

  final LudoTheme        theme;
  final List<LudoPlayer> players;
  final List<LudoTeam>?  teams;

  static const List<int> _trianglePlayer = [1, 2, 3, 0];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / kBoardGridSize;
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.boardBackgroundColor);
    _paintHomeBases(canvas, cell);
    _paintSharedPath(canvas, cell);
    _paintHomeStretches(canvas, cell);
    _paintCenter(canvas, cell);
    _paintTeamBrackets(canvas, cell);
    _paintOuterBorder(canvas, size);
  }

  void _paintHomeBases(Canvas canvas, double cell) {
    for (var q = 0; q < 4; q++) {
      final color = q < players.length
          ? players[q].color
          : Colors.grey.shade300;
      final origin = kHomeBaseOrigins[q];

      final outer = Rect.fromLTWH(
        origin[1] * cell, origin[0] * cell, cell * 6, cell * 6,
      );

      canvas.drawRect(outer, Paint()..color = color.withValues(alpha: 0.15));
      canvas.drawRect(
        outer,
        Paint()
          ..color       = color.withValues(alpha: q < players.length ? 0.8 : 0.3)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      if (q >= players.length) continue;

      final yard = Rect.fromLTWH(
        (origin[1] + 1) * cell, (origin[0] + 1) * cell, cell * 4, cell * 4,
      );
      canvas.drawRect(yard, Paint()..color = Colors.white.withValues(alpha: 0.6));
      canvas.drawRect(
        yard,
        Paint()
          ..color       = color.withValues(alpha: 0.4)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      for (final slot in kHomeYardSlots) {
        final cx = (origin[1] + slot[1] + 0.5) * cell;
        final cy = (origin[0] + slot[0] + 0.5) * cell;
        canvas.drawCircle(Offset(cx, cy), cell * 0.36,
            Paint()..color = color.withValues(alpha: 0.18));
        canvas.drawCircle(
          Offset(cx, cy), cell * 0.36,
          Paint()
            ..color       = color.withValues(alpha: 0.55)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  /// Draws a subtle coloured bracket connecting each team's two home bases,
  /// so players can instantly see who their teammate is.
  ///
  /// Team A (0+3): connects top-left ↔ bottom-left  (left edge)
  /// Team B (1+2): connects top-right ↔ bottom-right (right edge)
  void _paintTeamBrackets(Canvas canvas, double cell) {
    if (teams == null) return;

    // Team A: players 0 (TL) and 3 (BL)
    // Team B: players 1 (TR) and 2 (BR)
    final teamConnections = [
      // [quadrantA, quadrantB, side]
      // side: 0=left, 1=right, 2=top, 3=bottom
      [0, 3, 0], // Team A — left side
      [1, 2, 1], // Team B — right side
    ];

    for (var t = 0; t < teams!.length && t < teamConnections.length; t++) {
      final conn  = teamConnections[t];
      final qA    = conn[0];
      final qB    = conn[1];
      if (qA >= players.length || qB >= players.length) continue;

      // Blend team colors for the bracket line
      final colorA = players[qA].color;
      final colorB = players[qB].color;

      final originA = kHomeBaseOrigins[qA];
      final originB = kHomeBaseOrigins[qB];

      // Draw a thick line on the outer edge connecting the two bases
      final paint = Paint()
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // side 0 = left edge, side 1 = right edge
      final side = conn[2];
      Offset p1, p2;

      if (side == 0) {
        // Left edge of TL and BL bases
        p1 = Offset(originA[1] * cell, (originA[0] + 1) * cell);
        p2 = Offset(originB[1] * cell, (originB[0] + 5) * cell);
      } else {
        // Right edge of TR and BR bases
        p1 = Offset((originA[1] + 6) * cell, (originA[0] + 1) * cell);
        p2 = Offset((originB[1] + 6) * cell, (originB[0] + 5) * cell);
      }

      // Draw colorA segment (top half) and colorB segment (bottom half)
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      paint.color = colorA.withValues(alpha: 0.7);
      canvas.drawLine(p1, mid, paint);
      paint.color = colorB.withValues(alpha: 0.7);
      canvas.drawLine(mid, p2, paint);

      // Small circles at the endpoints to cap the bracket
      canvas.drawCircle(p1, 5, Paint()..color = colorA.withValues(alpha: 0.8));
      canvas.drawCircle(p2, 5, Paint()..color = colorB.withValues(alpha: 0.8));
    }
  }

  void _paintSharedPath(Canvas canvas, double cell) {
    for (var i = 0; i < kPathCells.length; i++) {
      final c    = kPathCells[i];
      final rect = Rect.fromLTWH(c[1] * cell, c[0] * cell, cell, cell);
      final safe = kSafeIndices.contains(i);
      canvas.drawRect(rect, Paint()..color = safe ? theme.safeCellColor : theme.pathCellColor);
      _grid(canvas, rect);
      if (safe) _star(canvas, rect.center, cell * 0.24, theme.starIconColor);
    }
  }

  void _paintHomeStretches(Canvas canvas, double cell) {
    for (var p = 0; p < players.length; p++) {
      final color = players[p].color;
      final cells = kHomeStretchCells[p];
      for (var i = 0; i < cells.length; i++) {
        final c    = cells[i];
        final rect = Rect.fromLTWH(c[1] * cell, c[0] * cell, cell, cell);
        canvas.drawRect(
          rect,
          Paint()..color = color.withValues(alpha: 0.28 + (i / cells.length) * 0.38),
        );
        _grid(canvas, rect);
      }
    }
  }

  void _paintCenter(Canvas canvas, double cell) {
    final rect = Rect.fromLTWH(6 * cell, 6 * cell, 3 * cell, 3 * cell);
    canvas.drawRect(rect, Paint()..color = Colors.white);

    final c       = rect.center;
    final corners = [
      [rect.topLeft,     rect.topRight],
      [rect.topRight,    rect.bottomRight],
      [rect.bottomRight, rect.bottomLeft],
      [rect.bottomLeft,  rect.topLeft],
    ];

    for (var i = 0; i < 4; i++) {
      final pi    = _trianglePlayer[i];
      final color = pi < players.length ? players[pi].color : Colors.grey.shade200;
      final pts   = corners[i];
      final path  = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.65));
    }

    _star(canvas, c, cell * 0.42, Colors.white.withValues(alpha: 0.85));
    _grid(canvas, rect, strokeWidth: 1.5);
  }

  void _paintOuterBorder(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color       = theme.gridLineColor.withValues(alpha: 0.5)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  void _grid(Canvas canvas, Rect rect, {double strokeWidth = 0.8}) {
    canvas.drawRect(
      rect,
      Paint()
        ..color       = theme.gridLineColor
        ..style       = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  void _star(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r     = i.isEven ? radius : radius * 0.45;
      final angle = (i * math.pi / 5) - math.pi / 2;
      final pt    = Offset(
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
      old.theme != theme || old.players != players || old.teams != teams;
}