import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:janggi_master/services/puzzle_progress_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PuzzleProgressService', () {
    test('records solved and failed attempts with timestamps', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final failedAt = DateTime.utc(2026, 4, 12, 8, 0, 0);
      final solvedAt = DateTime.utc(2026, 4, 12, 8, 5, 0);

      await PuzzleProgressService.recordFailedAttempt(
        'm1_01',
        completedAt: failedAt,
      );
      await PuzzleProgressService.recordSolvedAttempt(
        'm1_01',
        completedAt: solvedAt,
      );

      final snapshot = await PuzzleProgressService.loadSnapshot();
      final entry = snapshot.entryFor('m1_01');

      expect(entry.attempts, 2);
      expect(entry.solvedCount, 1);
      expect(entry.failedCount, 1);
      expect(entry.isSolved, isTrue);
      expect(entry.firstSolvedAt, solvedAt);
      expect(entry.lastSolvedAt, solvedAt);
      expect(entry.lastAttemptedAt, solvedAt);
      expect(snapshot.solvedPuzzleIds, contains('m1_01'));
    });

    test('migrates legacy solved ids into the new progress snapshot', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'solved_puzzle_ids': <String>['m1_02', 'm2_04'],
      });

      final snapshot = await PuzzleProgressService.loadSnapshot();

      expect(snapshot.solvedPuzzleIds, containsAll(<String>['m1_02', 'm2_04']));
      expect(snapshot.entryFor('m1_02').attempts, 1);
      expect(snapshot.entryFor('m1_02').solvedCount, 1);
      expect(snapshot.entryFor('m2_04').attempts, 1);
      expect(snapshot.entryFor('m2_04').solvedCount, 1);
    });
  });
}
