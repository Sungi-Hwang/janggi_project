import 'package:flutter/material.dart';

import '../models/piece.dart';
import '../theme/janggi_skin.dart';
import 'traditional_piece_widget.dart';

/// Panel showing captured pieces for one side.
class CapturedPiecesPanel extends StatelessWidget {
  final List<Piece> capturedPieces;
  final String backgroundImage;
  final double boardWidth;
  final bool isOverlay;
  final String pieceSkin;

  const CapturedPiecesPanel({
    super.key,
    required this.capturedPieces,
    required this.backgroundImage,
    required this.boardWidth,
    this.isOverlay = false,
    this.pieceSkin = JanggiSkin.pieceTraditional,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, int> pieceCounts = {};
    final Map<String, Piece> pieceExamples = {};

    for (final piece in capturedPieces) {
      final key = '${piece.type.name}_${piece.color.name}';
      pieceCounts[key] = (pieceCounts[key] ?? 0) + 1;
      pieceExamples[key] = piece;
    }

    final keys = pieceCounts.keys.toList();

    const boardMargin = 35.0;
    final boardInnerWidth = boardWidth - (boardMargin * 2);
    final gridSpacing = boardInnerWidth / 8;
    final pieceSize = isOverlay ? 60.0 : gridSpacing * 0.85;

    if (isOverlay) {
      if (keys.isEmpty) {
        return const Center(
          child: Text(
            '잡은 기물이 없습니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        );
      }
      return Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: keys.map((key) {
            final piece = pieceExamples[key]!;
            final count = pieceCounts[key]!;
            return _buildCapturedPieceIcon(piece, count, pieceSize);
          }).toList(),
        ),
      );
    }

    final isHan = backgroundImage.contains('한');
    final title = isHan ? '漢' : '楚';
    final titleColor =
        isHan ? const Color(0xFFCC0000) : const Color(0xFF0066CC);

    return Stack(
      children: [
        Positioned.fill(
          child: RotatedBox(
            quarterTurns: 1,
            child: Image.asset(
              'assets/images/janggi_pan.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.9),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.25),
                ],
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withValues(alpha: 0.6),
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.black.withValues(alpha: 0.6),
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 0),
                        blurRadius: 8,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      Shadow(
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: keys.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: keys.length,
                        itemBuilder: (context, index) {
                          final key = keys[index];
                          final piece = pieceExamples[key]!;
                          final count = pieceCounts[key]!;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 4,
                            ),
                            child: _buildCapturedPieceIcon(
                              piece,
                              count,
                              pieceSize,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCapturedPieceIcon(Piece piece, int count, double pieceSize) {
    return Stack(
      alignment: Alignment.center,
      children: [
        TraditionalPieceWidget(
          piece: piece,
          size: pieceSize,
          skin: pieceSkin,
        ),
        if (count > 1)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                'x$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
