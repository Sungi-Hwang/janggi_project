import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strict puzzle catalog stays internally consistent', () {
    final file = File('assets/puzzles/puzzles.json');
    expect(file.existsSync(), isTrue);

    final raw = file.readAsStringSync(encoding: utf8);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final puzzles = List<Map<String, dynamic>>.from(
      (data['puzzles'] as List<dynamic>).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final categories =
        Map<String, dynamic>.from(data['categories'] as Map<String, dynamic>);

    expect(data['total'], puzzles.length);

    final counts = <int, int>{1: 0, 2: 0, 3: 0};
    for (final puzzle in puzzles) {
      final mateIn = puzzle['mateIn'] as int;
      counts[mateIn] = (counts[mateIn] ?? 0) + 1;

      final solution = List<String>.from(puzzle['solution'] as List<dynamic>);
      expect(solution, isNotEmpty,
          reason: 'Puzzle ${puzzle['id']} has no solution');
      expect(
        solution.length,
        mateIn * 2 - 1,
        reason: 'Puzzle ${puzzle['id']} solution length does not match mateIn',
      );
      expect(
        puzzle['title'],
        startsWith('$mateIn수 외통 #'),
        reason: 'Puzzle ${puzzle['id']} title does not match mateIn',
      );

      final validation =
          Map<String, dynamic>.from(puzzle['validation'] as Map? ?? const {});
      expect(validation['strictPass'], isTrue,
          reason: 'Puzzle ${puzzle['id']} is not strictPass');
      expect(validation['uniqueFirstMove'], isTrue,
          reason: 'Puzzle ${puzzle['id']} is not uniquely solved');
      expect(validation['linePerfect'], isTrue,
          reason: 'Puzzle ${puzzle['id']} line is not engine-perfect');
      expect(validation['finalMateResolved'], isTrue,
          reason: 'Puzzle ${puzzle['id']} does not end in mate');
    }

    expect(
      categories['mate1']['count'],
      counts[1],
      reason: 'mate1 category count mismatch',
    );
    expect(
      categories['mate2']['count'],
      counts[2],
      reason: 'mate2 category count mismatch',
    );
    expect(
      categories['mate3']['count'],
      counts[3],
      reason: 'mate3 category count mismatch',
    );
  });
}
