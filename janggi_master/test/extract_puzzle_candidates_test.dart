import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/utils/gib_parser.dart';

import '../tool/extract_puzzle_candidates.dart' as extractor;

void main() {
  test('extracts validator-compatible candidate JSON from normalized corpus', () async {
    final tempRoot = Directory.systemTemp.createTempSync('janggi-corpus-root-');
    addTearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    final normalizedDir =
        Directory('${tempRoot.path}${Platform.pathSeparator}normalized')
          ..createSync(recursive: true);

    final bytes = File('dev/test_tmp/kja_83.bin').readAsBytesSync();
    final games = GibParser.parseNormalizedGamesFromBytes(
      bytes,
      sourceId: 'kja_pds:83',
      sourceType: 'kja_pds',
      sourceUrl: 'https://koreajanggi.cafe24.com/data_room/data.php?show=view&id=83&offset=0&board=pds',
      localPath: r'C:\fixtures\kja_83.bin',
      downloadUrl:
          'https://koreajanggi.cafe24.com/board/down.php?board=pds&id=83&cnt=1',
    );

    final normalizedFile =
        File('${normalizedDir.path}${Platform.pathSeparator}kja_pds.jsonl');
    normalizedFile.writeAsStringSync(
      games.map((game) => jsonEncode(game.toJson())).join('\n'),
      encoding: utf8,
    );

    final outputPath =
        '${tempRoot.path}${Platform.pathSeparator}out${Platform.pathSeparator}puzzle_candidates.json';
    await extractor.main(<String>[
      '--root',
      tempRoot.path,
      '--output',
      outputPath,
      '--limit-games',
      '1',
    ]);

    final outputFile = File(outputPath);
    expect(outputFile.existsSync(), isTrue);

    final doc =
        jsonDecode(outputFile.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
    final puzzles = List<Map<String, dynamic>>.from(
      (doc['puzzles'] as List<dynamic>).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

    expect(doc['total'], puzzles.length);
    expect(puzzles, isNotEmpty);

    final movePattern =
        RegExp(r'^[a-i](?:10|[0-9])[a-i](?:10|[0-9])$');

    for (final puzzle in puzzles.take(5)) {
      expect(puzzle['id'], isA<String>());
      expect(puzzle['title'], isA<String>());
      expect(puzzle['mateIn'], anyOf(1, 2, 3));
      expect(puzzle['fen'], isA<String>());
      final solution = List<String>.from(puzzle['solution'] as List<dynamic>);
      expect(solution, isNotEmpty);
      for (final move in solution) {
        expect(movePattern.hasMatch(move), isTrue,
            reason: 'Expected UCI-style move, got $move');
      }
    }
  });
}
