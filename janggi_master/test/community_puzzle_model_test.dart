import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:janggi_master/models/community_puzzle.dart';
import 'package:janggi_master/services/custom_puzzle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses community rows and builds local import metadata', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final puzzle = CommunityPuzzle.fromJson(
      <String, dynamic>{
        'id': 'post-1',
        'author_id': 'user-1',
        'title': 'Shared mate',
        'description': 'A clean two-move idea',
        'fen': '4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1',
        'solution': <String>['e1e2', 'e10e9'],
        'mate_in': 2,
        'to_move': 'blue',
        'objective_type': 'material_gain',
        'objective': <String, dynamic>{
          'targetPieceTypes': <String>['cannon'],
          'maxPlayerMoves': 2,
          'minNetMaterialGainCp': 300,
        },
        'like_count': 7,
        'import_count': 3,
        'report_count': 0,
        'created_at': '2026-04-26T12:00:00.000Z',
        'profiles': <String, dynamic>{
          'display_name': 'Maker',
          'avatar_url': 'https://example.com/avatar.png',
        },
      },
      hasLiked: true,
    );

    expect(puzzle.authorName, 'Maker');
    expect(puzzle.hasLiked, isTrue);
    expect(puzzle.solution, <String>['e1e2', 'e10e9']);
    expect(puzzle.objectiveType, 'material_gain');
    expect(puzzle.objective['targetPieceTypes'], <String>['cannon']);

    await CustomPuzzleService.addImportedPuzzle(
      <String, dynamic>{
        ...puzzle.toLocalPuzzle(),
        'id': CustomPuzzleService.nextImportedId(),
      },
      importSource: CustomPuzzleService.importSourceCommunityPost,
    );

    final imported = await CustomPuzzleService.loadImportedPuzzles();
    expect(imported, hasLength(1));
    expect(imported.single['communityPostId'], 'post-1');
    expect(imported.single['objectiveType'], 'material_gain');
    expect(
      imported.single['importSource'],
      CustomPuzzleService.importSourceCommunityPost,
    );
  });
}
