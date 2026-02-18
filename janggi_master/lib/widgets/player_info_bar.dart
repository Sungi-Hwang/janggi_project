import 'package:flutter/material.dart';
import '../models/piece.dart';
import 'traditional_piece_widget.dart';

class PlayerInfoBar extends StatelessWidget {
  final String name;
  final bool isTop; 
  final List<Piece> capturedPieces;
  final PieceColor pieceColor; 
  final VoidCallback? onTap;

  const PlayerInfoBar({
    super.key,
    required this.name,
    required this.isTop,
    required this.capturedPieces,
    required this.pieceColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.black.withOpacity(0.05),
        child: Row(
          children: isTop ? [
            _buildAvatar(),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                name, 
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)
              ),
            ),
            const Spacer(),
            _buildSummary(),
          ] : [
            _buildSummary(),
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                name, 
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)
              ),
            ),
            const SizedBox(width: 4),
            _buildAvatar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    int countCar = 0;
    int countSang = 0;
    int countMa = 0;
    int countPo = 0;
    int countSa = 0;
    int countJol = 0;
    
    for (var p in capturedPieces) {
      switch (p.type) {
        case PieceType.chariot: countCar++; break;
        case PieceType.elephant: countSang++; break;
        case PieceType.horse: countMa++; break;
        case PieceType.cannon: countPo++; break;
        case PieceType.guard: countSa++; break;
        case PieceType.soldier: countJol++; break;
        default: break;
      }
    }

    final piecesToShow = [
      MapEntry(PieceType.chariot, countCar),
      MapEntry(PieceType.elephant, countSang),
      MapEntry(PieceType.horse, countMa),
      MapEntry(PieceType.cannon, countPo),
      MapEntry(PieceType.guard, countSa),
      MapEntry(PieceType.soldier, countJol),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: piecesToShow.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: _buildPieceCount(entry.key, entry.value),
        );
      }).toList(),
    );
  }

  Widget _buildPieceCount(PieceType type, int count) {
    final piece = Piece(type: type, color: pieceColor);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: TraditionalPieceWidget(
            piece: piece,
            size: 22,
          ),
        ),
        const SizedBox(width: 1),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: count > 0 ? Colors.black87 : Colors.black12,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 12,
      backgroundColor: isTop ? Colors.red.shade100 : Colors.blue.shade100,
      child: Icon(
        Icons.person, 
        size: 14, 
        color: isTop ? Colors.red.shade700 : Colors.blue.shade700
      ),
    );
  }
}
