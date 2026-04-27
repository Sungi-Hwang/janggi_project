import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:janggi_master/services/custom_puzzle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomPuzzleService', () {
    test('treats legacy puzzles without library metadata as created', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'custom_puzzles_v1': json.encode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'legacy_1',
            'title': 'Legacy puzzle',
            'fen': '4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1',
            'solution': <String>['e1e2'],
            'mateIn': 1,
            'toMove': 'blue',
            'createdAt': '2026-04-20T12:00:00.000',
          },
        ]),
      });

      final allPuzzles = await CustomPuzzleService.loadPuzzles();
      final createdPuzzles = await CustomPuzzleService.loadCreatedPuzzles();
      final importedPuzzles = await CustomPuzzleService.loadImportedPuzzles();

      expect(allPuzzles.single['libraryType'],
          CustomPuzzleService.libraryTypeCreated);
      expect(createdPuzzles.single['id'], 'legacy_1');
      expect(importedPuzzles, isEmpty);
    });

    test('stores created and imported puzzles in separate libraries', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await CustomPuzzleService.addCreatedPuzzle(<String, dynamic>{
        'title': 'My puzzle',
        'fen': '4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1',
        'solution': <String>['e1e2'],
        'mateIn': 1,
        'toMove': 'blue',
        'createdAt': '2026-04-22T10:00:00.000',
      });

      await CustomPuzzleService.addImportedPuzzle(
        <String, dynamic>{
          'title': 'Imported puzzle',
          'fen': '4k4/9/9/9/9/9/9/9/9/4K4 b - - 0 1',
          'solution': <String>['e10e9'],
          'mateIn': 1,
          'toMove': 'red',
          'createdAt': '2026-04-22T11:00:00.000',
        },
        importSource: CustomPuzzleService.importSourceCommunityPost,
      );

      final createdPuzzles = await CustomPuzzleService.loadCreatedPuzzles();
      final importedPuzzles = await CustomPuzzleService.loadImportedPuzzles();

      expect(createdPuzzles, hasLength(1));
      expect(importedPuzzles, hasLength(1));
      expect(
        (createdPuzzles.single['id'] as String).startsWith('custom_'),
        isTrue,
      );
      expect(
        (importedPuzzles.single['id'] as String).startsWith('imported_'),
        isTrue,
      );
      expect(
        createdPuzzles.single['libraryType'],
        CustomPuzzleService.libraryTypeCreated,
      );
      expect(importedPuzzles.single['libraryType'],
          CustomPuzzleService.libraryTypeImported);
      expect(
        importedPuzzles.single['importSource'],
        CustomPuzzleService.importSourceCommunityPost,
      );
    });

    test('preserves material gain objective metadata', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await CustomPuzzleService.addCreatedPuzzle(<String, dynamic>{
        'title': 'Win a chariot',
        'fen': '4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1',
        'solution': <String>['a1a2'],
        'mateIn': 1,
        'toMove': 'blue',
        'objectiveType': 'material_gain',
        'objective': <String, dynamic>{
          'targetPieceTypes': <String>['chariot'],
          'maxPlayerMoves': 1,
        },
      });

      final created = await CustomPuzzleService.loadCreatedPuzzles();
      expect(created.single['objectiveType'], 'material_gain');
      expect(
        created.single['objective']['targetPieceTypes'],
        <String>['chariot'],
      );
      expect(created.single['objective']['minNetMaterialGainCp'], 450);
    });
  });
}
