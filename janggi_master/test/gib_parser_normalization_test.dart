import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/utils/gib_parser.dart';

void main() {
  test('normalizes KJA GIB metadata and setups from raw bytes', () {
    final fixture = File('test_tmp/kja_83.bin');
    expect(fixture.existsSync(), isTrue);

    final bytes = fixture.readAsBytesSync();
    final decoded = GibParser.decodeBytes(bytes, sourceLabel: fixture.path);
    expect(decoded.encoding, 'cp949');

    final games = GibParser.parseNormalizedGamesFromBytes(
      bytes,
      sourceId: 'kja_pds:83',
      sourceType: 'kja_pds',
      sourceUrl: 'https://koreajanggi.cafe24.com/data_room/data.php?show=view&id=83&offset=0&board=pds',
      localPath: fixture.path,
      downloadUrl:
          'https://koreajanggi.cafe24.com/board/down.php?board=pds&id=83&cnt=1',
    );

    expect(games, hasLength(1));
    final game = games.first;
    expect(game.title, contains('2023'));
    expect(game.round, isNotNull);
    expect(game.round, isNotEmpty);
    expect(game.date, '2023-05-14');
    expect(game.players['blue'], isNotNull);
    expect(game.players['blue'], isNotEmpty);
    expect(game.players['red'], isNotNull);
    expect(game.players['red'], isNotEmpty);
    expect(game.setupBlue, 'horseElephantElephantHorse');
    expect(game.setupRed, 'elephantHorseElephantHorse');
    expect(game.moves, isNotEmpty);
    expect(game.moveCount, game.moves.length);
    expect(game.initialFen, isNotNull);
    expect(game.initialFen, isNotEmpty);
    expect(game.rawMetadata, isNotEmpty);
  });

  test('parses numbered move list text into a normalized game', () {
    const text = '''
[Title "manual sample"]
1. 7978 2. 1918 3. 7877
''';

    final game = GibParser.parsePlainTextMoveList(
      text,
      sourceId: 'manual:sample',
      sourceType: 'manual_drop',
      localPath: r'C:\tmp\sample.txt',
      title: 'manual sample',
      encoding: 'utf8',
    );

    expect(game.title, 'manual sample');
    expect(game.moves, <String>['7978', '1918', '7877']);
    expect(game.moveCount, 3);
  });
}
