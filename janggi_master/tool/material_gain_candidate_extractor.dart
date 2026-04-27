import 'dart:convert';
import 'dart:io';

import 'package:janggi_master/models/board.dart';
import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/position.dart';
import 'package:janggi_master/models/puzzle_objective.dart';
import 'package:janggi_master/utils/gib_parser.dart';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  final records = _readRecords(options.inputPath);
  final candidates = <Map<String, dynamic>>[];

  for (final record in records) {
    candidates.addAll(_extractFromRecord(record, options));
  }

  final document = <String, dynamic>{
    'version': 1,
    'generated': DateTime.now().toIso8601String(),
    'input': options.inputPath,
    'total': candidates.length,
    'puzzles': candidates,
  };

  final output = File(options.outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(document),
    encoding: utf8,
  );

  stdout.writeln(jsonEncode(<String, dynamic>{
    'input': options.inputPath,
    'records': records.length,
    'candidates': candidates.length,
    'output': options.outputPath,
  }));
}

class _Options {
  const _Options({
    required this.inputPath,
    required this.outputPath,
    required this.maxPlayerMoves,
    required this.targetTypes,
  });

  final String inputPath;
  final String outputPath;
  final int maxPlayerMoves;
  final Set<PieceType> targetTypes;

  static _Options parse(List<String> args) {
    String inputPath =
        'dev/test_tmp/community_seed_corpus/normalized/kja_pds.jsonl';
    String outputPath = 'dev/test_tmp/material_gain_candidates.json';
    int maxPlayerMoves = 3;
    var targetTypes = <PieceType>{PieceType.chariot, PieceType.cannon};

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--input':
          inputPath = args[++i];
          break;
        case '--output':
          outputPath = args[++i];
          break;
        case '--max-player-moves':
          maxPlayerMoves = int.parse(args[++i]);
          break;
        case '--targets':
          targetTypes = args[++i]
              .split(',')
              .map((value) => PuzzleObjective.pieceTypeFromWire(value.trim()))
              .whereType<PieceType>()
              .where((type) =>
                  type == PieceType.chariot || type == PieceType.cannon)
              .toSet();
          if (targetTypes.isEmpty) {
            targetTypes = <PieceType>{PieceType.chariot, PieceType.cannon};
          }
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

    return _Options(
      inputPath: inputPath,
      outputPath: outputPath,
      maxPlayerMoves: maxPlayerMoves.clamp(1, 3),
      targetTypes: targetTypes,
    );
  }

  static void _printUsage() {
    stdout.writeln('''
Usage: dart run tool/material_gain_candidate_extractor.dart [options]

Options:
  --input <path>             Normalized GIB jsonl file or directory
  --output <path>            Candidate JSON output
  --max-player-moves <n>     1-3 player moves to scan (default: 3)
  --targets <list>           Comma list: chariot,cannon
''');
  }
}

class _Record {
  const _Record({
    required this.sourceId,
    required this.sourceType,
    required this.sourceUrl,
    required this.gameId,
    required this.title,
    required this.date,
    required this.moves,
    required this.initialFen,
  });

  final String sourceId;
  final String sourceType;
  final String? sourceUrl;
  final String gameId;
  final String title;
  final String? date;
  final List<String> moves;
  final String? initialFen;

  factory _Record.fromJson(Map<String, dynamic> json) {
    return _Record(
      sourceId: json['sourceId'] as String? ?? 'unknown',
      sourceType: json['sourceType'] as String? ?? 'unknown',
      sourceUrl: json['sourceUrl'] as String?,
      gameId: json['gameId'] as String? ?? json['sourceId'] as String? ?? '',
      title: json['title'] as String? ?? '기보',
      date: json['date'] as String?,
      moves: List<String>.from(json['moves'] as List<dynamic>? ?? const []),
      initialFen: json['initialFen'] as String?,
    );
  }
}

List<_Record> _readRecords(String inputPath) {
  final input = File(inputPath);
  final files = <File>[];
  if (input.existsSync()) {
    files.add(input);
  } else {
    final directory = Directory(inputPath);
    if (directory.existsSync()) {
      files.addAll(
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.jsonl')),
      );
    }
  }

  final records = <_Record>[];
  for (final file in files) {
    for (final line in file.readAsLinesSync(encoding: utf8)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        records.add(_Record.fromJson(Map<String, dynamic>.from(decoded)));
      }
    }
  }
  return records;
}

List<Map<String, dynamic>> _extractFromRecord(
    _Record record, _Options options) {
  final initialBoard = record.initialFen == null
      ? null
      : GibParser.fenToBoard(record.initialFen!);
  if (initialBoard == null || record.moves.isEmpty) {
    return const <Map<String, dynamic>>[];
  }

  final candidates = <Map<String, dynamic>>[];

  for (var moveIndex = 0; moveIndex < record.moves.length; moveIndex++) {
    final board = GibParser.replayMovesToPosition(
      record.moves,
      upToMove: moveIndex,
      initialBoard: initialBoard,
    );
    if (board == null) continue;

    final player = moveIndex.isEven ? PieceColor.blue : PieceColor.red;
    for (var playerMoves = 1;
        playerMoves <= options.maxPlayerMoves;
        playerMoves++) {
      final plies = playerMoves * 2 - 1;
      if (moveIndex + plies > record.moves.length) continue;

      final result = _simulateLine(
        board,
        record.moves.sublist(moveIndex, moveIndex + plies),
        player,
        options.targetTypes,
      );
      if (result == null || !result.hasTargetCapture) continue;

      final targetWires = result.targetCapturedTypes
          .map(PuzzleObjective.pieceTypeToWire)
          .toSet()
          .toList(growable: false)
        ..sort();
      final minNet = targetWires.contains('chariot')
          ? PuzzleObjective.defaultChariotNetGainCp
          : PuzzleObjective.defaultCannonNetGainCp;
      if (result.netMaterialGainCp < minNet) continue;

      final id =
          '${_sanitizeId(record.sourceId)}__${_sanitizeId(record.gameId)}__mg${(moveIndex + 1).toString().padLeft(3, '0')}_$playerMoves';
      final label = targetWires
          .map(PuzzleObjective.pieceTypeFromWire)
          .whereType<PieceType>()
          .map(PuzzleObjective.pieceTypeLabel)
          .join('/');

      candidates.add(<String, dynamic>{
        'id': id,
        'difficulty': playerMoves,
        'mateIn': playerMoves,
        'title': '$label 획득 후보 #${moveIndex + 1}',
        'fen': GibParser.boardToFen(board, player),
        'solution': result.solution,
        'toMove': player == PieceColor.blue ? 'blue' : 'red',
        'source': record.title,
        'sourceId': record.sourceId,
        'sourceType': record.sourceType,
        'sourceUrl': record.sourceUrl,
        'gameId': record.gameId,
        'date': record.date,
        'moveIndex': moveIndex,
        'objectiveType': PuzzleObjective.materialGain,
        'objective': <String, dynamic>{
          'targetPieceTypes': targetWires,
          'maxPlayerMoves': playerMoves,
          'minNetMaterialGainCp': minNet,
          'minFinalEvalCp': PuzzleObjective.defaultFinalEvalCp,
          'minEvalGainCp': PuzzleObjective.defaultEvalGainCp,
          'verifiedNetMaterialGainCp': result.netMaterialGainCp,
        },
      });
    }
  }

  return candidates;
}

_SimulationResult? _simulateLine(
  Board startBoard,
  List<String> gibMoves,
  PieceColor player,
  Set<PieceType> targets,
) {
  final board = Board.copy(startBoard);
  final solution = <String>[];
  final capturedByPlayer = <Piece>[];
  final capturedByOpponent = <Piece>[];
  final targetCapturedTypes = <PieceType>{};

  for (final rawMove in gibMoves) {
    final positions = GibParser.parseGibMove(rawMove);
    if (positions == null) return null;
    final from = positions['from']!;
    final to = positions['to']!;
    final movingPiece = board.getPiece(from);
    if (movingPiece == null) return null;
    final captured = board.getPiece(to);
    board.movePiece(from, to);
    solution.add(_uci(from, to));

    if (captured == null) continue;
    if (movingPiece.color == player) {
      capturedByPlayer.add(captured);
      if (targets.contains(captured.type)) {
        targetCapturedTypes.add(captured.type);
      }
    } else {
      capturedByOpponent.add(captured);
    }
  }

  final netGain = PuzzleObjective.materialScoreForPieces(capturedByPlayer) -
      PuzzleObjective.materialScoreForPieces(capturedByOpponent);
  return _SimulationResult(
    solution: solution,
    hasTargetCapture: targetCapturedTypes.isNotEmpty,
    targetCapturedTypes: targetCapturedTypes,
    netMaterialGainCp: netGain,
  );
}

class _SimulationResult {
  const _SimulationResult({
    required this.solution,
    required this.hasTargetCapture,
    required this.targetCapturedTypes,
    required this.netMaterialGainCp,
  });

  final List<String> solution;
  final bool hasTargetCapture;
  final Set<PieceType> targetCapturedTypes;
  final int netMaterialGainCp;
}

String _uci(Position from, Position to) {
  final fromFile = String.fromCharCode('a'.codeUnitAt(0) + from.file);
  final toFile = String.fromCharCode('a'.codeUnitAt(0) + to.file);
  return '$fromFile${from.rank + 1}$toFile${to.rank + 1}';
}

String _sanitizeId(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
