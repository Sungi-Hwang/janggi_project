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
      debugPrint('[BoardWidget] Animation starting: from=${widget.animatingMove?.from} to=${widget.animatingMove?.to} piece=${widget.animatingPiece}');
      _currentAnimatingMove = widget.animatingMove;
      _animationStarted = false;
      // Trigger animation to 'to' position on next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isAnimating && widget.animatingMove == _currentAnimatingMove) {
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
    return AspectRatio(
      aspectRatio: 8 / 9, // Janggi board is 9 files x 10 ranks (8 squares x 9 squares)
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE6C8A0),
          border: Border.all(color: Colors.black, width: 2),
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
              clipBehavior: Clip.hardEdge,
              children: [
                // Background image - rotated 90 degrees clockwise
                Positioned.fill(
                  child: RotatedBox(
                    quarterTurns: 1, // 90 degrees clockwise
                    child: Image.asset(
                      'assets/images/janggi_pan.png',
                      fit: BoxFit.fill,
                      opacity: const AlwaysStoppedAnimation(0.8),
                    ),
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
                    ),
                  ),
                ),
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

                // Draw pieces EXACTLY on grid intersections
                ..._buildPieces(margin, gridSpacing),
              ],
            );
          },
        ),
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

        pieces.add(
          Positioned(
            left: margin + screenPos.file * gridSpacing - (pieceSize / 2),
            top: margin + screenPos.rank * gridSpacing - (pieceSize / 2),
            width: pieceSize,
            height: pieceSize,
            child: IgnorePointer(
              child: _buildPiece(piece, pieceSize),
            ),
          ),
        );
      }
    }

    // Render animating piece with AnimatedPositioned
    if (widget.isAnimating && widget.animatingMove != null && widget.animatingPiece != null) {
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

  Color? _getSquareColor(Position position) {
    if (widget.selectedPosition == position) {
      return Colors.yellow.withAlpha(200);
    }
    if (widget.validMoves.contains(position)) {
      return Colors.green.withAlpha(150);
    }
    return Colors.transparent;
  }

  Widget _buildPiece(Piece piece, double size) {
    // Use traditional 3D style piece
    return TraditionalPieceWidget(
      piece: piece,
      size: size * 0.85,
    );
  }
}

/// Custom painter for board lines and palace diagonals
class BoardLinesPainter extends CustomPainter {
  final double gridSpacing;
  final bool flipBoard;

  BoardLinesPainter({
    required this.gridSpacing,
    required this.flipBoard,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
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
      gridSpacing != oldDelegate.gridSpacing || flipBoard != oldDelegate.flipBoard;
}
