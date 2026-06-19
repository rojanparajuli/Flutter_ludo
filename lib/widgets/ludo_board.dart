import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_ludo/constant/board_constants.dart';
import 'package:flutter_ludo/model/ludo_game_state.dart';
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
              // Movement trail overlay
              if (state.lastMovedPiece != null)
                _MovementTrail(
                  piece: state.lastMovedPiece!,
                  cell: cell,
                  color: state.players[state.lastMovedPiece!.playerIndex].color,
                  theme: theme,
                ),
              for (final piece in state.pieces)
                _PositionedPiece(
                  key: ValueKey(piece.id),
                  piece: piece,
                  cell: cell,
                  color: state.players[piece.playerIndex].color,
                  isLegal: legalPieceIds.contains(piece.id),
                  onTap: () => _handlePieceTap(context, piece, state),
                  allPieces: state.pieces,
                  isLastMoved: state.lastMovedPiece?.id == piece.id,
                ),
            ],
          ),
        );
      },
    );
  }

  void _handlePieceTap(
    BuildContext context,
    LudoPiece piece,
    LudoGameState state,
  ) {
    // Only allow tapping pieces that belong to the current player.
    if (piece.playerIndex != state.currentPlayerIndex) {
      return; // Silently ignore taps on other players' pieces
    }

    // Get all pieces at the same position (only current player's pieces)
    final piecesAtSamePosition = state.pieces
        .where(
          (p) =>
              _isAtSamePosition(p, piece) &&
              !p.isHome &&
              !p.isFinished &&
              p.playerIndex ==
                  state.currentPlayerIndex, // Only current player's pieces
        )
        .toList();

    // If no stack or only one piece, just select it
    if (piecesAtSamePosition.length <= 1) {
      controller.selectPiece(piece.id);
      return;
    }

    // Get legal pieces in this stack (only current player's pieces)
    final legalPieces = piecesAtSamePosition
        .where((p) => state.legalMoves.any((m) => m.pieceId == p.id))
        .toList();

    if (legalPieces.isEmpty) return;

    // All pieces in the stack belong to the same player, so it doesn't
    // matter which one is moved — pick one automatically instead of
    // prompting the user to choose.
    controller.selectPiece(legalPieces.first.id);
  }

  bool _isAtSamePosition(LudoPiece a, LudoPiece b) {
    if (a.isHome != b.isHome) return false;
    if (a.isFinished != b.isFinished) return false;

    if (a.isHome || a.isFinished) {
      return a.id == b.id;
    }

    return a.trackPosition == b.trackPosition && a.playerIndex == b.playerIndex;
  }
}

// New widget for movement trail effect
class _MovementTrail extends StatelessWidget {
  const _MovementTrail({
    required this.piece,
    required this.cell,
    required this.color,
    required this.theme,
  });

  final LudoPiece piece;
  final double cell;
  final Color color;
  final LudoTheme theme;

  @override
  Widget build(BuildContext context) {
    final center = _resolveCenter(piece, cell);
    final radius = cell * 0.34;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      left: center.dx - radius * 1.2,
      top: center.dy - radius * 1.2,
      width: radius * 2.4,
      height: radius * 2.4,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
      ),
    );
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
      const cornerNudge = [
        Offset(-0.55, -0.55),
        Offset(0.55, -0.55),
        Offset(0.55, 0.55),
        Offset(-0.55, 0.55),
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
        : kHomeStretchCells[piece.playerIndex][piece.trackPosition -
              LudoPiece.sharedPathSpan];
    return Offset((cellCoord[1] + 0.5) * cell, (cellCoord[0] + 0.5) * cell);
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
    this.isLastMoved = false,
  });

  final LudoPiece piece;
  final double cell;
  final Color color;
  final bool isLegal;
  final VoidCallback onTap;
  final List<LudoPiece> allPieces;
  final bool isLastMoved;

  @override
  Widget build(BuildContext context) {
    final center = _resolveCenter(piece, cell);
    final radius = cell * 0.34;

    final offset = _calculateStackOffset(piece, allPieces, radius);
    final isTopOfStack = _isTopOfStack(piece, allPieces);
    final isInStack = _isInStack(piece, allPieces);
    final isSelectable = isLegal && isInStack && !isTopOfStack;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: center.dx - radius + offset.dx,
      top: center.dy - radius + offset.dy,
      width: radius * 2,
      height: radius * 2,
      child: GestureDetector(
        onTap: isLegal ? onTap : null,
        behavior: isLegal
            ? HitTestBehavior.opaque
            : HitTestBehavior.translucent,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: _getBorderColor(
                isLegal,
                isTopOfStack,
                isInStack,
                isSelectable,
                isLastMoved,
              ),
              width: _getBorderWidth(
                isLegal,
                isTopOfStack,
                isInStack,
                isSelectable,
                isLastMoved,
              ),
            ),
            boxShadow: _getBoxShadow(
              isLegal,
              isTopOfStack,
              color,
              isSelectable,
              isLastMoved,
            ),
          ),
          child: Stack(
            children: [
              // Visual indicator for selectable pieces in stack
              if (isSelectable)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              // Last moved indicator
              if (isLastMoved)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.yellow,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.yellow.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              // Stack position indicator
              ?_buildStackIndicator(isInStack, isTopOfStack, isSelectable),
              // Piece number for identification
              if (isInStack)
                Center(
                  child: Text(
                    '${piece.id % 4 + 1}',
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: isTopOfStack ? 1.0 : 0.6,
                      ),
                      fontSize: radius * 0.6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildStackIndicator(
    bool isInStack,
    bool isTopOfStack,
    bool isSelectable,
  ) {
    if (!isInStack) return null;

    Color dotColor;
    if (isTopOfStack) {
      dotColor = Colors.white;
    } else if (isSelectable) {
      dotColor = Colors.white.withValues(alpha: 0.9);
    } else {
      dotColor = Colors.white.withValues(alpha: 0.3);
    }

    return Positioned(
      bottom: 2,
      right: 2,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: dotColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelectable ? Colors.white : Colors.black26,
            width: isSelectable ? 2 : 0.5,
          ),
        ),
      ),
    );
  }

  Color _getBorderColor(
    bool isLegal,
    bool isTopOfStack,
    bool isInStack,
    bool isSelectable,
    bool isLastMoved,
  ) {
    if (isLastMoved) return Colors.yellow;
    if (isSelectable) return Colors.white;
    if (isLegal) return Colors.white;
    if (isTopOfStack) return Colors.white70;
    if (isInStack) return Colors.white38;
    return Colors.black54;
  }

  double _getBorderWidth(
    bool isLegal,
    bool isTopOfStack,
    bool isInStack,
    bool isSelectable,
    bool isLastMoved,
  ) {
    if (isLastMoved) return 4.0;
    if (isSelectable) return 3.0;
    if (isLegal) return 3.0;
    if (isTopOfStack) return 2.5;
    if (isInStack) return 1.5;
    return 1.5;
  }

  List<BoxShadow>? _getBoxShadow(
    bool isLegal,
    bool isTopOfStack,
    Color color,
    bool isSelectable,
    bool isLastMoved,
  ) {
    if (isLastMoved) {
      return [
        BoxShadow(
          color: Colors.yellow.withValues(alpha: 0.6),
          blurRadius: 16,
          spreadRadius: 6,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 8,
          spreadRadius: 2,
        ),
      ];
    }
    if (isSelectable) {
      return [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.5),
          blurRadius: 12,
          spreadRadius: 4,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: 8,
          spreadRadius: 2,
        ),
      ];
    }
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

  Offset _calculateStackOffset(
    LudoPiece piece,
    List<LudoPiece> allPieces,
    double radius,
  ) {
    final piecesAtSamePosition = allPieces
        .where((p) => _isAtSamePosition(p, piece) && !p.isHome && !p.isFinished)
        .toList();

    if (piecesAtSamePosition.length <= 1) {
      return Offset.zero;
    }

    final indexInStack = piecesAtSamePosition.indexOf(piece);
    final totalInStack = piecesAtSamePosition.length;

    // Fan out in a circle
    final angle = (indexInStack / totalInStack) * 2 * math.pi + (math.pi / 4);
    final distance = radius * 0.5;

    return Offset(distance * math.cos(angle), distance * math.sin(angle));
  }

  bool _isAtSamePosition(LudoPiece a, LudoPiece b) {
    if (a.isHome != b.isHome) return false;
    if (a.isFinished != b.isFinished) return false;

    if (a.isHome || a.isFinished) {
      return a.id == b.id;
    }

    return a.trackPosition == b.trackPosition && a.playerIndex == b.playerIndex;
  }

  bool _isTopOfStack(LudoPiece piece, List<LudoPiece> allPieces) {
    final piecesAtSamePosition = allPieces
        .where((p) => _isAtSamePosition(p, piece) && !p.isHome && !p.isFinished)
        .toList();

    if (piecesAtSamePosition.length <= 1) return false;

    return piecesAtSamePosition.last == piece;
  }

  bool _isInStack(LudoPiece piece, List<LudoPiece> allPieces) {
    final piecesAtSamePosition = allPieces
        .where((p) => _isAtSamePosition(p, piece) && !p.isHome && !p.isFinished)
        .toList();

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
      const cornerNudge = [
        Offset(-0.55, -0.55),
        Offset(0.55, -0.55),
        Offset(0.55, 0.55),
        Offset(-0.55, 0.55),
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
        : kHomeStretchCells[piece.playerIndex][piece.trackPosition -
              LudoPiece.sharedPathSpan];
    return Offset((cellCoord[1] + 0.5) * cell, (cellCoord[0] + 0.5) * cell);
  }
}

class _LudoBoardPainter extends CustomPainter {
  _LudoBoardPainter({required this.theme, required this.players});

  final LudoTheme theme;
  final List<LudoPlayer> players;

  static const List<int> _trianglePlayers = [1, 2, 3, 0];

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
      
      // Draw outer border with partition effect
      final borderPaint = Paint()
        ..color = theme.homeBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(outer, borderPaint);

      // Fill home base with translucent color
      canvas.drawRect(
        outer,
        Paint()..color = players[p].color.withValues(alpha: 0.15),
      );

      // Draw partition lines (4 quadrants for each piece)
      final partitionPaint = Paint()
        ..color = theme.homePartitionColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Vertical and horizontal partition lines
      final centerX = (origin[1] + 3) * cell;
      final centerY = (origin[0] + 3) * cell;
      
      // Vertical line
      canvas.drawLine(
        Offset(centerX, origin[0] * cell),
        Offset(centerX, (origin[0] + 6) * cell),
        partitionPaint,
      );
      
      // Horizontal line
      canvas.drawLine(
        Offset(origin[1] * cell, centerY),
        Offset((origin[1] + 6) * cell, centerY),
        partitionPaint,
      );

      // Draw individual piece slots with subtle borders
      for (var slot in kHomeYardSlots) {
        final row = origin[0] + slot[0];
        final col = origin[1] + slot[1];
        final slotRect = Rect.fromLTWH(
          col * cell + 1,
          row * cell + 1,
          cell - 2,
          cell - 2,
        );
        canvas.drawRect(
          slotRect,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }

      // Draw inner yard
      final yard = Rect.fromLTWH(
        (origin[1] + 1) * cell,
        (origin[0] + 1) * cell,
        cell * 4,
        cell * 4,
      );
      canvas.drawRect(yard, Paint()..color = Colors.white.withValues(alpha: 0.4));
      canvas.drawRect(
        yard,
        Paint()
          ..color = theme.homeBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  void _paintSharedPath(Canvas canvas, double cell) {
    for (var i = 0; i < kPathCells.length; i++) {
      final coord = kPathCells[i];
      final rect = Rect.fromLTWH(coord[1] * cell, coord[0] * cell, cell, cell);
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