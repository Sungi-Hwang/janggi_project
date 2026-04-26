import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/utils/gib_parser.dart';

import '../tool/gib_corpus_support.dart';

void main() {
  test('parses KJA data room list HTML for recent posts', () {
    final fixture = File('dev/test_tmp/koreajanggi_data_room.html');
    expect(fixture.existsSync(), isTrue);

    final html = GibParser.decodeBytes(
      fixture.readAsBytesSync(),
      sourceLabel: fixture.path,
    ).text;
    final posts = parseKjaPdsListHtml(html);

    expect(posts, isNotEmpty);
    final ids = posts.map((post) => post.id).toSet();
    expect(ids, contains(83));
    expect(ids, contains(78));
    expect(ids, contains(73));
  });

  test('parses KJA post HTML and extracts GIB attachment metadata', () {
    final fixture = File('dev/test_tmp/koreajanggi_post_83.html');
    expect(fixture.existsSync(), isTrue);

    final html = GibParser.decodeBytes(
      fixture.readAsBytesSync(),
      sourceLabel: fixture.path,
    ).text;
    final page = parseKjaPdsPostHtml(
      html,
      viewUrl:
          'https://koreajanggi.cafe24.com/data_room/data.php?show=view&id=83&offset=0&board=pds',
    );

    expect(page.title, isNotEmpty);
    expect(page.postedDate, isNotEmpty);
    expect(page.attachments, isNotEmpty);
    final attachment = page.attachments.first;
    expect(attachment.fileName.toLowerCase(), endsWith('.gib'));
    expect(attachment.downloadUrl, contains('board/down.php'));
  });

  test('scans manual drop folder for gib and text files only', () {
    final tempDir = Directory.systemTemp.createTempSync('janggi-manual-drop-');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    File('${tempDir.path}${Platform.pathSeparator}sample1.gib')
        .writeAsStringSync('dummy');
    File('${tempDir.path}${Platform.pathSeparator}sample2.txt')
        .writeAsStringSync('dummy');
    File('${tempDir.path}${Platform.pathSeparator}sample3.gib.txt')
        .writeAsStringSync('dummy');
    File('${tempDir.path}${Platform.pathSeparator}ignore.md')
        .writeAsStringSync('dummy');

    final files = scanManualDropFiles(tempDir);
    final names = files
        .map((file) => file.uri.pathSegments.last)
        .toList(growable: false);

    expect(names, contains('sample1.gib'));
    expect(names, contains('sample2.txt'));
    expect(names, contains('sample3.gib.txt'));
    expect(names, isNot(contains('ignore.md')));
  });
}
