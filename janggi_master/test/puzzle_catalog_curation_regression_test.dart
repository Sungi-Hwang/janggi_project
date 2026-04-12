import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('curated puzzle catalog removes no-escape-incompatible puzzles', () {
    final file = File('assets/puzzles/puzzles.json');
    expect(file.existsSync(), isTrue);

    final raw = file.readAsStringSync(encoding: utf8);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final puzzles = List<Map<String, dynamic>>.from(
      (data['puzzles'] as List<dynamic>).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final byId = {
      for (final puzzle in puzzles) puzzle['id'] as String: puzzle,
    };

    for (final id in const [
      'm1_45',
      'm1_50',
      'm1_54',
      'm1_67',
      'm1_71',
      'm1_115',
      'm1_117',
      'm1_158',
      'm1_162',
      'm1_176',
      'm1_196',
      'm1_198',
      'm1_213',
      'm1_217',
      'm1_228',
      'm1_246',
      'm2_15',
      'm2_33',
      'm2_42',
      'm2_50',
      'm2_53',
      'm2_60',
    ]) {
      expect(
        byId.containsKey(id),
        isFalse,
        reason: 'Puzzle $id should be removed from the shared catalog',
      );
    }
  });
}
