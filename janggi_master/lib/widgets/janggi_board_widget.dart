import 'package:flutter/material.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';

/// Widget that renders the Janggi board
class JanggiBoardWidget extends StatelessWidget {
  final Board board;
  final Position? selectedPosition;
  final List<Position> validMoves;
  final Function(Position)? onSquareTapped;
  final bool flipBoard;

  const JanggiBoardWidget({
    super.key,
    required this.board,
    this.selectedPosition,
    this.validMoves = const [],
    this.onSquareTapped,
    this.flipBoard = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 8 / 9, // Janggi board is 9 files x 10 ranks (8 squares x 9 squares)
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE6C8A0),
          border: Border.all(color: Colors.black, width: 2),
        ),
        clipBehavior: Clip.none, // Allow pieces to extend beyond board edges
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate grid spacing (distance between intersection points)
            final gridSpacing = constraints.maxWidth / 8; // 8 spaces for 9 vertical lines
            return Stack(
              clipBehavior: Clip.none, // Allow pieces to extend beyond bounds
              children: [
                // Draw board lines
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: BoardLinesPainter(
                    gridSpacing: gridSpacing,
                    flipBoard: flipBoard,
                  ),
                ),
                // Draw interactive squares (tap areas) - centered on intersections
                ...List.generate(
                  10,
                  (rank) => List.generate(
                    9,
                    (file) {
                      // Red is at bottom (rank 0-3), Blue at top (rank 6-9)
                      // Screen rank 0 (top) = board rank 9, screen rank 9 (bottom) = board rank 0
                      final boardRank = flipBoard ? rank : (9 - rank);
                      final boardFile = flipBoard ? (8 - file) : file;
                      final position = Position(file: boardFile, rank: boardRank);

                      final tapSize = gridSpacing * 0.95;

                      return Positioned(
                        left: file * gridSpacing - (tapSize / 2),
                        top: rank * gridSpacing - (tapSize / 2),
                        width: tapSize,
                        height: tapSize,
                        child: GestureDetector(
                          onTap: () => onSquareTapped?.call(position),
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
                ...List.generate(
                  10,
                  (rank) => List.generate(
                    9,
                    (file) {
                      final boardRank = flipBoard ? rank : (9 - rank);
                      final boardFile = flipBoard ? (8 - file) : file;
                      final position = Position(file: boardFile, rank: boardRank);
                      final piece = board.getPiece(position);

                      if (piece == null) return const SizedBox.shrink();

                      // Place piece centered on intersection point
                      final pieceSize = gridSpacing * 0.9;

                      return Positioned(
                        left: file * gridSpacing - (pieceSize / 2),
                        top: rank * gridSpacing - (pieceSize / 2),
                        width: pieceSize,
                        height: pieceSize,
                        child: IgnorePointer(
                          child: _buildPiece(piece, pieceSize),
                        ),
                      );
                    },
                  ),
                ).expand((list) => list),
              ],
            );
          },
        ),
      ),
    );
  }

  Color? _getSquareColor(Position position) {
    if (selectedPosition == position) {
      return Colors.yellow.withAlpha(200);
    }
    if (validMoves.contains(position)) {
      return Colors.green.withAlpha(150);
    }
    return Colors.transparent;
  }

  Widget _buildPiece(Piece piece, double size) {
    return Center(
      child: Container(
        width: size * 0.85,
        height: size * 0.85,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: piece.color == PieceColor.red
              ? const Color(0xFFFFE0E0)
              : const Color(0xFFE0E0FF),
          border: Border.all(
            color: piece.color == PieceColor.red
                ? const Color(0xFFD00000)
                : const Color(0xFF0000D0),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(76),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            piece.character,
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.bold,
              color: piece.color == PieceColor.red
                  ? const Color(0xFFD00000)
                  : const Color(0xFF0000D0),
            ),
          ),
        ),
      ),
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
