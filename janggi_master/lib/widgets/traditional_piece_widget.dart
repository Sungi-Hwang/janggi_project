import 'package:flutter/material.dart';
import '../models/piece.dart';
import 'dart:math' as math;

/// Traditional 3D Janggi piece widget (like the screenshot)
class TraditionalPieceWidget extends StatelessWidget {
  final Piece piece;
  final double size;

  const TraditionalPieceWidget({
    super.key,
    required this.piece,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: TraditionalPiecePainter(piece: piece, size: size),
      ),
    );
  }
}

/// Custom painter for traditional 3D Janggi pieces
class TraditionalPiecePainter extends CustomPainter {
  final Piece piece;
  final double size;

  TraditionalPiecePainter({required this.piece, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = this.size * 0.42;

    // Define colors
    final isBlue = piece.color == PieceColor.blue;

    // Main piece color - cream/beige like wood
    final mainColor = const Color(0xFFFFF8DC); // Cornsilk
    final shadowColor = const Color(0xFFD4A574); // Tan
    final darkEdge = const Color(0xFF8B6F47); // Brown for 3D edge

    // Text color - deep red for all pieces (traditional style)
    final textColor = isBlue
        ? const Color(0xFF2E3192) // Deep blue
        : const Color(0xFFB8232F); // Deep red

    // 1. Draw bottom-right shadow (3D effect)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    _drawOctagon(canvas, center + const Offset(4, 4), radius * 1.02, Colors.transparent, shadowPaint);

    // 2. Draw main octagon with 3D edge effect (right-bottom darker)
    // First, draw the 3D edge (offset octagon in dark color)
    final edgePaint = Paint()
      ..color = darkEdge
      ..style = PaintingStyle.fill;
    _drawOctagon(canvas, center + const Offset(3, 3), radius, darkEdge, edgePaint);

    // 3. Draw main octagon body with gradient
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          mainColor,
          const Color(0xFFFAEBD7), // Antique white
          shadowColor,
        ],
        stops: const [0.0, 0.6, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    _drawOctagon(canvas, center, radius * 0.95, mainColor, bodyPaint);

    // 4. Draw top-left highlight (glossy effect)
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(
        center: center - Offset(radius * 0.3, radius * 0.3),
        radius: radius * 0.4,
      ));
    canvas.drawCircle(
      center - Offset(radius * 0.3, radius * 0.3),
      radius * 0.35,
      highlightPaint,
    );

    // 5. Draw thin border around octagon
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = textColor.withValues(alpha: 0.25);
    _drawOctagon(canvas, center, radius * 0.88, Colors.transparent, borderPaint);

    // 7. Draw character with shadow
    final textSpan = TextSpan(
      text: piece.character,
      style: TextStyle(
        fontSize: this.size * 0.48,
        fontWeight: FontWeight.w900,
        color: textColor,
        fontFamily: 'serif',
        height: 1.0,
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
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );

    textPainter.paint(canvas, textOffset);

    // 8. Draw subtle outer glow for selected/special state (optional)
    if (isBlue) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF4A7BC8).withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center, radius + 2, glowPaint);
    }
  }

  /// Draw octagonal shape for traditional look
  void _drawOctagon(Canvas canvas, Offset center, double radius, Color color, [Paint? customPaint]) {
    final path = Path();
    final sides = 8;
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

    final paint = customPaint ?? (Paint()
      ..color = color
      ..style = PaintingStyle.fill);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TraditionalPiecePainter oldDelegate) =>
      piece != oldDelegate.piece || size != oldDelegate.size;
}
