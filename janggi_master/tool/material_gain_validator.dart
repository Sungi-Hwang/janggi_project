import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/position.dart';
import 'package:janggi_master/models/puzzle_objective.dart';
import 'package:janggi_master/utils/gib_parser.dart';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  final document = _readDocument(options.inputPath);
  final puzzles = List<Map<String, dynamic>>.from(
    document['puzzles'] as List<dynamic>? ?? const <dynamic>[],
  );

  final engine = _UciEngineClient(options.enginePath);
  try {
    await engine.initialize();
    final details = <Map<String, dynamic>>[];
    final strictPuzzles = <Map<String, dynamic>>[];

    for (final puzzle in puzzles.take(options.limit ?? puzzles.length)) {
      final result = await _validatePuzzle(
        puzzle,
        engine,
        options.depth,
        options.uniqueFirstMoveMarginCp,
      );
      details.add(result);
      if (result['strictPass'] == true) {
        strictPuzzles.add(Map<String, dynamic>.from(result['puzzle'] as Map));
      }
    }

    final report = <String, dynamic>{
      'summary': <String, dynamic>{
        'generatedAt': DateTime.now().toIso8601String(),
        'input': options.inputPath,
        'checked': details.length,
        'strictPass':
            details.where((item) => item['strictPass'] == true).length,
      },
      'details': details,
    };

    _writeJson(options.reportPath, report);
    _writeJson(options.strictOutputPath, <String, dynamic>{
      ...document,
      'generated': DateTime.now().toIso8601String(),
      'total': strictPuzzles.length,
      'puzzles': strictPuzzles,
    });

    stdout.writeln(jsonEncode(report['summary']));
  } finally {
    await engine.dispose();
  }
}

class _Options {
  const _Options({
    required this.inputPath,
    required this.reportPath,
    required this.strictOutputPath,
    required this.depth,
    required this.enginePath,
    required this.limit,
    required this.uniqueFirstMoveMarginCp,
  });

  final String inputPath;
  final String reportPath;
  final String strictOutputPath;
  final int depth;
  final String enginePath;
  final int? limit;
  final int uniqueFirstMoveMarginCp;

  static _Options parse(List<String> args) {
    String inputPath = 'dev/test_tmp/material_gain_candidates.json';
    String reportPath = 'dev/test_tmp/material_gain_validation_report.json';
    String strictOutputPath = 'dev/test_tmp/material_gain_strict_preview.json';
    int depth = 8;
    int? limit;
    int uniqueFirstMoveMarginCp = 80;
    final defaultEngine = Platform.isWindows
        ? 'engine/src/stockfish.exe'
        : 'engine/src/stockfish';
    var enginePath = File(defaultEngine).existsSync()
        ? defaultEngine
        : Platform.isWindows
            ? 'stockfish.dll'
            : 'libstockfish.so';

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--input':
          inputPath = args[++i];
          break;
        case '--report':
          reportPath = args[++i];
          break;
        case '--strict-output':
          strictOutputPath = args[++i];
          break;
        case '--depth':
          depth = int.parse(args[++i]);
          break;
        case '--engine':
          enginePath = args[++i];
          break;
        case '--limit':
          limit = int.parse(args[++i]);
          break;
        case '--uniqueness-margin':
          uniqueFirstMoveMarginCp = int.parse(args[++i]);
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
      reportPath: reportPath,
      strictOutputPath: strictOutputPath,
      depth: depth,
      enginePath: enginePath,
      limit: limit,
      uniqueFirstMoveMarginCp: uniqueFirstMoveMarginCp,
    );
  }

  static void _printUsage() {
    stdout.writeln('''
Usage: dart run tool/material_gain_validator.dart [options]

Options:
  --input <path>          Candidate JSON input
  --report <path>         Validation report output
  --strict-output <path>  Strict-only puzzle JSON output
  --depth <n>             Engine depth (default: 8)
  --engine <path>         Engine executable path
  --limit <n>             Validate only the first N puzzles
  --uniqueness-margin <n> Exclude alternate first moves within N cp (default: 80)
''');
  }
}

Future<Map<String, dynamic>> _validatePuzzle(
  Map<String, dynamic> rawPuzzle,
  _UciEngineClient engine,
  int depth,
  int uniqueFirstMoveMarginCp,
) async {
  final puzzle = PuzzleObjective.normalizePuzzleMap(rawPuzzle);
  final objective = PuzzleObjective.objectiveOf(puzzle);
  final solution = List<String>.from(puzzle['solution'] as List? ?? const []);
  final fen = puzzle['fen'] as String? ?? '';
  final player = puzzle['toMove'] == 'red' ? PieceColor.red : PieceColor.blue;
  final failReasons = <String>[];

  if (PuzzleObjective.typeOf(puzzle) != PuzzleObjective.materialGain) {
    failReasons.add('not_material_gain');
  }
  if (solution.isEmpty) {
    failReasons.add('missing_solution');
  }
  if (fen.isEmpty) {
    failReasons.add('missing_fen');
  }

  final material = _validateMaterialLine(fen, solution, player, objective);
  if (!material.hasTargetCapture) failReasons.add('target_not_captured');
  if (material.netMaterialGainCp <
      (objective['minNetMaterialGainCp'] as int? ??
          PuzzleObjective.defaultCannonNetGainCp)) {
    failReasons.add('net_material_gain_too_low');
  }
  if (fen.isEmpty || solution.isEmpty) {
    return <String, dynamic>{
      'id': puzzle['id'],
      'title': puzzle['title'],
      'strictPass': false,
      'failReasons': failReasons,
      'targetCaptured': material.hasTargetCapture,
      'netMaterialGainCp': material.netMaterialGainCp,
      'puzzle': puzzle,
    };
  }

  final startEval = await engine.analyzePosition(fen, const <String>[], depth);
  final finalEval = await engine.analyzePosition(fen, solution, depth);
  final firstMoveMatches = startEval.bestmove == solution.first;
  if (!firstMoveMatches) failReasons.add('first_move_mismatch');
  if (startEval.hasNearEquivalentAlternative(uniqueFirstMoveMarginCp)) {
    failReasons.add('first_move_not_unique');
  }

  final startEvalForPlayer = _scoreForPlayer(startEval, player, player);
  final finalSideToMove =
      solution.length.isEven ? player : _oppositeColor(player);
  final finalEvalForPlayer =
      _scoreForPlayer(finalEval, finalSideToMove, player);
  final evalGainCp = finalEvalForPlayer == null || startEvalForPlayer == null
      ? null
      : finalEvalForPlayer - startEvalForPlayer;

  final minFinalEvalCp =
      objective['minFinalEvalCp'] as int? ?? PuzzleObjective.defaultFinalEvalCp;
  final minEvalGainCp =
      objective['minEvalGainCp'] as int? ?? PuzzleObjective.defaultEvalGainCp;
  if (finalEvalForPlayer == null || finalEvalForPlayer < minFinalEvalCp) {
    failReasons.add('final_eval_too_low');
  }
  if (evalGainCp == null || evalGainCp < minEvalGainCp) {
    failReasons.add('eval_gain_too_low');
  }

  final strictPass = failReasons.isEmpty;
  final normalizedObjective = <String, dynamic>{
    ...objective,
    'verifiedNetMaterialGainCp': material.netMaterialGainCp,
    if (finalEvalForPlayer != null) 'verifiedFinalEvalCp': finalEvalForPlayer,
    if (evalGainCp != null) 'verifiedEvalGainCp': evalGainCp,
    'engineDepth': depth,
  };
  final normalizedPuzzle = <String, dynamic>{
    ...puzzle,
    'objective': normalizedObjective,
  };

  return <String, dynamic>{
    'id': puzzle['id'],
    'title': puzzle['title'],
    'strictPass': strictPass,
    'failReasons': failReasons,
    'targetCaptured': material.hasTargetCapture,
    'netMaterialGainCp': material.netMaterialGainCp,
    'firstMoveMatches': firstMoveMatches,
    'firstMoveUnique':
        !startEval.hasNearEquivalentAlternative(uniqueFirstMoveMarginCp),
    'startEvalCp': startEvalForPlayer,
    'finalEvalCp': finalEvalForPlayer,
    'evalGainCp': evalGainCp,
    'startEval': startEval.toJson(),
    'finalEval': finalEval.toJson(),
    'puzzle': normalizedPuzzle,
  };
}

_MaterialLineResult _validateMaterialLine(
  String fen,
  List<String> solution,
  PieceColor player,
  Map<String, dynamic> objective,
) {
  final board = GibParser.fenToBoard(fen);
  if (board == null) {
    return const _MaterialLineResult(
      hasTargetCapture: false,
      netMaterialGainCp: -99999,
    );
  }

  final targets = PuzzleObjective.targetPieceTypes(objective);
  final capturedByPlayer = <Piece>[];
  final capturedByOpponent = <Piece>[];
  var sideToMove = player;

  for (final rawMove in solution) {
    final move = _parseUciMove(rawMove);
    if (move == null) {
      return const _MaterialLineResult(
        hasTargetCapture: false,
        netMaterialGainCp: -99999,
      );
    }

    final movingPiece = board.getPiece(move.$1);
    if (movingPiece == null || movingPiece.color != sideToMove) {
      return const _MaterialLineResult(
        hasTargetCapture: false,
        netMaterialGainCp: -99999,
      );
    }

    final captured = board.getPiece(move.$2);
    board.movePiece(move.$1, move.$2);
    if (captured != null) {
      if (movingPiece.color == player) {
        capturedByPlayer.add(captured);
      } else {
        capturedByOpponent.add(captured);
      }
    }
    sideToMove = _oppositeColor(sideToMove);
  }

  final netGain = PuzzleObjective.materialScoreForPieces(capturedByPlayer) -
      PuzzleObjective.materialScoreForPieces(capturedByOpponent);
  return _MaterialLineResult(
    hasTargetCapture: capturedByPlayer.any(
      (piece) => targets.contains(piece.type),
    ),
    netMaterialGainCp: netGain,
  );
}

class _MaterialLineResult {
  const _MaterialLineResult({
    required this.hasTargetCapture,
    required this.netMaterialGainCp,
  });

  final bool hasTargetCapture;
  final int netMaterialGainCp;
}

(Position, Position)? _parseUciMove(String rawMove) {
  final match = RegExp(
    r'^([a-i])(10|[1-9])([a-i])(10|[1-9])$',
    caseSensitive: false,
  ).firstMatch(rawMove.trim());
  if (match == null) return null;
  return (
    _square(match.group(1)!, match.group(2)!),
    _square(match.group(3)!, match.group(4)!),
  );
}

Position _square(String fileText, String rankText) {
  return Position(
    file: fileText.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0),
    rank: int.parse(rankText) - 1,
  );
}

PieceColor _oppositeColor(PieceColor color) {
  return color == PieceColor.blue ? PieceColor.red : PieceColor.blue;
}

int? _scoreForPlayer(
  _EvalResult eval,
  PieceColor sideToMove,
  PieceColor player,
) {
  if (eval.type == 'mate') {
    final value = eval.value;
    if (value == null) return null;
    final cp = value.sign * 100000;
    return sideToMove == player ? cp : -cp;
  }
  if (eval.type != 'cp' || eval.value == null) return null;
  return sideToMove == player ? eval.value : -eval.value!;
}

Map<String, dynamic> _readDocument(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync(encoding: utf8));
  if (decoded is! Map) {
    throw const FormatException('Input must be a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

void _writeJson(String path, Map<String, dynamic> value) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(value),
    encoding: utf8,
  );
}

class _UciEngineClient {
  _UciEngineClient(this.enginePath);

  final String enginePath;
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  final _pendingLines = <String>[];
  Completer<List<String>>? _waiter;
  bool Function(String line)? _until;

  Future<void> initialize() async {
    _process = await Process.start(enginePath, const <String>[]);
    _stdoutSubscription = _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine);
    _process!.stderr.drain<void>();
    await _sendAndWait('uci', until: (line) => line == 'uciok');
    await _send('setoption name UCI_Variant value janggi');
    await _send('setoption name Threads value 1');
    await _send('setoption name Hash value 128');
    await _send('setoption name MultiPV value 4');
    await _waitReady();
    await _send('ucinewgame');
    await _waitReady();
  }

  Future<_EvalResult> analyzePosition(
    String fen,
    List<String> moves,
    int depth,
  ) async {
    final command = moves.isEmpty
        ? 'position fen $fen'
        : 'position fen $fen moves ${moves.join(' ')}';
    await _send(command);
    await _waitReady();
    final lines = await _sendAndWait(
      'go depth $depth',
      until: (line) => line.startsWith('bestmove '),
      timeout: const Duration(seconds: 20),
    );
    return _EvalResult.fromLines(lines, depth: depth);
  }

  Future<void> dispose() async {
    final process = _process;
    if (process != null) {
      process.stdin.writeln('quit');
      await process.stdin.close();
    }
    await _stdoutSubscription?.cancel();
    _process = null;
  }

  Future<void> _waitReady() async {
    await _sendAndWait('isready', until: (line) => line == 'readyok');
  }

  Future<void> _send(String command) async {
    final process = _process;
    if (process == null) {
      throw StateError('Engine is not initialized.');
    }
    process.stdin.writeln(command);
    await process.stdin.flush();
  }

  Future<List<String>> _sendAndWait(
    String command, {
    required bool Function(String line) until,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_waiter != null) {
      throw StateError('Engine command already pending.');
    }
    _pendingLines.clear();
    _until = until;
    _waiter = Completer<List<String>>();
    await _send(command);
    try {
      return await _waiter!.future.timeout(timeout);
    } finally {
      _waiter = null;
      _until = null;
    }
  }

  void _handleLine(String line) {
    final waiter = _waiter;
    if (waiter == null) return;
    _pendingLines.add(line);
    if (_until?.call(line) == true && !waiter.isCompleted) {
      waiter.complete(List<String>.from(_pendingLines));
    }
  }
}

class _EvalResult {
  const _EvalResult({
    required this.type,
    required this.value,
    required this.bestmove,
    required this.depth,
    required this.pvScores,
  });

  final String type;
  final int? value;
  final String? bestmove;
  final int depth;
  final List<_PvScore> pvScores;

  factory _EvalResult.fromLines(List<String> lines, {required int depth}) {
    final text = lines.join('\n');
    final bestmove = RegExp(
      r'^bestmove\s+([a-i](?:10|[1-9])[a-i](?:10|[1-9])[a-z]*)',
      multiLine: true,
    ).firstMatch(text)?.group(1);
    final pvScores = _parsePvScores(lines, depth);
    final primary = _primaryPvScore(pvScores);

    return _EvalResult(
      type: primary?.type ?? 'unknown',
      value: primary?.value,
      bestmove: bestmove,
      depth: depth,
      pvScores: pvScores,
    );
  }

  bool hasNearEquivalentAlternative(int marginCp) {
    final primary = _primaryPvScore(pvScores);
    final primaryCp = primary?.scoreCp;
    final primaryMove = primary?.firstMove ?? bestmove;
    if (primaryCp == null || primaryMove == null) {
      return false;
    }
    return pvScores.any((score) {
      if (score.multipv <= 1) return false;
      if (score.firstMove == null || score.firstMove == primaryMove) {
        return false;
      }
      final scoreCp = score.scoreCp;
      return scoreCp != null && primaryCp - scoreCp <= marginCp;
    });
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'value': value,
        'bestmove': bestmove,
        'depth': depth,
        'pvScores': pvScores.map((score) => score.toJson()).toList(),
      };
}

class _PvScore {
  const _PvScore({
    required this.multipv,
    required this.type,
    required this.value,
    required this.firstMove,
  });

  final int multipv;
  final String type;
  final int? value;
  final String? firstMove;

  int? get scoreCp {
    if (value == null) return null;
    if (type == 'mate') return value!.sign * 100000;
    if (type == 'cp') return value;
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'multipv': multipv,
        'type': type,
        'value': value,
        'firstMove': firstMove,
      };
}

_PvScore? _primaryPvScore(List<_PvScore> scores) {
  for (final score in scores) {
    if (score.multipv == 1) {
      return score;
    }
  }
  return scores.isEmpty ? null : scores.first;
}

List<_PvScore> _parsePvScores(List<String> lines, int depth) {
  final byMultipv = <int, _PvScore>{};
  final infoPattern = RegExp(
    r'\bdepth\s+(\d+).*?\bmultipv\s+(\d+).*?\bscore\s+(cp|mate)\s+(-?\d+).*?\bpv\s+([a-i](?:10|[1-9])[a-i](?:10|[1-9])[a-z]*)',
  );

  for (final line in lines) {
    if (!line.startsWith('info ')) continue;
    final match = infoPattern.firstMatch(line);
    if (match == null) continue;
    final lineDepth = int.tryParse(match.group(1)!);
    if (lineDepth != null && lineDepth < depth) continue;
    final multipv = int.parse(match.group(2)!);
    byMultipv[multipv] = _PvScore(
      multipv: multipv,
      type: match.group(3)!,
      value: int.tryParse(match.group(4)!),
      firstMove: match.group(5),
    );
  }

  if (byMultipv.isEmpty) {
    RegExpMatch? scoreMatch;
    for (final match in RegExp(
      r'\bscore\s+(cp|mate)\s+(-?\d+).*?\bpv\s+([a-i](?:10|[1-9])[a-i](?:10|[1-9])[a-z]*)',
    ).allMatches(lines.join('\n'))) {
      scoreMatch = match;
    }
    if (scoreMatch != null) {
      byMultipv[1] = _PvScore(
        multipv: 1,
        type: scoreMatch.group(1)!,
        value: int.tryParse(scoreMatch.group(2)!),
        firstMove: scoreMatch.group(3),
      );
    }
  }

  final sorted = byMultipv.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return sorted.map((entry) => entry.value).toList(growable: false);
}
