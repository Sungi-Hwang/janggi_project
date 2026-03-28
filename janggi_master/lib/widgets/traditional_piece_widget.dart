import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/piece.dart';
import '../theme/janggi_skin.dart';

/// Traditional Janggi piece widget with selectable visual skins.
class TraditionalPieceWidget extends StatelessWidget {
  final Piece piece;
  final double size;
  final String skin;

  const TraditionalPieceWidget({
    super.key,
    required this.piece,
    required this.size,
    this.skin = JanggiSkin.pieceTraditional,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: TraditionalPiecePainter(
          piece: piece,
          size: size,
          skin: skin,
        ),
      ),
    );
  }
}

class TraditionalPiecePainter extends CustomPainter {
  final Piece piece;
  final double size;
  final String skin;

  TraditionalPiecePainter({
    required this.piece,
    required this.size,
    required this.skin,
  });

  bool get _isLegacyGoldSkin => skin == JanggiSkin.pieceLegacyGold;

  @override
  void paint(Canvas canvas, Size size) {
    if (_isLegacyGoldSkin) {
      _paintLegacyGold(canvas, size);
      return;
    }

    _paintKoreanTraditional(canvas, size);
  }

  void _paintKoreanTraditional(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = this.size * 0.42 * piece.type.faceScale;
    final isBlue = piece.color == PieceColor.blue;

    final mainColor = const Color(0xFFF3E8D2);
    final midTone = const Color(0xFFE8D4B0);
    final shadowColor = const Color(0xFFD4B184);
    final darkEdge = const Color(0xFF745536);
    final textColor = isBlue
        ? const Color(0xFF244E87)
        : const Color(0xFFA12B2F);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    _drawOctagon(
      canvas,
      center + const Offset(3, 3),
      radius * 1.01,
      Colors.transparent,
      shadowPaint,
    );

    final edgePaint = Paint()
      ..color = darkEdge
      ..style = PaintingStyle.fill;
    _drawOctagon(canvas, center + const Offset(3, 3), radius, darkEdge, edgePaint);

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [mainColor, midTone, shadowColor],
        stops: const [0.0, 0.58, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    _drawOctagon(canvas, center, radius * 0.95, mainColor, bodyPaint);

    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: center - Offset(radius * 0.3, radius * 0.3),
          radius: radius * 0.4,
        ),
      );
    canvas.drawCircle(
      center - Offset(radius * 0.3, radius * 0.3),
      radius * 0.28,
      highlightPaint,
    );

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = darkEdge.withValues(alpha: 0.28);
    _drawOctagon(canvas, center, radius * 0.88, Colors.transparent, borderPaint);

    _paintCharacter(
      canvas,
      center: center,
      textColor: textColor,
      fontSize: this.size * 0.48 * piece.type.glyphScale,
      shadows: [
        Shadow(
          color: Colors.white.withValues(alpha: 0.28),
          offset: const Offset(0.8, 0.8),
          blurRadius: 1.5,
        ),
      ],
    );
  }

  void _paintLegacyGold(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = this.size * 0.42 * piece.type.faceScale;
    final isBlue = piece.color == PieceColor.blue;

    final mainColor = const Color(0xFFFFF8DC);
    final shadowColor = const Color(0xFFD4A574);
    final darkEdge = const Color(0xFF8B6F47);
    final textColor = isBlue
        ? const Color(0xFF2E3192)
        : const Color(0xFFB8232F);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    _drawOctagon(
      canvas,
      center + const Offset(4, 4),
      radius * 1.02,
      Colors.transparent,
      shadowPaint,
    );

    final edgePaint = Paint()
      ..color = darkEdge
      ..style = PaintingStyle.fill;
    _drawOctagon(canvas, center + const Offset(3, 3), radius, darkEdge, edgePaint);

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          mainColor,
          const Color(0xFFFAEBD7),
          shadowColor,
        ],
        stops: const [0.0, 0.6, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    _drawOctagon(canvas, center, radius * 0.95, mainColor, bodyPaint);

    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: center - Offset(radius * 0.3, radius * 0.3),
          radius: radius * 0.4,
        ),
      );
    canvas.drawCircle(
      center - Offset(radius * 0.3, radius * 0.3),
      radius * 0.35,
      highlightPaint,
    );

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = textColor.withValues(alpha: 0.25);
    _drawOctagon(canvas, center, radius * 0.88, Colors.transparent, borderPaint);

    _paintCharacter(
      canvas,
      center: center,
      textColor: textColor,
      fontSize: this.size * 0.48 * piece.type.glyphScale,
      shadows: [
        Shadow(
          color: Colors.white.withValues(alpha: 0.8),
          offset: const Offset(2, 2),
          blurRadius: 3,
        ),
        Shadow(
          color: Colors.black.withValues(alpha: 0.2),
          offset: const Offset(1, 1),
          blurRadius: 2,
        ),
      ],
    );

    if (isBlue) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF4A7BC8).withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center, radius + 2, glowPaint);
    }
  }

  void _paintCharacter(
    Canvas canvas, {
    required Offset center,
    required Color textColor,
    required double fontSize,
    required List<Shadow> shadows,
  }) {
    final textSpan = TextSpan(
      text: piece.character,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: textColor,
        fontFamily: JanggiSkin.displayFontFamily,
        height: 1.0,
        shadows: shadows,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  void _drawOctagon(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, [
    Paint? customPaint,
  ]) {
    final path = Path();
    const sides = 8;
    final angleStep = (math.pi * 2) / sides;

    for (int i = 0; i < sides; i++) {
      final angle = angleStep * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = customPaint ??
        (Paint()
          ..color = color
          ..style = PaintingStyle.fill);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TraditionalPiecePainter oldDelegate) =>
      piece != oldDelegate.piece ||
      size != oldDelegate.size ||
      skin != oldDelegate.skin;
}
