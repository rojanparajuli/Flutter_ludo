import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_ludo/constant/board_constants.dart';
import 'package:flutter_ludo/model/ludo_piece.dart';
import 'package:flutter_ludo/model/ludo_player.dart';

import '../controller/ludo_controller.dart';
import '../themes/ludo_theme.dart';

/// Renders the fixed 15x15 Ludo board and every piece, driven by
/// [controller].
///
/// Tapping a piece that is part of the current legal moves calls
/// [LudoController.selectPiece] automatically — no extra wiring needed.
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
        final legalPieceIds = state.legalMoves.map((m) => m.pieceId).toSet();

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _LudoBoardPainter(
                  theme: theme,
                  players: state.players,
                ),
              ),
              for (final piece in state.pieces)
                _PositionedPiece(
                  key: ValueKey(piece.id),
                  piece: piece,
                  cell: cell,
                  color: state.players[piece.playerIndex].color,
                  isLegal: legalPieceIds.contains(piece.id),
                  onTap: legalPieceIds.contains(piece.id)
                      ? () => controller.selectPiece(piece.id)
                      : null,
                  allPieces: state.pieces,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PositionedPiece extends StatelessWidget {
  const _PositionedPiece({
    super.key,
    required this.piece,
    required this.cell,
    required this.color,
    required this.isLegal,
    required this.onTap,
    required this.allPieces,
  });

  final LudoPiece piece;
  final double cell;
  final Color color;
  final bool isLegal;
  final VoidCallback? onTap;
  final List<LudoPiece> allPieces;

  @override
  Widget build(BuildContext context) {
    final center = _resolveCenter(piece, cell);
    final radius = cell * 0.34;
    
    // Calculate offset for stacked pieces
    final offset = _calculateStackOffset(piece, allPieces, radius);
    
    // Check if this piece is at the top of a stack
    final isTopOfStack = _isTopOfStack(piece, allPieces);
    final isInStack = _isInStack(piece, allPieces);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: center.dx - radius + offset.dx,
      top: center.dy - radius + offset.dy,
      width: radius * 2,
      height: radius * 2,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: _getBorderColor(isLegal, isTopOfStack, isInStack),
              width: _getBorderWidth(isLegal, isTopOfStack, isInStack),
            ),
            boxShadow: _getBoxShadow(isLegal, isTopOfStack, color),
          ),
          child: _buildStackIndicator(isInStack, isTopOfStack),
        ),
      ),
    );
  }

  Widget? _buildStackIndicator(bool isInStack, bool isTopOfStack) {
    if (!isInStack) return null;
    
    return Center(
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: isTopOfStack ? Colors.white : Colors.white.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black26,
            width: 0.5,
          ),
        ),
      ),
    );
  }

  Color _getBorderColor(bool isLegal, bool isTopOfStack, bool isInStack) {
    if (isLegal) return Colors.white;
    if (isTopOfStack) return Colors.white70;
    if (isInStack) return Colors.white38;
    return Colors.black54;
  }

  double _getBorderWidth(bool isLegal, bool isTopOfStack, bool isInStack) {
    if (isLegal) return 3.0;
    if (isTopOfStack) return 2.5;
    if (isInStack) return 1.5;
    return 1.5;
  }

  List<BoxShadow>? _getBoxShadow(bool isLegal, bool isTopOfStack, Color color) {
    if (isLegal) {
      return [
        BoxShadow(
          color: color.withValues(alpha: 0.7),
          blurRadius: 6,
          spreadRadius: 2,
        ),
      ];
    }
    if (isTopOfStack) {
      return [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return null;
  }

  Offset _calculateStackOffset(LudoPiece piece, List<LudoPiece> allPieces, double radius) {
    // Get all pieces at the same position (excluding home and finished)
    final piecesAtSamePosition = allPieces.where((p) => 
      _isAtSamePosition(p, piece) &&
      !p.isHome && 
      !p.isFinished
    ).toList();
    
    if (piecesAtSamePosition.length <= 1) {
      return Offset.zero;
    }

    // Offset pieces in a circular pattern
    final indexInStack = piecesAtSamePosition.indexOf(piece);
    final totalInStack = piecesAtSamePosition.length;
    
    // Fan out in a circle with some randomness
    final angle = (indexInStack / totalInStack) * 2 * math.pi + (math.pi / 4);
    final distance = radius * 0.4; // Slightly less than radius to keep them overlapping
    
    return Offset(
      distance * math.cos(angle),
      distance * math.sin(angle),
    );
  }

  bool _isAtSamePosition(LudoPiece a, LudoPiece b) {
    // Check if two pieces are at the same track position
    if (a.isHome != b.isHome) return false;
    if (a.isFinished != b.isFinished) return false;
    
    if (a.isHome || a.isFinished) {
      return a.id == b.id; // Same piece
    }
    
    return a.trackPosition == b.trackPosition && 
           a.playerIndex == b.playerIndex;
  }

  bool _isTopOfStack(LudoPiece piece, List<LudoPiece> allPieces) {
    final piecesAtSamePosition = allPieces.where((p) => 
      _isAtSamePosition(p, piece) &&
      !p.isHome && 
      !p.isFinished
    ).toList();
    
    if (piecesAtSamePosition.length <= 1) return false;
    
    // The top piece is the one with the highest ID (last added/moved)
    // Or we could use the one with the most recent move time if available
    return piecesAtSamePosition.last == piece;
  }

  bool _isInStack(LudoPiece piece, List<LudoPiece> allPieces) {
    final piecesAtSamePosition = allPieces.where((p) => 
      _isAtSamePosition(p, piece) &&
      !p.isHome && 
      !p.isFinished
    ).toList();
    
    return piecesAtSamePosition.length > 1;
  }

  static Offset _resolveCenter(LudoPiece piece, double cell) {
    if (piece.isHome) {
      final origin = kHomeBaseOrigins[piece.playerIndex];
      final slot = kHomeYardSlots[piece.id % 4];
      final row = origin[0] + slot[0];
      final col = origin[1] + slot[1];
      return Offset((col + 0.5) * cell, (row + 0.5) * cell);
    }

    if (piece.isFinished) {
      // Fan finished pieces out a little within the center square so a
      // player's 4 finished tokens (and other players') don't fully
      // overlap. Each player is nudged toward the corner closest to their
      // own home base.
      const cornerNudge = [
        Offset(-0.55, -0.55), // player 0: top-left
        Offset(0.55, -0.55), // player 1: top-right
        Offset(0.55, 0.55), // player 2: bottom-right
        Offset(-0.55, 0.55), // player 3: bottom-left
      ];
      final base = cornerNudge[piece.playerIndex];
      final siblingIndex = piece.id % 4;
      final fan = (siblingIndex - 1.5) * 0.12;
      final row = kCenterCell[0] + base.dy + fan;
      final col = kCenterCell[1] + base.dx + fan;
      return Offset((col + 0.5) * cell, (row + 0.5) * cell);
    }

    final cellCoord = piece.trackPosition < LudoPiece.sharedPathSpan
        ? kPathCells[globalCellOf(piece.playerIndex, piece.trackPosition)]
        : kHomeStretchCells[piece.playerIndex]
            [piece.trackPosition - LudoPiece.sharedPathSpan];
    return Offset((cellCoord[1] + 0.5) * cell, (cellCoord[0] + 0.5) * cell);
  }
}

class _LudoBoardPainter extends CustomPainter {
  _LudoBoardPainter({required this.theme, required this.players});

  final LudoTheme theme;
  final List<LudoPlayer> players;

  static const List<int> _trianglePlayers = [1, 2, 3, 0]; // top,right,bottom,left

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / kBoardGridSize;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = theme.boardBackgroundColor,
    );

    _paintHomeBases(canvas, cell);
    _paintSharedPath(canvas, cell);
    _paintHomeStretches(canvas, cell);
    _paintCenter(canvas, cell);
  }

  void _paintHomeBases(Canvas canvas, double cell) {
    for (var p = 0; p < kHomeBaseOrigins.length; p++) {
      if (p >= players.length) continue;
      final origin = kHomeBaseOrigins[p];
      final outer = Rect.fromLTWH(
        origin[1] * cell,
        origin[0] * cell,
        cell * 6,
        cell * 6,
      );
      canvas.drawRect(outer, Paint()..color = players[p].color.withValues(alpha: 0.20));
      _strokeRect(canvas, outer, 1.5);

      final yard = Rect.fromLTWH(
        (origin[1] + 1) * cell,
        (origin[0] + 1) * cell,
        cell * 4,
        cell * 4,
      );
      canvas.drawRect(yard, Paint()..color = Colors.white);
      _strokeRect(canvas, yard, 1);
    }
  }

  void _paintSharedPath(Canvas canvas, double cell) {
    for (var i = 0; i < kPathCells.length; i++) {
      final coord = kPathCells[i];
      final rect = Rect.fromLTWH(
        coord[1] * cell,
        coord[0] * cell,
        cell,
        cell,
      );
      final isSafe = kSafeIndices.contains(i);
      canvas.drawRect(
        rect,
        Paint()..color = isSafe ? theme.safeCellColor : theme.pathCellColor,
      );
      _strokeRect(canvas, rect, 1);
      if (isSafe) {
        _drawStar(canvas, rect.center, cell * 0.28, theme.starIconColor);
      }
    }
  }

  void _paintHomeStretches(Canvas canvas, double cell) {
    for (var p = 0; p < kHomeStretchCells.length; p++) {
      if (p >= players.length) continue;
      final color = players[p].color;
      for (final coord in kHomeStretchCells[p]) {
        final rect = Rect.fromLTWH(
          coord[1] * cell,
          coord[0] * cell,
          cell,
          cell,
        );
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.45));
        _strokeRect(canvas, rect, 1);
      }
    }
  }

  void _paintCenter(Canvas canvas, double cell) {
    final centerRect = Rect.fromLTWH(6 * cell, 6 * cell, cell * 3, cell * 3);
    canvas.drawRect(centerRect, Paint()..color = theme.centerCellColor);

    final c = centerRect.center;
    final triangleCorners = [
      [centerRect.topLeft, centerRect.topRight],
      [centerRect.topRight, centerRect.bottomRight],
      [centerRect.bottomRight, centerRect.bottomLeft],
      [centerRect.bottomLeft, centerRect.topLeft],
    ];

    for (var i = 0; i < 4; i++) {
      final playerIndex = _trianglePlayers[i];
      if (playerIndex >= players.length) continue;
      final corners = triangleCorners[i];
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(corners[0].dx, corners[0].dy)
        ..lineTo(corners[1].dx, corners[1].dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = players[playerIndex].color.withValues(alpha: 0.55),
      );
    }

    _strokeRect(canvas, centerRect, 1.5);
  }

  void _strokeRect(Canvas canvas, Rect rect, double width) {
    canvas.drawRect(
      rect,
      Paint()
        ..color = theme.gridLineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    const points = 5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = (i * math.pi / points) - math.pi / 2;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainter oldDelegate) {
    return oldDelegate.theme != theme || oldDelegate.players != players;
  }
}