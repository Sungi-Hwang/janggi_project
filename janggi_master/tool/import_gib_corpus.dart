import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:janggi_master/utils/gib_parser.dart';
import 'gib_corpus_support.dart';

Future<void> main(List<String> args) async {
  final options = _ImportOptions.parse(args);
  final paths = resolveCorpusPaths(
    rootPath: options.rootPath,
    manualDirOverride: options.manualDir,
  );
  paths.ensureExists();

  stdout.writeln('Using corpus root: ${paths.root.path}');

  final summary = <String, dynamic>{
    'root': paths.root.path,
    'startedAt': DateTime.now().toIso8601String(),
    'sources': <String, dynamic>{},
  };

  if (options.source == 'kja_pds' || options.source == 'all') {
    summary['sources']['kja_pds'] = await _runKjaImport(options, paths);
  }

  if (options.source == 'manual_drop' || options.source == 'all') {
    summary['sources']['manual_drop'] = await _runManualImport(options, paths);
  }

  summary['finishedAt'] = DateTime.now().toIso8601String();
  final summaryPath =
      '${paths.manifestDir.path}${Platform.pathSeparator}import_summary.json';
  writeJson(summaryPath, summary);
  stdout.writeln(jsonEncode(summary));
  stdout.writeln('Summary written to $summaryPath');
}

class _ImportOptions {
  _ImportOptions({
    required this.rootPath,
    required this.source,
    required this.pages,
    required this.sinceId,
    required this.manualDir,
  });

  final String? rootPath;
  final String source;
  final int pages;
  final int? sinceId;
  final String? manualDir;

  static _ImportOptions parse(List<String> args) {
    String? rootPath;
    String source = 'all';
    int pages = 1;
    int? sinceId;
    String? manualDir;

    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--root':
          rootPath = args[++i];
          break;
        case '--source':
          source = args[++i];
          break;
        case '--pages':
          pages = int.parse(args[++i]);
          break;
        case '--since-id':
          sinceId = int.parse(args[++i]);
          break;
        case '--manual-dir':
          manualDir = args[++i];
          break;
        case '--help':
        case '-h':
          _printUsage();
          exit(0);
        default:
          stderr.writeln('Unknown argument: ${args[i]}');
          _printUsage();
          exit(64);
      }
    }

    if (!const {'kja_pds', 'manual_drop', 'all'}.contains(source)) {
      stderr.writeln('Unsupported source: $source');
      _printUsage();
      exit(64);
    }

    return _ImportOptions(
      rootPath: rootPath,
      source: source,
      pages: pages,
      sinceId: sinceId,
      manualDir: manualDir,
    );
  }

  static void _printUsage() {
    stdout.writeln('''
Usage: dart run tool/import_gib_corpus.dart [options]

Options:
  --root <path>         Corpus root (default: %USERPROFILE%\\Documents\\janggi_gib_corpus)
  --source <name>       One of: kja_pds, manual_drop, all (default: all)
  --pages <n>           Number of KJA list pages to scan (default: 1)
  --since-id <n>        Skip KJA posts with id <= n
  --manual-dir <path>   Override manual drop directory
  --help                Show this help
''');
  }
}

Future<Map<String, dynamic>> _runKjaImport(
  _ImportOptions options,
  GibCorpusPaths paths,
) async {
  final manifestPath =
      '${paths.manifestDir.path}${Platform.pathSeparator}kja_pds_downloads.jsonl';
  final existingManifest = _readJsonLines(manifestPath);
  final manifestByLocalPath = <String, Map<String, dynamic>>{};

  for (final item in existingManifest) {
    final localPath = item['localPath'] as String?;
    if (localPath != null && localPath.isNotEmpty) {
      manifestByLocalPath[localPath] = item;
    }
  }

  final downloaded = <Map<String, dynamic>>[];
  final scannedPosts = <KjaPdsPostSummary>[];

  for (int page = 0; page < options.pages; page++) {
    final offset = page * 20;
    final listUri = Uri.parse(
      'https://koreajanggi.cafe24.com/data_room/data.php?board=pds&menu=&offset=$offset',
    );
    final listBytes = await _downloadBytes(listUri);
    final listHtml = GibParser.decodeBytes(listBytes, sourceLabel: '$listUri').text;
    final posts = parseKjaPdsListHtml(listHtml);
    scannedPosts.addAll(posts);
  }

  final filteredPosts = scannedPosts.where((post) {
    if (options.sinceId == null) return true;
    return post.id > options.sinceId!;
  }).toList()
    ..sort((a, b) => b.id.compareTo(a.id));

  for (final post in filteredPosts) {
    stdout.writeln('Fetching KJA post ${post.id}: ${post.title}');
    final postBytes = await _downloadBytes(Uri.parse(post.viewUrl));
    final postHtml =
        GibParser.decodeBytes(postBytes, sourceLabel: post.viewUrl).text;
    final postPage = parseKjaPdsPostHtml(postHtml, viewUrl: post.viewUrl);

    for (final attachment in postPage.attachments) {
      if (!attachment.fileName.toLowerCase().endsWith('.gib')) {
        continue;
      }

      final localFile = File(
        '${paths.kjaRawRoot.path}${Platform.pathSeparator}'
        '${post.id}__${sanitizeFileName(attachment.fileName)}',
      );

      if (!localFile.existsSync()) {
        final attachmentBytes = await _downloadBytes(Uri.parse(attachment.downloadUrl));
        localFile.parent.createSync(recursive: true);
        localFile.writeAsBytesSync(attachmentBytes, flush: true);
      }

      final manifestRecord = <String, dynamic>{
        'sourceId': 'kja_pds:${post.id}',
        'postId': post.id,
        'title': postPage.title,
        'postedDate': postPage.postedDate,
        'viewUrl': postPage.viewUrl,
        'downloadUrl': attachment.downloadUrl,
        'fileName': attachment.fileName,
        'localPath': localFile.path,
      };
      manifestByLocalPath[localFile.path] = manifestRecord;
      downloaded.add(manifestRecord);
    }
  }

  final manifestRecords = manifestByLocalPath.values.toList()
    ..sort((a, b) => (a['localPath'] as String).compareTo(b['localPath'] as String));
  writeJsonLines(manifestPath, manifestRecords);

  final normalizedRecords = <Map<String, dynamic>>[];
  for (final record in manifestRecords) {
    final localPath = record['localPath'] as String;
    final file = File(localPath);
    if (!file.existsSync()) continue;

    final bytes = file.readAsBytesSync();
    final games = GibParser.parseNormalizedGamesFromBytes(
      bytes,
      sourceId: record['sourceId'] as String,
      sourceType: 'kja_pds',
      sourceUrl: record['viewUrl'] as String?,
      localPath: localPath,
      downloadUrl: record['downloadUrl'] as String?,
    );
    normalizedRecords.addAll(games.map((game) => game.toJson()));
  }

  final normalizedPath =
      '${paths.normalizedDir.path}${Platform.pathSeparator}kja_pds.jsonl';
  writeJsonLines(normalizedPath, normalizedRecords);

  return {
    'pagesRequested': options.pages,
    'postsScanned': scannedPosts.length,
    'postsImported': filteredPosts.length,
    'attachmentsTracked': manifestRecords.length,
    'attachmentsDownloadedThisRun': downloaded.length,
    'normalizedGames': normalizedRecords.length,
    'manifestPath': manifestPath,
    'normalizedPath': normalizedPath,
  };
}

Future<Map<String, dynamic>> _runManualImport(
  _ImportOptions options,
  GibCorpusPaths paths,
) async {
  final files = scanManualDropFiles(paths.manualDropDir);
  final normalizedRecords = <Map<String, dynamic>>[];
  final skippedFiles = <String>[];

  for (final file in files) {
    final bytes = file.readAsBytesSync();
    final decoded = GibParser.decodeBytes(bytes, sourceLabel: file.path);
    final relativePath = _relativePath(file.path, paths.manualDropDir.path);
    final sourceId = 'manual:${relativePath.replaceAll(RegExp(r'[\\\\/]'), '_')}';

    if (GibParser.looksLikeGib(decoded.text)) {
      final games = GibParser.parseNormalizedGames(
        decoded.text,
        sourceId: sourceId,
        sourceType: 'manual_drop',
        sourceUrl: null,
        localPath: file.path,
        encoding: decoded.encoding,
      );
      normalizedRecords.addAll(games.map((game) => game.toJson()));
      continue;
    }

    if (GibParser.looksLikePlainTextMoveList(decoded.text)) {
      final title = sanitizeFileName(file.uri.pathSegments.isEmpty
          ? file.path
          : file.uri.pathSegments.last);
      final game = GibParser.parsePlainTextMoveList(
        decoded.text,
        sourceId: sourceId,
        sourceType: 'manual_drop',
        localPath: file.path,
        title: title,
        encoding: decoded.encoding,
      );
      normalizedRecords.add(game.toJson());
      continue;
    }

    skippedFiles.add(file.path);
  }

  final normalizedPath =
      '${paths.normalizedDir.path}${Platform.pathSeparator}manual_drop.jsonl';
  writeJsonLines(normalizedPath, normalizedRecords);

  return {
    'manualDir': paths.manualDropDir.path,
    'filesScanned': files.length,
    'normalizedGames': normalizedRecords.length,
    'skippedFiles': skippedFiles,
    'normalizedPath': normalizedPath,
  };
}

Future<List<int>> _downloadBytes(Uri uri) async {
  final client = HttpClient();
  client.userAgent = 'janggi-master/1.0 (gib-corpus-import)';
  client.connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Unexpected HTTP status ${response.statusCode} for $uri',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return bytes;
  } finally {
    client.close(force: true);
  }
}

List<Map<String, dynamic>> _readJsonLines(String path) {
  final file = File(path);
  if (!file.existsSync()) return const <Map<String, dynamic>>[];

  return file
      .readAsLinesSync(encoding: utf8)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => Map<String, dynamic>.from(jsonDecode(line) as Map))
      .toList(growable: false);
}

String _relativePath(String path, String basePath) {
  final normalizedPath = path.replaceAll('/', Platform.pathSeparator);
  final normalizedBase = basePath.replaceAll('/', Platform.pathSeparator);
  if (!normalizedPath.startsWith(normalizedBase)) {
    return normalizedPath;
  }
  return normalizedPath.substring(normalizedBase.length).replaceFirst(
        RegExp(r'^[\\/]+'),
        '',
      );
}
