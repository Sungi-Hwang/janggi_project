import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/position.dart';
import 'package:janggi_master/utils/generated_puzzle_quality_guard.dart';
import 'package:janggi_master/utils/puzzle_share_codec.dart';
import 'package:janggi_master/utils/stockfish_converter.dart';

Future<void> main(List<String> args) async {
  final options = _RankOptions.parse(args);
  final document = await _readJson(options.inputPath);
  final ranked = _rankPuzzles(document, options)
    ..sort((a, b) {
      final scoreCompare = ((b['qualityScore'] as num).toDouble())
          .compareTo((a['qualityScore'] as num).toDouble());
      if (scoreCompare != 0) return scoreCompare;
      return (a['id'] as String).compareTo(b['id'] as String);
    });

  final selected = _selectDiverse(ranked, options);
  final total = selected.length;
  final mate1 = selected.where((puzzle) => puzzle['mateIn'] == 1).length;
  final mate2 = selected.where((puzzle) => puzzle['mateIn'] == 2).length;
  final mate3 = selected.where((puzzle) => puzzle['mateIn'] == 3).length;
  _writeJson(options.outputPath, <String, dynamic>{
    'version': '1.0-generated-ranked',
    'generated': DateTime.now().toUtc().toIso8601String(),
    'source': options.inputPath,
    'totalCandidates': ranked.length,
    'selected': selected.length,
    'targetMateIn': options.mateIn,
    'minPieces': options.minPieces,
    'qualityGate': {
      'mate3Ratio': total == 0 ? 0 : mate3 / total,
      'containsMate1': mate1 > 0,
      'containsMate2': mate2 > 0,
      'duplicateFenRemoved': true,
      'maxSamePalaceFingerprint': options.maxSamePalaceFingerprint,
      'maxSameLinePattern': options.maxSameLinePattern,
      'maxChariotFirstPercent': options.maxChariotFirstPercent,
      'maxQuietFirstPercent': options.maxQuietFirstPercent,
      'maxSameFinalTarget': options.maxSameFinalTarget,
      'maxSameFirstVector': options.maxSameFirstVector,
      'strictDiversity': options.strictDiversity,
    },
    'puzzles': selected,
  });

  stdout.writeln(jsonEncode(<String, dynamic>{
    'candidates': ranked.length,
    'selected': selected.length,
    'mate3Ratio': total == 0 ? 0 : mate3 / total,
    'containsMate1': mate1 > 0,
    'containsMate2': mate2 > 0,
    'output': options.outputPath,
    'lowestSelectedScore': selected.isEmpty
        ? null
        : (selected.last['qualityScore'] as num).toDouble(),
  }));
}

class _RankOptions {
  const _RankOptions({
    required this.inputPath,
    required this.outputPath,
    required this.limit,
    required this.mateIn,
    required this.minPieces,
    required this.maxSamePalaceFingerprint,
    required this.maxSameLinePattern,
    required this.maxChariotFirstPercent,
    required this.maxQuietFirstPercent,
    required this.maxSameFinalTarget,
    required this.maxSameFirstVector,
    required this.strictDiversity,
  });

  final String inputPath;
  final String outputPath;
  final int limit;
  final int mateIn;
  final int minPieces;
  final int maxSamePalaceFingerprint;
  final int maxSameLinePattern;
  final int maxChariotFirstPercent;
  final int maxQuietFirstPercent;
  final int maxSameFinalTarget;
  final int maxSameFirstVector;
  final bool strictDiversity;

  static _RankOptions parse(List<String> args) {
    var inputPath = 'dev/test_tmp/selfplay_puzzles.json';
    var outputPath = 'dev/generated_feed_ranked.json';
    var limit = 300;
    var mateIn = 3;
    var minPieces = 10;
    var maxSamePalaceFingerprint = 2;
    var maxSameLinePattern = 6;
    var maxChariotFirstPercent = 100;
    var maxQuietFirstPercent = 100;
    var maxSameFinalTarget = 999999;
    var maxSameFirstVector = 999999;
    var strictDiversity = false;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--input':
          inputPath = args[++i];
          break;
        case '--output':
          outputPath = args[++i];
          break;
        case '--limit':
          limit = int.parse(args[++i]);
          break;
        case '--mate-in':
          mateIn = int.parse(args[++i]);
          break;
        case '--min-pieces':
          minPieces = int.parse(args[++i]);
          break;
        case '--max-same-palace':
          maxSamePalaceFingerprint = int.parse(args[++i]);
          break;
        case '--max-same-line-pattern':
          maxSameLinePattern = int.parse(args[++i]);
          break;
        case '--max-chariot-first-percent':
          maxChariotFirstPercent = int.parse(args[++i]);
          break;
        case '--max-quiet-first-percent':
          maxQuietFirstPercent = int.parse(args[++i]);
          break;
        case '--max-same-final-target':
          maxSameFinalTarget = int.parse(args[++i]);
          break;
        case '--max-same-first-vector':
          maxSameFirstVector = int.parse(args[++i]);
          break;
        case '--strict-diversity':
          strictDiversity = true;
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

    return _RankOptions(
      inputPath: inputPath,
      outputPath: outputPath,
      limit: limit,
      mateIn: mateIn,
      minPieces: minPieces,
      maxSamePalaceFingerprint: maxSamePalaceFingerprint,
      maxSameLinePattern: maxSameLinePattern,
      maxChariotFirstPercent: maxChariotFirstPercent,
      maxQuietFirstPercent: maxQuietFirstPercent,
      maxSameFinalTarget: maxSameFinalTarget,
      maxSameFirstVector: maxSameFirstVector,
      strictDiversity: strictDiversity,
    );
  }

  static void _printUsage() {
    stdout.writeln('''
Usage: dart run tool/rank_generated_puzzles.dart [options]

Options:
  --input <path>      Generator JSON input
  --output <path>     Ranked JSON output
  --limit <n>         Number of puzzles to keep (default: 300)
  --mate-in <n>       Mate length to keep (default: 3)
  --min-pieces <n>    Minimum total pieces (default: 10)
  --max-same-palace <n>
                      Max puzzles with the same palace fingerprint (default: 2)
  --max-same-line-pattern <n>
                      Max puzzles with the same first/final move pattern
                      (default: 6)
  --max-chariot-first-percent <n>
                      Max share of first moves made by a chariot (default: 100)
  --max-quiet-first-percent <n>
                      Max share of non-capturing first moves (default: 100)
  --max-same-final-target <n>
                      Max puzzles ending on the same target square
  --max-same-first-vector <n>
                      Max puzzles with the same first-move vector
  --strict-diversity  Do not backfill with puzzles that fail diversity caps
''');
  }
}

Future<Map<String, dynamic>> _readJson(String path) async {
  final decoded = json.decode(await File(path).readAsString());
  if (decoded is! Map) {
    throw const FormatException('Expected a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

List<Map<String, dynamic>> _rankPuzzles(
  Map<String, dynamic> document,
  _RankOptions options,
) {
  final rawPuzzles = document['puzzles'];
  if (rawPuzzles is! List) {
    throw const FormatException('Expected a puzzles array.');
  }

  final seenFen = <String>{};
  final ranked = <Map<String, dynamic>>[];
  for (final raw in rawPuzzles.whereType<Map>()) {
    final puzzle = Map<String, dynamic>.from(raw);
    final mateIn = (puzzle['mateIn'] as num?)?.toInt();
    final fen = puzzle['fen'] as String?;
    final solution = puzzle['solution'];
    if (mateIn == null || mateIn != options.mateIn) continue;
    if (fen == null || fen.trim().isEmpty) continue;
    if (solution is! List || solution.length != mateIn * 2 - 1) continue;
    if (!seenFen.add(_fenKey(fen))) continue;
    if (GeneratedPuzzleQualityGuard.hasImmediateGeneralCapture(
      fen: fen,
      toMove: puzzle['toMove'] as String?,
    )) {
      continue;
    }

    final board = PuzzleShareCodec.parseFenBoard(fen);
    if (board == null) continue;

    final metrics = _qualityMetrics(
      board: board,
      fen: fen,
      solution: List<String>.from(solution),
    );
    if (metrics.pieceCount < options.minPieces) continue;

    final rankedPuzzle = <String, dynamic>{
      ...puzzle,
      'qualityScore': metrics.score,
      'quality': metrics.toJson(),
    };
    ranked.add(rankedPuzzle);
  }
  return ranked;
}

List<Map<String, dynamic>> _selectDiverse(
  List<Map<String, dynamic>> ranked,
  _RankOptions options,
) {
  final selected = <Map<String, dynamic>>[];
  final palaceCounts = <String, int>{};
  final linePatternCounts = <String, int>{};
  final finalTargetCounts = <String, int>{};
  final firstVectorCounts = <String, int>{};
  var chariotFirstCount = 0;
  var quietFirstCount = 0;
  final chariotFirstLimit = _percentLimit(
    options.limit,
    options.maxChariotFirstPercent,
  );
  final quietFirstLimit = _percentLimit(
    options.limit,
    options.maxQuietFirstPercent,
  );

  for (final puzzle in ranked) {
    if (selected.length >= options.limit) break;
    final quality = puzzle['quality'];
    final palace =
        quality is Map ? quality['palaceFingerprint']?.toString() : null;
    final line = quality is Map ? quality['linePattern']?.toString() : null;
    final firstPiece =
        quality is Map ? quality['firstMovePiece']?.toString() : null;
    final firstCapture =
        quality is Map && quality['firstMoveIsCapture'] == true;
    final firstVector = _firstVectorFromLinePattern(line);
    final finalTarget = _finalTargetFromSolution(puzzle['solution']);

    if (palace != null &&
        (palaceCounts[palace] ?? 0) >= options.maxSamePalaceFingerprint) {
      continue;
    }
    if (line != null &&
        (linePatternCounts[line] ?? 0) >= options.maxSameLinePattern) {
      continue;
    }
    if (finalTarget != null &&
        (finalTargetCounts[finalTarget] ?? 0) >= options.maxSameFinalTarget) {
      continue;
    }
    if (firstVector != null &&
        (firstVectorCounts[firstVector] ?? 0) >= options.maxSameFirstVector) {
      continue;
    }
    if (firstPiece == 'chariot' && chariotFirstCount >= chariotFirstLimit) {
      continue;
    }
    if (!firstCapture && quietFirstCount >= quietFirstLimit) {
      continue;
    }

    selected.add(puzzle);
    if (palace != null) palaceCounts[palace] = (palaceCounts[palace] ?? 0) + 1;
    if (line != null) {
      linePatternCounts[line] = (linePatternCounts[line] ?? 0) + 1;
    }
    if (finalTarget != null) {
      finalTargetCounts[finalTarget] =
          (finalTargetCounts[finalTarget] ?? 0) + 1;
    }
    if (firstVector != null) {
      firstVectorCounts[firstVector] =
          (firstVectorCounts[firstVector] ?? 0) + 1;
    }
    if (firstPiece == 'chariot') chariotFirstCount++;
    if (!firstCapture) quietFirstCount++;
  }

  if (!options.strictDiversity && selected.length < options.limit) {
    for (final puzzle in ranked) {
      if (selected.length >= options.limit) break;
      if (!selected.contains(puzzle)) selected.add(puzzle);
    }
  }
  return selected;
}

int _percentLimit(int total, int percent) {
  if (percent >= 100) return 999999;
  if (percent <= 0) return 0;
  return (total * percent / 100).floor();
}

String? _firstVectorFromLinePattern(String? linePattern) {
  if (linePattern == null) return null;
  final parts = linePattern.split(':');
  return parts.length >= 2 ? parts[1] : null;
}

String? _finalTargetFromSolution(dynamic solution) {
  if (solution is! List || solution.isEmpty) return null;
  final raw = solution.last.toString();
  final match =
      RegExp(r'^[a-i](?:10|[1-9])([a-i](?:10|[1-9]))$').firstMatch(raw);
  return match?.group(1);
}

_PuzzleQuality _qualityMetrics({
  required dynamic board,
  required String fen,
  required List<String> solution,
}) {
  final pieceCount = _pieceCount(board);
  final firstMove = _parseMove(solution.first);
  final firstPiece =
      firstMove == null ? null : board.getPiece(firstMove.from) as Piece?;
  final firstCapture =
      firstMove == null ? null : board.getPiece(firstMove.to) as Piece?;
  final uniqueMovingSquares = <String>{};
  final uniquePieceTypes = <PieceType>{};
  var captureCount = 0;
  Piece? finalMovingPiece;
  _ParsedMove? finalMove;

  final replay = PuzzleShareCodec.parseFenBoard(fen);
  for (final rawMove in solution) {
    final move = _parseMove(rawMove);
    if (move == null || replay == null) continue;
    final moving = replay.getPiece(move.from);
    final captured = replay.getPiece(move.to);
    if (moving != null) {
      uniqueMovingSquares.add('${move.from.file},${move.from.rank}');
      uniquePieceTypes.add(moving.type);
    }
    if (captured != null) {
      captureCount++;
    }
    finalMovingPiece = moving;
    finalMove = move;
    replay.movePiece(move.from, move.to);
  }

  var score = 100.0;
  score += min(pieceCount, 24) * 1.4;
  score += uniqueMovingSquares.length * 3.0;
  score += uniquePieceTypes.length * 4.0;
  score += captureCount.clamp(0, 3) * 2.0;

  if (firstPiece != null) {
    score += switch (firstPiece.type) {
      PieceType.horse || PieceType.elephant => 8.0,
      PieceType.soldier => 6.0,
      PieceType.cannon => 3.0,
      PieceType.chariot => 1.0,
      PieceType.guard => 2.0,
      PieceType.general => -12.0,
    };
  }
  if (firstCapture != null) {
    score -= switch (firstCapture.type) {
      PieceType.chariot => 9.0,
      PieceType.cannon => 7.0,
      PieceType.horse || PieceType.elephant => 6.0,
      PieceType.guard || PieceType.soldier => 3.0,
      PieceType.general => 20.0,
    };
  } else {
    score += 7.0;
  }

  if (pieceCount < 12) score -= 12.0;
  if (uniquePieceTypes.length <= 1) score -= 10.0;

  return _PuzzleQuality(
    score: double.parse((score / 150).clamp(0.0, 1.0).toStringAsFixed(4)),
    pieceCount: pieceCount,
    firstMoveIsCapture: firstCapture != null,
    firstMovePiece: firstPiece?.type.name,
    uniqueMovingPieces: uniqueMovingSquares.length,
    uniqueMovingPieceTypes: uniquePieceTypes.map((type) => type.name).toList()
      ..sort(),
    captureCountInLine: captureCount,
    palaceFingerprint: _palaceFingerprint(board, fen),
    linePattern: _linePattern(
      firstMove: firstMove,
      firstPiece: firstPiece,
      finalMove: finalMove,
      finalPiece: finalMovingPiece,
      firstMoveIsCapture: firstCapture != null,
    ),
  );
}

int _pieceCount(dynamic board) {
  var count = 0;
  for (var rank = 0; rank < 10; rank++) {
    for (var file = 0; file < 9; file++) {
      if (board.getPiece(Position(file: file, rank: rank)) != null) {
        count++;
      }
    }
  }
  return count;
}

String _palaceFingerprint(dynamic board, String fen) {
  final attackingSide = _sideFromFen(fen);
  final defenderColor =
      attackingSide == 'red' ? PieceColor.blue : PieceColor.red;
  Position? general;
  for (var rank = 0; rank < 10; rank++) {
    for (var file = 0; file < 9; file++) {
      final pos = Position(file: file, rank: rank);
      final piece = board.getPiece(pos);
      if (piece is Piece &&
          piece.color == defenderColor &&
          piece.type == PieceType.general) {
        general = pos;
        break;
      }
    }
    if (general != null) break;
  }
  if (general == null) return 'no-general';

  final parts = <String>[
    '${defenderColor.name}:${general.file},${general.rank}'
  ];
  for (var rank = general.rank - 2; rank <= general.rank + 2; rank++) {
    for (var file = general.file - 2; file <= general.file + 2; file++) {
      if (file < 0 || file > 8 || rank < 0 || rank > 9) continue;
      final pos = Position(file: file, rank: rank);
      final piece = board.getPiece(pos);
      if (piece is Piece) {
        parts.add(
          '${file - general.file},${rank - general.rank}:'
          '${piece.color.name[0]}${piece.type.name[0]}',
        );
      }
    }
  }
  return parts.join('|');
}

String _linePattern({
  required _ParsedMove? firstMove,
  required Piece? firstPiece,
  required _ParsedMove? finalMove,
  required Piece? finalPiece,
  required bool firstMoveIsCapture,
}) {
  String vector(_ParsedMove? move) {
    if (move == null) return 'none';
    return '${move.to.file - move.from.file},${move.to.rank - move.from.rank}';
  }

  return <String>[
    firstPiece?.type.name ?? 'unknown',
    vector(firstMove),
    firstMoveIsCapture ? 'capture' : 'quiet',
    finalPiece?.type.name ?? 'unknown',
    vector(finalMove),
  ].join(':');
}

String _sideFromFen(String fen) {
  final parts = fen.split(RegExp(r'\s+'));
  return parts.length > 1 && parts[1] == 'b' ? 'red' : 'blue';
}

_ParsedMove? _parseMove(String move) {
  final match =
      RegExp(r'^([a-i](?:10|[1-9]))([a-i](?:10|[1-9]))$').firstMatch(move);
  if (match == null) return null;
  try {
    return _ParsedMove(
      from: StockfishConverter.fromUCI(match.group(1)!),
      to: StockfishConverter.fromUCI(match.group(2)!),
    );
  } catch (_) {
    return null;
  }
}

String _fenKey(String fen) {
  final parts = fen.split(RegExp(r'\s+'));
  if (parts.length < 2) return fen;
  return '${parts[0]} ${parts[1]}';
}

void _writeJson(String path, Object data) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(data)}\n', encoding: utf8);
}

class _PuzzleQuality {
  const _PuzzleQuality({
    required this.score,
    required this.pieceCount,
    required this.firstMoveIsCapture,
    required this.firstMovePiece,
    required this.uniqueMovingPieces,
    required this.uniqueMovingPieceTypes,
    required this.captureCountInLine,
    required this.palaceFingerprint,
    required this.linePattern,
  });

  final double score;
  final int pieceCount;
  final bool firstMoveIsCapture;
  final String? firstMovePiece;
  final int uniqueMovingPieces;
  final List<String> uniqueMovingPieceTypes;
  final int captureCountInLine;
  final String palaceFingerprint;
  final String linePattern;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'score': score,
      'pieceCount': pieceCount,
      'firstMoveIsCapture': firstMoveIsCapture,
      'firstMovePiece': firstMovePiece,
      'uniqueMovingPieces': uniqueMovingPieces,
      'uniqueMovingPieceTypes': uniqueMovingPieceTypes,
      'captureCountInLine': captureCountInLine,
      'palaceFingerprint': palaceFingerprint,
      'linePattern': linePattern,
    };
  }
}

class _ParsedMove {
  const _ParsedMove({
    required this.from,
    required this.to,
  });

  final Position from;
  final Position to;
}
