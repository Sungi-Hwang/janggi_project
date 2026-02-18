import 'package:flutter/material.dart';

/// A widget that displays the evaluation bar (Chess.com style)
class EvaluationBar extends StatelessWidget {
  final int? score; // centipawn score or mate distance
  final String? type; // 'cp' or 'mate'
  final bool isBlueTurn;
  final bool visible;

  const EvaluationBar({
    super.key,
    required this.score,
    required this.type,
    required this.isBlueTurn,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || score == null) return const SizedBox.shrink();

    // Convert relative score (side to move) to absolute score (Blue perspective)
    // Blue win = Positive, Red win = Negative
    double absoluteScore;
    String displayValue;

    if (type == 'mate') {
      // Mate distance
      int distance = score!.abs();
      bool winning = score! > 0; // Relative to current player
      bool blueWinning = isBlueTurn ? winning : !winning;

      absoluteScore = blueWinning ? 100.0 : -100.0;
      displayValue = 'M$distance';
    } else {
      // Centipawn score (100 cp = 1 point)
      double cp = score! / 100.0;
      double absCp = isBlueTurn ? cp : -cp;
      if (absCp.abs() < 0.05) absCp = 0.0;

      absoluteScore = absCp;
      displayValue =
          absCp > 0 ? '+${absCp.toStringAsFixed(1)}' : absCp.toStringAsFixed(1);
    }

    // Map score to a percentage (0.0 to 1.0)
    // 0.0 = Red winning (+10 or more), 1.0 = Blue winning (+10 or more)
    // Center (0.5) is equal.
    // We use a sigmoid-like curve or just linear clamping
    double clamped = (absoluteScore / 10.0).clamp(-1.0, 1.0);
    double percentage = (clamped + 1.0) / 2.0;

    return SizedBox(
      width: 30,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Red part (background)
            Positioned.fill(
              child: ColoredBox(color: Colors.red.shade900),
            ),

            // Blue part (relative to actual bar height)
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                heightFactor: percentage,
                widthFactor: 1.0,
                child: ColoredBox(color: Colors.blue.shade900),
              ),
            ),

            // Center mark
            const Center(
              child: Divider(color: Colors.white30, thickness: 1),
            ),

            // Value text
            Positioned(
              top: absoluteScore < 0 ? 10 : null,
              bottom: absoluteScore >= 0 ? 10 : null,
              left: 0,
              right: 0,
              child: Text(
                displayValue,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
