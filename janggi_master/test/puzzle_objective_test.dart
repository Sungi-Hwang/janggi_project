import 'package:flutter_test/flutter_test.dart';

import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/puzzle_objective.dart';

void main() {
  group('PuzzleObjective', () {
    test('defaults legacy puzzles to mate', () {
      final puzzle = <String, dynamic>{
        'mateIn': 2,
        'solution': <String>['a1a2', 'a10a9', 'a2a3'],
      };

      expect(PuzzleObjective.typeOf(puzzle), PuzzleObjective.mate);
      expect(PuzzleObjective.objectiveOf(puzzle), isEmpty);
      expect(PuzzleObjective.playerMoveCount(puzzle), 2);
    });

    test('normalizes material gain objective', () {
      final puzzle = PuzzleObjective.normalizePuzzleMap(<String, dynamic>{
        'objectiveType': PuzzleObjective.materialGain,
        'objective': <String, dynamic>{
          'targetPieceTypes': <String>['chariot', 'general'],
          'maxPlayerMoves': 2,
        },
        'solution': <String>['a1a2', 'a10a9', 'a2a3'],
      });

      expect(puzzle['objectiveType'], PuzzleObjective.materialGain);
      expect(puzzle['objective']['targetPieceTypes'], <String>['chariot']);
      expect(puzzle['objective']['minNetMaterialGainCp'], 450);
      expect(PuzzleObjective.displayLabelForPuzzle(puzzle), '차 획득');
    });

    test('evaluates material gain with target capture and net gain', () {
      final result = PuzzleObjective.evaluateMaterialGain(
        objective: <String, dynamic>{
          'targetPieceTypes': <String>['cannon'],
          'minNetMaterialGainCp': 300,
          'verifiedFinalEvalCp': 320,
          'verifiedEvalGainCp': 180,
        },
        playerColor: PieceColor.blue,
        capturedByBlue: const <Piece>[
          Piece(type: PieceType.cannon, color: PieceColor.red),
        ],
        capturedByRed: const <Piece>[
          Piece(type: PieceType.soldier, color: PieceColor.blue),
        ],
      );

      expect(result.success, isTrue);
      expect(result.netMaterialGainCp, 400);
      expect(result.message, contains('포 획득 성공'));
    });

    test('rejects captures that lose the material back immediately', () {
      final result = PuzzleObjective.evaluateMaterialGain(
        objective: <String, dynamic>{
          'targetPieceTypes': <String>['chariot'],
          'minNetMaterialGainCp': 450,
          'verifiedFinalEvalCp': 260,
          'verifiedEvalGainCp': 160,
        },
        playerColor: PieceColor.blue,
        capturedByBlue: const <Piece>[
          Piece(type: PieceType.chariot, color: PieceColor.red),
        ],
        capturedByRed: const <Piece>[
          Piece(type: PieceType.chariot, color: PieceColor.blue),
        ],
      );

      expect(result.success, isFalse);
      expect(result.hasTargetCapture, isTrue);
      expect(result.netMaterialGainCp, 0);
      expect(result.message, contains('순이득이 부족'));
    });
  });
}
