import 'dart:convert';
import 'dart:io';

import 'package:janggi_master/models/board.dart';
import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/utils/gib_parser.dart';

import 'gib_corpus_support.dart';

Future<void> main(List<String> args) async {
  final options = _ExtractOptions.parse(args);
  final rootPath = resolveCorpusRoot(options.rootPath);
  final inputFiles = _resolveInputFiles(rootPath, options.inputPath);

  if (inputFiles.isEmpty) {
    stderr.writeln('No normalized corpus files found.');
    exit(2);
  }

  final records = <_NormalizedRecord>[];
  for (final file in inputFiles) {
    records.addAll(_readNormalizedRecords(file));
  }

  final limitedRecords = options.limitGames == null
      ? records
      : records.take(options.limitGames!).toList(growable: false);

  final categories = <String, int>{
    'mate1': 0,
    'mate2': 0,
    'mate3': 0,
  };
  final candidates = <Map<String, dynamic>>[];
  for (final record in limitedRecords) {
    candidates.addAll(_extractCandidates(record, categories));
  }

  final document = <String, dynamic>{
    'version': 1,
    'generated': DateTime.now().toIso8601String(),
    'sourceRoot': rootPath,
    'inputFiles': inputFiles.map((file) => file.path).toList(growable: false),
    'total': candidates.length,
    'categories': {
      'mate1': {'count': categories['mate1']},
      'mate2': {'count': categories['mate2']},
      'mate3': {'count': categories['mate3']},
    },
    'puzzles': candidates,
  };

  final outputFile = File(options.outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(document),
    encoding: utf8,
  );

  stdout.writeln(
    jsonEncode({
      'root': rootPath,
      'inputFiles': inputFiles.length,
      'gamesRead': limitedRecords.length,
      'totalCandidates': candidates.length,
      'output': options.outputPath,
      'categories': categories,
    }),
  );
}

class _ExtractOptions {
  _ExtractOptions({
    required this.rootPath,
    required this.inputPath,
    required this.outputPath,
    required this.limitGames,
  });

  final String? rootPath;
  final String? inputPath;
  final String outputPath;
  final int? limitGames;

  static _ExtractOptions parse(List<String> args) {
    String? rootPath;
    String? inputPath;
    String outputPath = 'test_tmp/puzzle_candidates.json';
    int? limitGames;

    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--root':
          rootPath = args[++i];
          break;
        case '--input':
          inputPath = args[++i];
          break;
        case '--output':
          outputPath = args[++i];
          break;
        case '--limit-games':
          limitGames = int.parse(args[++i]);
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

    return _ExtractOptions(
      rootPath: rootPath,
      inputPath: inputPath,
      outputPath: outputPath,
      limitGames: limitGames,
    );
  }

  static void _printUsage() {
    stdout.writeln('''
Usage: dart run tool/extract_puzzle_candidates.dart [options]

Options:
  --root <path>         Corpus root (default: %USERPROFILE%\\Documents\\janggi_gib_corpus)
  --input <path>        Normalized file, directory, or simple wildcard pattern
  --output <path>       Output JSON path (default: test_tmp/puzzle_candidates.json)
  --limit-games <n>     Limit number of normalized games to process
  --help                Show this help
''');
  }
}

class _NormalizedRecord {
  const _NormalizedRecord({
    required this.sourceId,
    required this.sourceType,
    required this.sourceUrl,
    required this.localPath,
    required this.gameId,
    required this.gameIndex,
    required this.title,
    required this.round,
    required this.date,
    required this.players,
    required this.result,
    required this.setupBlue,
    required this.setupRed,
    required this.moves,
    required this.moveCount,
    required this.initialFen,
    required this.rawMetadata,
    required this.encoding,
    required this.downloadUrl,
  });

  final String sourceId;
  final String sourceType;
  final String? sourceUrl;
  final String localPath;
  final String gameId;
  final int gameIndex;
  final String title;
  final String? round;
  final String? date;
  final Map<String, dynamic> players;
  final String? result;
  final String? setupBlue;
  final String? setupRed;
  final List<String> moves;
  final int moveCount;
  final String? initialFen;
  final Map<String, dynamic> rawMetadata;
  final String encoding;
  final String? downloadUrl;

  factory _NormalizedRecord.fromJson(Map<String, dynamic> json) {
    return _NormalizedRecord(
      sourceId: json['sourceId'] as String,
      sourceType: json['sourceType'] as String,
      sourceUrl: json['sourceUrl'] as String?,
      localPath: json['localPath'] as String,
      gameId: json['gameId'] as String,
      gameIndex: json['gameIndex'] as int? ?? 0,
      title: json['title'] as String? ?? 'Untitled GIB Game',
      round: json['round'] as String?,
      date: json['date'] as String?,
      players: Map<String, dynamic>.from(
        json['players'] as Map? ?? const <String, dynamic>{},
      ),
      result: json['result'] as String?,
      setupBlue: json['setupBlue'] as String?,
      setupRed: json['setupRed'] as String?,
      moves: List<String>.from(json['moves'] as List<dynamic>),
      moveCount: json['moveCount'] as int? ?? 0,
      initialFen: json['initialFen'] as String?,
      rawMetadata: Map<String, dynamic>.from(
        json['rawMetadata'] as Map? ?? const <String, dynamic>{},
      ),
      encoding: json['encoding'] as String? ?? 'unknown',
      downloadUrl: json['downloadUrl'] as String?,
    );
  }
}

List<File> _resolveInputFiles(String rootPath, String? inputPath) {
  if (inputPath == null || inputPath.trim().isEmpty) {
    final normalizedDir =
        Directory('$rootPath${Platform.pathSeparator}normalized');
    if (!normalizedDir.existsSync()) return const <File>[];
    return normalizedDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.jsonl'))
        .toList(growable: false)
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  final trimmed = inputPath.trim();
  final asFile = File(trimmed);
  if (asFile.existsSync()) {
    return <File>[asFile];
  }

  final asDirectory = Directory(trimmed);
  if (asDirectory.existsSync()) {
    return asDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.jsonl'))
        .toList(growable: false)
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  if (trimmed.contains('*')) {
    final normalizedDir =
        Directory('$rootPath${Platform.pathSeparator}normalized');
    if (!normalizedDir.existsSync()) return const <File>[];
    final wildcard = RegExp.escape(trimmed)
        .replaceAll(r'\*', '.*')
        .replaceAll(r'\?', '.');
    final pattern = RegExp('^$wildcard\$', caseSensitive: false);
    return normalizedDir
        .listSync()
        .whereType<File>()
        .where((file) => pattern.hasMatch(file.uri.pathSegments.last))
        .toList(growable: false)
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  return const <File>[];
}

List<_NormalizedRecord> _readNormalizedRecords(File file) {
  return file
      .readAsLinesSync(encoding: utf8)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => _NormalizedRecord.fromJson(
            Map<String, dynamic>.from(jsonDecode(line) as Map),
          ))
      .toList(growable: false);
}

List<Map<String, dynamic>> _extractCandidates(
  _NormalizedRecord record,
  Map<String, int> categories,
) {
  final initialBoard = _buildInitialBoard(record);
  final blueSetup = GibParser.parsePieceSetup(record.setupBlue);
  final redSetup = GibParser.parsePieceSetup(record.setupRed);
  final candidates = <Map<String, dynamic>>[];

  for (int moveIndex = 0; moveIndex < record.moves.length; moveIndex++) {
    final remainingPlies = record.moves.length - moveIndex;
    if (remainingPlies != 1 && remainingPlies != 3 && remainingPlies != 5) {
      continue;
    }

    final board = GibParser.replayMovesToPosition(
      record.moves,
      upToMove: moveIndex,
      blueSetup: blueSetup ?? PieceSetup.horseElephantHorseElephant,
      redSetup: redSetup ?? PieceSetup.horseElephantHorseElephant,
      initialBoard: initialBoard,
    );
    if (board == null) continue;

    final solution = _toUciMoves(record.moves.sublist(moveIndex));
    if (solution.length != remainingPlies) {
      continue;
    }

    final toMove = moveIndex.isEven ? PieceColor.blue : PieceColor.red;
    final fen = GibParser.boardToFen(board, toMove);
    final mateIn = (remainingPlies + 1) ~/ 2;
    categories['mate$mateIn'] = (categories['mate$mateIn'] ?? 0) + 1;

    final moveNumber = moveIndex + 1;
    final id =
        '${_sanitizeId(record.sourceId)}__${_sanitizeId(record.gameId)}__m${moveNumber.toString().padLeft(3, '0')}';

    candidates.add({
      'id': id,
      'title': '${record.title} - mate $mateIn candidate #$moveNumber',
      'description': _buildDescription(record),
      'mateIn': mateIn,
      'fen': fen,
      'solution': solution,
      'sourceId': record.sourceId,
      'sourceType': record.sourceType,
      'sourceUrl': record.sourceUrl,
      'downloadUrl': record.downloadUrl,
      'localPath': record.localPath,
      'gameId': record.gameId,
      'gameIndex': record.gameIndex,
      'moveIndex': moveIndex,
      'moveNumber': moveNumber,
      'toMove': toMove == PieceColor.blue ? 'blue' : 'red',
      'players': record.players,
      'date': record.date,
      'round': record.round,
      'result': record.result,
      'initialFen': record.initialFen,
      'rawMetadata': record.rawMetadata,
      'validation': {
        'source': 'gib_candidate',
        'remainingPlies': remainingPlies,
      },
    });
  }

  return candidates;
}

Board? _buildInitialBoard(_NormalizedRecord record) {
  if (record.initialFen != null && record.initialFen!.trim().isNotEmpty) {
    return GibParser.fenToBoard(record.initialFen!);
  }
  return null;
}

List<String> _toUciMoves(List<String> gibMoves) {
  final converted = <String>[];
  for (final move in gibMoves) {
    final parsed = GibParser.parseGibMove(move);
    if (parsed == null) {
      return const <String>[];
    }
    converted.add(
      '${parsed['from']!.toAlgebraic()}${parsed['to']!.toAlgebraic()}',
    );
  }
  return converted;
}

String _sanitizeId(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
}

String _buildDescription(_NormalizedRecord record) {
  final parts = <String>[
    if (record.players['blue']?.toString().trim().isNotEmpty == true)
      '초: ${record.players['blue']}',
    if (record.players['red']?.toString().trim().isNotEmpty == true)
      '한: ${record.players['red']}',
    if (record.round?.trim().isNotEmpty == true) record.round!,
    if (record.date?.trim().isNotEmpty == true) record.date!,
  ];
  return parts.join(' / ');
}
