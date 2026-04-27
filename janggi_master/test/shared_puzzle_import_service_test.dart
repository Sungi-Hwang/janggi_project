import 'package:flutter_test/flutter_test.dart';

import 'package:janggi_master/services/custom_puzzle_service.dart';
import 'package:janggi_master/services/shared_puzzle_import_service.dart';
import 'package:janggi_master/utils/puzzle_share_codec.dart';

void main() {
  group('SharedPuzzleImportService', () {
    test('builds an imported puzzle from a full share code', () {
      final shareCode = PuzzleShareCodec.encodePuzzle(<String, dynamic>{
        'title': 'Shared puzzle',
        'fen': '4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1',
        'solution': <String>['e1e2'],
        'mateIn': 1,
        'toMove': 'blue',
      });

      final decoded = SharedPuzzleImportService.decodeShareCode(shareCode);
      final puzzle = SharedPuzzleImportService.buildImportedPuzzle(decoded);

      expect((puzzle['id'] as String).startsWith('imported_'), isTrue);
      expect(
        puzzle['libraryType'],
        CustomPuzzleService.libraryTypeImported,
      );
      expect(
        puzzle['importSource'],
        CustomPuzzleService.importSourceShareCode,
      );
      expect(puzzle['solution'], <String>['e1e2']);
      expect(puzzle['toMove'], 'blue');
    });

    test('rejects setup-only share codes for imported puzzles', () {
      final shareCode = PuzzleShareCodec.encodeSetup(
        title: 'Setup only',
        fen: '4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1',
        toMove: 'blue',
      );

      final decoded = SharedPuzzleImportService.decodeShareCode(shareCode);

      expect(
        () => SharedPuzzleImportService.buildImportedPuzzle(decoded),
        throwsA(
          isA<SharedPuzzleImportException>().having(
            (error) => error.message,
            'message',
            contains('정답 수순'),
          ),
        ),
      );
    });

    test('preserves material gain objective in v2 share codes', () {
      final shareCode = PuzzleShareCodec.encodePuzzle(<String, dynamic>{
        'title': 'Win a cannon',
        'fen': '4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1',
        'solution': <String>['e1e2'],
        'mateIn': 1,
        'toMove': 'blue',
        'objectiveType': 'material_gain',
        'objective': <String, dynamic>{
          'targetPieceTypes': <String>['cannon'],
          'maxPlayerMoves': 1,
          'minNetMaterialGainCp': 300,
        },
      });

      expect(shareCode.startsWith(PuzzleShareCodec.prefixV2), isTrue);

      final decoded = SharedPuzzleImportService.decodeShareCode(shareCode);
      final puzzle = SharedPuzzleImportService.buildImportedPuzzle(decoded);

      expect(puzzle['objectiveType'], 'material_gain');
      expect(puzzle['objective']['targetPieceTypes'], <String>['cannon']);
      expect(puzzle['objective']['minNetMaterialGainCp'], 300);
    });
  });
}
