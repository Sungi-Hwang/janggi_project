import 'dart:math' show cos, sin;
import 'package:flutter/material.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';
import '../models/move.dart';
import 'traditional_piece_widget.dart';

/// Widget that renders the Janggi board
class JanggiBoardWidget extends StatefulWidget {
  final Board board;
  final Position? selectedPosition;
  final List<Position> validMoves;
  final Function(Position)? onSquareTapped;
  final bool flipBoard;
  final Move? animatingMove;
  final bool isAnimating;
  final Piece? animatingPiece;
  final Move? hintMove; // AI hint move to display as arrow
  final String boardSkin;
  final String pieceSkin;
  final bool showCoordinates;

  const JanggiBoardWidget({
    super.key,
    required this.board,
    this.selectedPosition,
    this.validMoves = const [],
    this.onSquareTapped,
    this.flipBoard = false,
    this.animatingMove,
    this.isAnimating = false,
    this.animatingPiece,
    this.hintMove,
    this.boardSkin = 'wood',
    this.pieceSkin = 'traditional',
    this.showCoordinates = true,
  });

  @override
  State<JanggiBoardWidget> createState() => _JanggiBoardWidgetState();
}

class _JanggiBoardWidgetState extends State<JanggiBoardWidget> {
  // Track the current animating move to detect when it changes
  Move? _currentAnimatingMove;
  bool _animationStarted = false;

  @override
  void didUpdateWidget(JanggiBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When animation starts OR when animatingMove changes to a different move
    final animationJustStarted = widget.isAnimating && !oldWidget.isAnimating;
    final animationMoveChanged = widget.isAnimating &&
        widget.animatingMove != null &&
        widget.animatingMove != _currentAnimatingMove;

    if (animationJustStarted || animationMoveChanged) {
      debugPrint(
          '[BoardWidget] Animation starting: from=${widget.animatingMove?.from} to=${widget.animatingMove?.to} piece=${widget.animatingPiece}');
      _currentAnimatingMove = widget.animatingMove;
      _animationStarted = false;
      // Trigger animation to 'to' position on next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.isAnimating &&
            widget.animatingMove == _currentAnimatingMove) {
          setState(() {
            debugPrint('[BoardWidget] Animation transition: from -> to');
            _animationStarted = true;
          });
        }
      });
    }

    // When animation ends, reset
    if (!widget.isAnimating && oldWidget.isAnimating) {
      debugPrint('[BoardWidget] Animation ended');
      _currentAnimatingMove = null;
      _animationStarted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardBaseColor = _getBoardBaseColor();
    final boardLineColor = _getBoardLineColor();
    final boardTextureOpacity = _getBoardTextureOpacity();
    final boardTextureTint = _getBoardTextureTint();

    return Container(
      decoration: BoxDecoration(
        color: boardBaseColor,
        border: Border(
          top: BorderSide(color: boardLineColor, width: 2),
          // No side borders - panels attach directly
          // No bottom border - connects to button container below
        ),
      ),
      clipBehavior: Clip.hardEdge, // Keep everything within bounds
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Add padding to keep pieces within board
          const margin = 35.0;
          final innerWidth = constraints.maxWidth - (margin * 2);
          final innerHeight = constraints.maxHeight - (margin * 2);

          // Calculate grid spacing (distance between intersection points)
          final gridSpacing = innerWidth / 8; // 8 spaces for 9 vertical lines

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              // Background image - rotated 90 degrees clockwise
              Positioned.fill(
                child: RotatedBox(
                  quarterTurns: 1, // 90 degrees clockwise
                  child: Image.asset(
                    'assets/images/janggi_pan.png',
                    fit: BoxFit.fill,
                    opacity: AlwaysStoppedAnimation(boardTextureOpacity),
                  ),
                ),
              ),
              if (boardTextureTint != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: boardTextureTint,
                  ),
                ),
              // Draw board lines with margin
              Positioned(
                left: margin,
                top: margin,
                child: CustomPaint(
                  size: Size(innerWidth, innerHeight),
                  painter: BoardLinesPainter(
                    gridSpacing: gridSpacing,
                    flipBoard: widget.flipBoard,
                    lineColor: boardLineColor,
                  ),
                ),
              ),
              if (widget.showCoordinates)
                ..._buildCoordinates(margin, gridSpacing, boardLineColor),
              // Draw interactive squares (tap areas) - centered on intersections
              ...List.generate(
                10,
                (rank) => List.generate(
                  9,
                  (file) {
                    final boardRank = widget.flipBoard ? rank : (9 - rank);
                    final boardFile = widget.flipBoard ? (8 - file) : file;
                    final position = Position(file: boardFile, rank: boardRank);

                    final tapSize = gridSpacing * 0.95;

                    return Positioned(
                      left: margin + file * gridSpacing - (tapSize / 2),
                      top: margin + rank * gridSpacing - (tapSize / 2),
                      width: tapSize,
                      height: tapSize,
                      child: GestureDetector(
                        onTap: () => widget.onSquareTapped?.call(position),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getSquareColor(position),
                            borderRadius: BorderRadius.circular(tapSize / 2),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ).expand((list) => list),

              // Draw hint arrow (if any)
              if (widget.hintMove != null)
                _buildHintArrow(margin, gridSpacing, widget.hintMove!),

              // Draw pieces EXACTLY on grid intersections
              ..._buildPieces(margin, gridSpacing),
            ],
          );
        },
      ),
    );
  }

  /// Build all pieces with animation support
  List<Widget> _buildPieces(double margin, double gridSpacing) {
    final pieces = <Widget>[];
    final pieceSize = gridSpacing * 0.9;

    // Helper function to convert board position to screen position
    Position getScreenPosition(Position boardPos) {
      if (widget.flipBoard) {
        return Position(file: 8 - boardPos.file, rank: boardPos.rank);
      } else {
        return Position(file: boardPos.file, rank: 9 - boardPos.rank);
      }
    }

    // Render all stationary pieces
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final boardPos = Position(file: file, rank: rank);
        final piece = widget.board.getPiece(boardPos);

        if (piece == null) continue;

        // Skip the piece being animated (it will be rendered separately)
        if (widget.isAnimating && widget.animatingMove != null) {
          // Skip source position (the moving piece)
          if (boardPos == widget.animatingMove!.from) {
            continue;
          }
          // Skip destination position (the piece being captured) during animation
          if (boardPos == widget.animatingMove!.to) {
            continue;
          }
        }

        final screenPos = getScreenPosition(boardPos);

        // Check if this piece is selected
        final isSelected = widget.selectedPosition == boardPos;
        final scale = isSelected
            ? 1.35
            : 1.0; // 35% larger when selected (picked up effect)
        final effectiveSize = pieceSize * scale;
        // Offset to lift the piece up and to the left when selected (picked up)
        final liftOffsetX = isSelected ? -gridSpacing * 0.15 : 0.0;
        final liftOffsetY = isSelected ? -gridSpacing * 0.15 : 0.0;

        // Use AnimatedPositioned ONLY for selected piece, regular Positioned for others
        if (isSelected) {
          pieces.add(
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: margin +
                  screenPos.file * gridSpacing -
                  (effectiveSize / 2) +
                  liftOffsetX,
              top: margin +
                  screenPos.rank * gridSpacing -
                  (effectiveSize / 2) +
                  liftOffsetY,
              width: effectiveSize,
              height: effectiveSize,
              child: IgnorePointer(
                child: _buildPiece(piece, pieceSize),
              ),
            ),
          );
        } else {
          pieces.add(
            Positioned(
              left: margin + screenPos.file * gridSpacing - (effectiveSize / 2),
              top: margin + screenPos.rank * gridSpacing - (effectiveSize / 2),
              width: effectiveSize,
              height: effectiveSize,
              child: IgnorePointer(
                child: _buildPiece(piece, pieceSize),
              ),
            ),
          );
        }
      }
    }

    // Render animating piece with AnimatedPositioned
    if (widget.isAnimating &&
        widget.animatingMove != null &&
        widget.animatingPiece != null) {
      // Use 'from' position initially, then 'to' after animation starts
      final targetPosition = _animationStarted
          ? widget.animatingMove!.to
          : widget.animatingMove!.from;
      final targetScreen = getScreenPosition(targetPosition);

      pieces.add(
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left: margin + targetScreen.file * gridSpacing - (pieceSize / 2),
          top: margin + targetScreen.rank * gridSpacing - (pieceSize / 2),
          width: pieceSize,
          height: pieceSize,
          child: IgnorePointer(
            child: _buildPiece(widget.animatingPiece!, pieceSize),
          ),
        ),
      );
    }

    return pieces;
  }

  List<Widget> _buildCoordinates(
    double margin,
    double gridSpacing,
    Color lineColor,
  ) {
    final labels = <Widget>[];
    final textStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: lineColor.withValues(alpha: 0.75),
    );

    for (int screenFile = 0; screenFile < 9; screenFile++) {
      final label = widget.flipBoard
          ? (9 - screenFile).toString()
          : (screenFile + 1).toString();
      final left = margin + screenFile * gridSpacing - 4;
      labels.add(
        Positioned(
          left: left,
          top: 8,
          child: Text(label, style: textStyle),
        ),
      );
      labels.add(
        Positioned(
          left: left,
          bottom: 8,
          child: Text(label, style: textStyle),
        ),
      );
    }

    for (int screenRank = 0; screenRank < 10; screenRank++) {
      final label = widget.flipBoard
          ? (screenRank + 1).toString()
          : (10 - screenRank).toString();
      final top = margin + screenRank * gridSpacing - 7;
      labels.add(
        Positioned(
          left: 8,
          top: top,
          child: Text(label, style: textStyle),
        ),
      );
      labels.add(
        Positioned(
          right: 8,
          top: top,
          child: Text(label, style: textStyle),
        ),
      );
    }

    return labels;
  }

  Color _getBoardBaseColor() {
    switch (widget.boardSkin) {
      case 'dark':
        return const Color(0xFF4A3A2A);
      case 'classic':
        return const Color(0xFFDFC29B);
      case 'wood':
      default:
        return const Color(0xFFE6C8A0);
    }
  }

  Color _getBoardLineColor() {
    switch (widget.boardSkin) {
      case 'dark':
        return const Color(0xFFF2E9D8);
      case 'classic':
        return const Color(0xFF2A211B);
      case 'wood':
      default:
        return Colors.black;
    }
  }

  double _getBoardTextureOpacity() {
    switch (widget.boardSkin) {
      case 'dark':
        return 0.45;
      case 'classic':
        return 0.75;
      case 'wood':
      default:
        return 0.8;
    }
  }

  Color? _getBoardTextureTint() {
    switch (widget.boardSkin) {
      case 'dark':
        return const Color(0x66000000);
      case 'classic':
      case 'wood':
      default:
        return null;
    }
  }

  Color? _getSquareColor(Position position) {
    // Only show highlight for valid move positions, not the selected piece
    if (widget.validMoves.contains(position)) {
      return Colors.yellow.withValues(alpha: 0.3); // Valid move cells
    }
    return Colors.transparent;
  }

  Widget _buildPiece(Piece piece, double size) {
    if (widget.pieceSkin == 'modern') {
      return _buildModernPiece(piece, size * 0.8);
    }
    return TraditionalPieceWidget(
      piece: piece,
      size: size * 0.85,
    );
  }

  Widget _buildModernPiece(Piece piece, double size) {
    final isBlue = piece.color == PieceColor.blue;
    final borderColor =
        isBlue ? const Color(0xFF4A7BC8) : const Color(0xFFB04848);
    final fillColor =
        isBlue ? const Color(0xFFEAF2FF) : const Color(0xFFFFEFEF);
    final label = _pieceShortLabel(piece.type);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(1.5, 1.5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: borderColor,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.38,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _pieceShortLabel(PieceType type) {
    switch (type) {
      case PieceType.general:
        return 'K';
      case PieceType.guard:
        return 'G';
      case PieceType.horse:
        return 'H';
      case PieceType.elephant:
        return 'E';
      case PieceType.chariot:
        return 'R';
      case PieceType.cannon:
        return 'C';
      case PieceType.soldier:
        return 'P';
    }
  }
}

/// Custom painter for board lines and palace diagonals
class BoardLinesPainter extends CustomPainter {
  final double gridSpacing;
  final bool flipBoard;
  final Color lineColor;

  BoardLinesPainter({
    required this.gridSpacing,
    required this.flipBoard,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw horizontal lines (10 lines for 10 ranks: 0-9)
    for (int rank = 0; rank < 10; rank++) {
      final y = rank * gridSpacing;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw vertical lines (9 lines for 9 files: 0-8)
    for (int file = 0; file < 9; file++) {
      final x = file * gridSpacing;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw palace diagonals
    _drawPalaceDiagonals(canvas, paint);
  }

  void _drawPalaceDiagonals(Canvas canvas, Paint paint) {
    // Red palace (bottom) diagonals
    final redPalaceBaseRank = flipBoard ? 7 : 0;
    _drawDiagonalLines(
      canvas,
      paint,
      baseRank: redPalaceBaseRank,
      isFlipped: flipBoard,
    );

    // Blue palace (top) diagonals
    final bluePalaceBaseRank = flipBoard ? 0 : 7;
    _drawDiagonalLines(
      canvas,
      paint,
      baseRank: bluePalaceBaseRank,
      isFlipped: flipBoard,
    );
  }

  void _drawDiagonalLines(
    Canvas canvas,
    Paint paint, {
    required int baseRank,
    required bool isFlipped,
  }) {
    // Files 3-5, ranks baseRank to baseRank+2
    final leftFile = 3.0;
    final rightFile = 5.0;
    final topRank = (isFlipped ? baseRank : baseRank).toDouble();
    final bottomRank = (isFlipped ? baseRank + 2 : baseRank + 2).toDouble();

    // Draw X in the palace
    canvas.drawLine(
      Offset(leftFile * gridSpacing, topRank * gridSpacing),
      Offset(rightFile * gridSpacing, bottomRank * gridSpacing),
      paint,
    );
    canvas.drawLine(
      Offset(rightFile * gridSpacing, topRank * gridSpacing),
      Offset(leftFile * gridSpacing, bottomRank * gridSpacing),
      paint,
    );
  }

  @override
  bool shouldRepaint(BoardLinesPainter oldDelegate) =>
      gridSpacing != oldDelegate.gridSpacing ||
      flipBoard != oldDelegate.flipBoard ||
      lineColor != oldDelegate.lineColor;
}

/// Extension for _JanggiBoardWidgetState to add hint arrow
extension on _JanggiBoardWidgetState {
  /// Build hint arrow overlay
  Widget _buildHintArrow(double margin, double gridSpacing, Move move) {
    return CustomPaint(
      painter: HintArrowPainter(
        from: move.from,
        to: move.to,
        margin: margin,
        gridSpacing: gridSpacing,
        flipBoard: widget.flipBoard,
      ),
    );
  }
}

/// Painter for hint arrow
class HintArrowPainter extends CustomPainter {
  final Position from;
  final Position to;
  final double margin;
  final double gridSpacing;
  final bool flipBoard;

  HintArrowPainter({
    required this.from,
    required this.to,
    required this.margin,
    required this.gridSpacing,
    required this.flipBoard,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Convert positions to screen coordinates
    final fromOffset = _positionToOffset(from);
    final toOffset = _positionToOffset(to);

    // Draw arrow
    final paint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.85)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw line
    canvas.drawLine(fromOffset, toOffset, paint);

    // Draw arrowhead
    const arrowSize = 20.0;
    final angle = (toOffset - fromOffset).direction;
    final arrowPath = Path()
      ..moveTo(toOffset.dx, toOffset.dy)
      ..lineTo(
        toOffset.dx - arrowSize * cos(angle - 0.4),
        toOffset.dy - arrowSize * sin(angle - 0.4),
      )
      ..lineTo(
        toOffset.dx - arrowSize * cos(angle + 0.4),
        toOffset.dy - arrowSize * sin(angle + 0.4),
      )
      ..close();

    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = Colors.yellow.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );
  }

  Offset _positionToOffset(Position pos) {
    // Match the same coordinate transformation as piece rendering
    int displayFile = flipBoard ? 8 - pos.file : pos.file;
    int displayRank = flipBoard ? pos.rank : 9 - pos.rank;

    return Offset(
      margin + displayFile * gridSpacing,
      margin + displayRank * gridSpacing,
    );
  }

  @override
  bool shouldRepaint(HintArrowPainter oldDelegate) {
    return from != oldDelegate.from ||
        to != oldDelegate.to ||
        gridSpacing != oldDelegate.gridSpacing ||
        flipBoard != oldDelegate.flipBoard;
  }
}
