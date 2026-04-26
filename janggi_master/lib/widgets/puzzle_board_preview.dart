import 'package:flutter/material.dart';

import '../models/piece.dart';
import '../models/position.dart';
import '../utils/puzzle_share_codec.dart';

class PuzzleBoardPreview extends StatelessWidget {
  const PuzzleBoardPreview({
    super.key,
    required this.fen,
    this.flipBoard = false,
  });

  final String fen;
  final bool flipBoard;

  @override
  Widget build(BuildContext context) {
    final board = PuzzleShareCodec.parseFenBoard(fen);
    if (board == null) {
      return _PreviewFrame(
        child: Icon(
          Icons.grid_off,
          color: Colors.grey.shade600,
        ),
      );
    }

    return _PreviewFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / 9;
          final cellHeight = constraints.maxHeight / 10;
          final tokenSize =
              (cellWidth < cellHeight ? cellWidth : cellHeight) * 0.78;

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _PreviewBoardPainter()),
              ),
              for (int rank = 0; rank < 10; rank++)
                for (int file = 0; file < 9; file++)
                  Builder(
                    builder: (context) {
                      final pos = Position(file: file, rank: rank);
                      final piece = board.getPiece(pos);
                      if (piece == null) {
                        return const SizedBox.shrink();
                      }

                      final displayFile = flipBoard ? 8 - file : file;
                      final displayRank = flipBoard ? rank : 9 - rank;
                      return Positioned(
                        left: displayFile * cellWidth +
                            (cellWidth - tokenSize) / 2,
                        top: displayRank * cellHeight +
                            (cellHeight - tokenSize) / 2,
                        width: tokenSize,
                        height: tokenSize,
                        child: _PreviewPiece(piece: piece),
                      );
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 10,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE5C287),
          border: Border.all(color: Colors.brown.shade700, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.hardEdge,
        child: child,
      ),
    );
  }
}

class _PreviewBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown.shade800.withValues(alpha: 0.72)
      ..strokeWidth = 0.8;
    final cellWidth = size.width / 9;
    final cellHeight = size.height / 10;

    for (int file = 0; file < 9; file++) {
      final x = file * cellWidth + cellWidth / 2;
      canvas.drawLine(
        Offset(x, cellHeight / 2),
        Offset(x, size.height - cellHeight / 2),
        paint,
      );
    }
    for (int rank = 0; rank < 10; rank++) {
      final y = rank * cellHeight + cellHeight / 2;
      canvas.drawLine(
        Offset(cellWidth / 2, y),
        Offset(size.width - cellWidth / 2, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PreviewPiece extends StatelessWidget {
  const _PreviewPiece({required this.piece});

  final Piece piece;

  @override
  Widget build(BuildContext context) {
    final isBlue = piece.color == PieceColor.blue;
    final color = isBlue ? Colors.blue.shade800 : Colors.red.shade800;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            _labelFor(piece),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  String _labelFor(Piece piece) {
    switch (piece.type) {
      case PieceType.general:
        return piece.color == PieceColor.blue ? '楚' : '漢';
      case PieceType.guard:
        return '士';
      case PieceType.horse:
        return '馬';
      case PieceType.elephant:
        return '象';
      case PieceType.chariot:
        return '車';
      case PieceType.cannon:
        return '包';
      case PieceType.soldier:
        return piece.color == PieceColor.blue ? '卒' : '兵';
    }
  }
}
