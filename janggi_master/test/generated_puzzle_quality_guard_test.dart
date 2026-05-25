import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/utils/generated_puzzle_quality_guard.dart';

void main() {
  test('detects generated puzzles with immediate general capture', () {
    expect(
      GeneratedPuzzleQualityGuard.immediateGeneralCaptureMoves(
        fen: '8r/9/3k5/2p4p1/9/1b6P/3PP4/4C4/4Kc3/3r5 b - - 1 17',
        toMove: 'red',
      ),
      contains('d1e2'),
    );
    expect(
      GeneratedPuzzleQualityGuard.immediateGeneralCaptureMoves(
        fen: '1n1R5/1N2ka3/9/9/5p3/2N5P/P3p4/6C2/4A4/4K4 w - - 1 39',
        toMove: 'blue',
      ),
      contains('d10e9'),
    );
    expect(
      GeneratedPuzzleQualityGuard.immediateGeneralCaptureMoves(
        fen: '2b1a3r/4ka3/3Rc4/p3p1pp1/9/3N5/P7P/4C4/7c1/3AKA2R w - - 7 11',
        toMove: 'blue',
      ),
      contains('d8e9'),
    );
  });

  test('does not flag a known non-trivial generated puzzle', () {
    expect(
      GeneratedPuzzleQualityGuard.hasImmediateGeneralCapture(
        fen: '9/4a4/3a1k3/p2C2pp1/9/2b6/4p1PP1/2n6/3K5/9 b - - 5 26',
        toMove: 'red',
      ),
      isFalse,
    );
  });
}
