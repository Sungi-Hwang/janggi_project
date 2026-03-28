import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options.workerMode) {
    final worker = _SinglePuzzleWorker(options);
    try {
      await worker.run();
    } finally {
      await worker.dispose();
    }
    return;
  }

  await _PuzzleQualityBatchRunner(options).run();
}

class _CliOptions {
  _CliOptions({
    required this.inputPath,
    required this.reportPath,
    required this.strictOutputPath,
    required this.depth,
    required this.multiPv,
    required this.limit,
    required this.engineLibraryPath,
    required this.workerMode,
    required this.workerId,
  });

  final String inputPath;
  final String reportPath;
  final String strictOutputPath;
  final int depth;
  final int multiPv;
  final int? limit;
  final String engineLibraryPath;
  final bool workerMode;
  final String? workerId;

  static _CliOptions parse(List<String> args) {
    String inputPath = 'assets/puzzles/puzzles.json';
    String reportPath = 'puzzle_quality_validation_v2.json';
    String strictOutputPath = 'assets/puzzles/puzzles_strict_preview.json';
    int depth = 12;
    int multiPv = 6;
    int? limit;
    bool workerMode = false;
    String? workerId;
    final defaultExe = Platform.isWindows
        ? 'engine/src/stockfish.exe'
        : 'engine/src/stockfish';
    String engineLibraryPath = File(defaultExe).existsSync()
        ? defaultExe
        : Platform.isWindows
            ? 'stockfish.dll'
            : 'libstockfish.so';

    for (int i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
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
        case '--multipv':
          multiPv = int.parse(args[++i]);
          break;
        case '--limit':
          limit = int.parse(args[++i]);
          break;
        case '--engine':
          engineLibraryPath = args[++i];
          break;
        case '--worker':
          workerMode = true;
          break;
        case '--id':
          workerId = args[++i];
          break;
        case '--help':
        case '-h':
          _printUsage();
          exit(0);
        default:
          stderr.writeln('Unknown argument: $arg');
          _printUsage();
          exit(64);
      }
    }

    return _CliOptions(
      inputPath: inputPath,
      reportPath: reportPath,
      strictOutputPath: strictOutputPath,
      depth: depth,
      multiPv: multiPv,
      limit: limit,
      engineLibraryPath: engineLibraryPath,
      workerMode: workerMode,
      workerId: workerId,
    );
  }

  static void _printUsage() {
    stdout.writeln('''
Usage: dart run tool/puzzle_quality_validator.dart [options]

Options:
  --input <path>          Input puzzle JSON (default: assets/puzzles/puzzles.json)
  --report <path>         Validation report output JSON
  --strict-output <path>  Strict-only preview JSON output
  --depth <n>             Engine search depth (default: 12)
  --multipv <n>           MultiPV count for uniqueness check (default: 6)
  --limit <n>             Validate only the first N puzzles
  --engine <path>         Engine path (recommended: engine/src/stockfish.exe)
  --worker                Internal: validate a single puzzle in a worker process
  --id <puzzle-id>        Puzzle id for worker mode
  --help                  Show this help
''');
  }
}

class _PuzzleQualityBatchRunner {
  _PuzzleQualityBatchRunner(this.options);

  final _CliOptions options;

  Future<void> run() async {
    final startedAt = DateTime.now();
    final document = _loadPuzzleDocument(options.inputPath);
    final sourcePuzzles = document.puzzles;
    final puzzles = options.limit == null
        ? sourcePuzzles
        : sourcePuzzles.take(options.limit!).toList(growable: false);

    stdout.writeln(
      'Validating ${puzzles.length} puzzles from ${options.inputPath} '
      '(depth=${options.depth}, multiPv=${options.multiPv})...',
    );

    final details = <Map<String, dynamic>>[];
    final strictPuzzles = <Map<String, dynamic>>[];

    for (int index = 0; index < puzzles.length; index++) {
      final puzzle = puzzles[index];
      stdout.writeln('[${index + 1}/${puzzles.length}] ${puzzle.id}');
      final result = _runWorker(puzzle);
      details.add(result);
      if (result['strictPass'] == true) {
        strictPuzzles.add({
          ...puzzle.raw,
          'validation': Map<String, dynamic>.from(
            result['validation'] as Map? ?? const <String, dynamic>{},
          ),
        });
      }
    }

    final summary = _buildSummary(
      inputPath: options.inputPath,
      startedAt: startedAt,
      checked: puzzles.length,
      sourceTotal: sourcePuzzles.length,
      depth: options.depth,
      multiPv: options.multiPv,
      details: details,
    );

    final report = {
      'summary': summary,
      'details': details,
    };
    _writeJson(options.reportPath, report);

    final strictDocument =
        document.copyWithPuzzles(strictPuzzles, generated: startedAt);
    _writeJson(options.strictOutputPath, strictDocument.toJson());

    stdout.writeln('Report written to ${options.reportPath}');
    stdout.writeln('Strict preview written to ${options.strictOutputPath}');
    stdout.writeln(jsonEncode(summary));
  }

  Map<String, dynamic> _runWorker(_PuzzleRecord puzzle) {
    final scriptPath = Platform.script.toFilePath();
    final result = Process.runSync(
      Platform.resolvedExecutable,
      <String>[
        scriptPath,
        '--worker',
        '--input',
        options.inputPath,
        '--id',
        puzzle.id,
        '--depth',
        '${options.depth}',
        '--multipv',
        '${options.multiPv}',
        '--engine',
        options.engineLibraryPath,
      ],
      workingDirectory: Directory.current.path,
    );

    final stdoutText = '${result.stdout}';
    final stderrText = '${result.stderr}';
    final jsonLines = stdoutText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.startsWith('{') && line.endsWith('}'))
        .toList(growable: false);
    final jsonLine = jsonLines.isEmpty ? null : jsonLines.last;

    if (jsonLine == null) {
      return {
        'id': puzzle.id,
        'title': puzzle.title,
        'mateIn': puzzle.mateIn,
        'strictPass': false,
        'relaxedPass': false,
        'forcedMateStart': false,
        'exactMateLengthStart': false,
        'solutionLengthMatches': false,
        'firstMoveMatches': false,
        'uniqueFirstMove': false,
        'sameMateCandidates': const <String>[],
        'branchUnique': false,
        'linePerfect': false,
        'finalMateResolved': false,
        'failReasons': <String>[
          'worker_no_json',
          if (result.exitCode != 0) 'worker_exit_${result.exitCode}',
        ],
        'workerExitCode': result.exitCode,
        'workerStdoutTail': _tail(stdoutText),
        'workerStderrTail': _tail(stderrText),
        'branchChecks': const <Map<String, dynamic>>[],
        'validation': const <String, dynamic>{},
      };
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(jsonLine) as Map);
    parsed['workerExitCode'] = result.exitCode;
    if (result.exitCode != 0) {
      final failReasons = List<String>.from(
          parsed['failReasons'] as List<dynamic>? ?? const []);
      failReasons.add('worker_exit_${result.exitCode}');
      parsed['failReasons'] = failReasons;
      parsed['strictPass'] = false;
      parsed['relaxedPass'] = false;
    }
    parsed['workerStdoutTail'] = _tail(stdoutText);
    parsed['workerStderrTail'] = _tail(stderrText);
    return parsed;
  }

  String _tail(String value, {int maxLength = 800}) {
    if (value.length <= maxLength) return value;
    return value.substring(value.length - maxLength);
  }
}

class _SinglePuzzleWorker {
  _SinglePuzzleWorker(this.options)
      : engine = _UciEngineClient(options.engineLibraryPath);

  final _CliOptions options;
  final _UciEngineClient engine;

  Future<void> run() async {
    if (options.workerId == null || options.workerId!.isEmpty) {
      throw ArgumentError('Worker mode requires --id');
    }

    final document = _loadPuzzleDocument(options.inputPath);
    final puzzle = document.puzzles.firstWhere(
      (item) => item.id == options.workerId,
      orElse: () =>
          throw ArgumentError('Puzzle not found: ${options.workerId}'),
    );

    await engine.initialize(multiPv: options.multiPv);
    final result = await _validatePuzzle(puzzle);
    stdout.writeln(jsonEncode(result.toJson()));
  }

  Future<_PuzzleValidationResult> _validatePuzzle(_PuzzleRecord puzzle) async {
    final solutionLengthExpected = puzzle.mateIn * 2 - 1;
    final solutionLengthMatches =
        puzzle.solution.length == solutionLengthExpected;

    _EvalResult? startEval;
    List<_PvLine> startPv = const <_PvLine>[];
    bool startAnalysisTimedOut = false;
    bool multiPvTimedOut = false;

    try {
      startEval = await engine.analyzePosition(
        puzzle.fen,
        const <String>[],
        options.depth,
      );
    } on TimeoutException {
      startAnalysisTimedOut = true;
    }

    try {
      startPv = await engine.analyzeMultiPv(
        puzzle.fen,
        const <String>[],
        options.depth,
        options.multiPv,
      );
    } on TimeoutException {
      multiPvTimedOut = true;
    }

    final forcedMateStart =
        startEval?.type == 'mate' && (startEval!.value ?? 0) > 0;
    final exactMateLengthStart =
        startEval?.type == 'mate' && startEval!.value == puzzle.mateIn;
    final firstMoveMatches = puzzle.solution.isNotEmpty &&
        startEval?.bestmove == puzzle.solution.first;

    final sameMateCandidates = startPv
        .where((line) =>
            line.scoreType == 'mate' && line.scoreValue == puzzle.mateIn)
        .map((line) => line.firstMove)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    final uniqueFirstMove = sameMateCandidates.length == 1 &&
        sameMateCandidates.first == puzzle.solution.first;

    final lineChecks = <Map<String, dynamic>>[];
    final branchChecks = <Map<String, dynamic>>[];
    final movesSoFar = <String>[];
    bool linePerfect = true;
    bool lineAnalysisTimedOut = false;
    bool branchUnique = true;
    bool branchAnalysisTimedOut = false;
    for (int ply = 0; ply < puzzle.solution.length; ply++) {
      final expectedMove = puzzle.solution[ply];

      if (ply.isEven) {
        final remainingMateLength = ((puzzle.solution.length - ply) + 1) ~/ 2;
        List<_PvLine> branchPv = const <_PvLine>[];
        bool timedOutThisPly = false;

        try {
          branchPv = await engine.analyzeMultiPv(
            puzzle.fen,
            movesSoFar,
            options.depth,
            options.multiPv,
          );
        } on TimeoutException {
          branchAnalysisTimedOut = true;
          timedOutThisPly = true;
        }

        final sameBranchCandidates = branchPv
            .where((line) =>
                line.scoreType == 'mate' &&
                line.scoreValue == remainingMateLength)
            .map((line) => line.firstMove)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();

        final uniqueAtBranch = !timedOutThisPly &&
            sameBranchCandidates.length == 1 &&
            sameBranchCandidates.first == expectedMove;

        if (!uniqueAtBranch) {
          branchUnique = false;
        }

        branchChecks.add({
          'ply': ply + 1,
          'expectedMove': expectedMove,
          'expectedMateLength': remainingMateLength,
          'sameMateCandidates': sameBranchCandidates,
          'unique': uniqueAtBranch,
          'timedOut': timedOutThisPly,
        });
      }

      _EvalResult? eval;
      try {
        eval = await engine.analyzePosition(
          puzzle.fen,
          movesSoFar,
          options.depth,
        );
      } on TimeoutException {
        lineAnalysisTimedOut = true;
      }
      final matches = eval?.bestmove == expectedMove;
      if (!matches || lineAnalysisTimedOut) {
        linePerfect = false;
      }

      lineChecks.add({
        'ply': ply + 1,
        'expectedMove': expectedMove,
        'engineBestMove': eval?.bestmove,
        'scoreType': eval?.type,
        'scoreValue': eval?.value,
        'matches': matches,
      });

      movesSoFar.add(expectedMove);

      if (lineAnalysisTimedOut) {
        break;
      }
    }

    _EvalResult? finalEval;
    bool finalAnalysisTimedOut = false;
    try {
      finalEval = await engine.analyzePosition(
        puzzle.fen,
        puzzle.solution,
        options.depth,
      );
    } on TimeoutException {
      finalAnalysisTimedOut = true;
    }
    final finalMateResolved =
        finalEval?.type == 'mate' && finalEval?.value == 0;

    final failReasons = <String>[];
    if (!solutionLengthMatches) failReasons.add('solution_length_mismatch');
    if (!forcedMateStart) failReasons.add('start_not_forced_mate');
    if (!exactMateLengthStart) failReasons.add('start_mate_length_mismatch');
    if (startAnalysisTimedOut) failReasons.add('start_analysis_timeout');
    if (multiPvTimedOut) failReasons.add('multipv_timeout');
    if (!firstMoveMatches) failReasons.add('first_move_mismatch');
    if (!uniqueFirstMove) {
      failReasons.add(
        multiPvTimedOut
            ? 'first_move_uniqueness_unknown'
            : 'non_unique_first_move',
      );
    }
    if (lineAnalysisTimedOut) {
      failReasons.add('line_analysis_timeout');
    } else if (!linePerfect) {
      failReasons.add('line_not_engine_perfect');
    }
    if (branchAnalysisTimedOut) {
      failReasons.add('branch_uniqueness_timeout');
    } else if (!branchUnique) {
      failReasons.add('non_unique_branch_move');
    }
    if (finalAnalysisTimedOut) {
      failReasons.add('final_analysis_timeout');
    } else if (!finalMateResolved) {
      failReasons.add('final_position_not_checkmate');
    }

    final strictPass = failReasons.isEmpty;
    final relaxedPass = forcedMateStart &&
        exactMateLengthStart &&
        firstMoveMatches &&
        finalMateResolved;

    return _PuzzleValidationResult(
      id: puzzle.id,
      mateIn: puzzle.mateIn,
      title: puzzle.title,
      strictPass: strictPass,
      relaxedPass: relaxedPass,
      forcedMateStart: forcedMateStart,
      exactMateLengthStart: exactMateLengthStart,
      solutionLengthMatches: solutionLengthMatches,
      firstMoveMatches: firstMoveMatches,
        uniqueFirstMove: uniqueFirstMove,
        sameMateCandidates: sameMateCandidates,
        branchUnique: branchUnique,
        linePerfect: linePerfect,
        finalMateResolved: finalMateResolved,
        failReasons: failReasons,
        startEval: startEval,
        finalEval: finalEval,
        lineChecks: lineChecks,
        branchChecks: branchChecks,
      );
  }

  Future<void> dispose() {
    return engine.dispose();
  }
}

Map<String, dynamic> _buildSummary({
  required String inputPath,
  required DateTime startedAt,
  required int checked,
  required int sourceTotal,
  required int depth,
  required int multiPv,
  required List<Map<String, dynamic>> details,
}) {
  int countTrue(String key) =>
      details.where((item) => item[key] == true).length;

  final failReasonCounts = <String, int>{};
  for (final item in details) {
    final reasons = (item['failReasons'] as List<dynamic>? ?? const <dynamic>[])
        .cast<String>();
    for (final reason in reasons) {
      failReasonCounts[reason] = (failReasonCounts[reason] ?? 0) + 1;
    }
  }

  final sortedFailReasons = failReasonCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return {
    'generatedAt': startedAt.toIso8601String(),
    'input': inputPath,
    'sourceTotal': sourceTotal,
    'checked': checked,
    'depth': depth,
    'multiPv': multiPv,
    'strictPass': countTrue('strictPass'),
    'relaxedPass': countTrue('relaxedPass'),
    'forcedMateStart': countTrue('forcedMateStart'),
    'exactMateLengthStart': countTrue('exactMateLengthStart'),
    'solutionLengthMatches': countTrue('solutionLengthMatches'),
    'firstMoveMatches': countTrue('firstMoveMatches'),
    'uniqueFirstMove': countTrue('uniqueFirstMove'),
    'branchUnique': countTrue('branchUnique'),
    'linePerfect': countTrue('linePerfect'),
    'finalMateResolved': countTrue('finalMateResolved'),
    'failReasons': sortedFailReasons
        .map((entry) => {'reason': entry.key, 'count': entry.value})
        .toList(growable: false),
  };
}

_PuzzleDocument _loadPuzzleDocument(String inputPath) {
  final file = File(inputPath);
  if (!file.existsSync()) {
    throw FileSystemException('Input puzzle file not found', inputPath);
  }

  final raw = file.readAsStringSync(encoding: utf8);
  final normalized = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
  final decoded = jsonDecode(normalized);

  if (decoded is Map<String, dynamic>) {
    final puzzles = (decoded['puzzles'] as List<dynamic>)
        .map((item) =>
            _PuzzleRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
    return _PuzzleDocument(
      raw: decoded,
      puzzles: puzzles,
    );
  }

  if (decoded is List<dynamic>) {
    final puzzles = decoded
        .map((item) =>
            _PuzzleRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
    return _PuzzleDocument(
      raw: <String, dynamic>{},
      puzzles: puzzles,
    );
  }

  throw FormatException('Unsupported puzzle JSON structure in $inputPath');
}

void _writeJson(String path, Object data) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(data)}\n', encoding: utf8);
}

class _PuzzleDocument {
  _PuzzleDocument({
    required this.raw,
    required this.puzzles,
  });

  final Map<String, dynamic> raw;
  final List<_PuzzleRecord> puzzles;

  _PuzzleDocument copyWithPuzzles(List<Map<String, dynamic>> puzzles,
      {required DateTime generated}) {
    final copy = <String, dynamic>{...raw};
    final categories =
        Map<String, dynamic>.from(copy['categories'] as Map? ?? const {});
    final counts = <String, int>{
      'mate1': 0,
      'mate2': 0,
      'mate3': 0,
    };
    for (final puzzle in puzzles) {
      final mateIn = puzzle['mateIn'];
      if (mateIn is int && mateIn >= 1 && mateIn <= 3) {
        counts['mate$mateIn'] = (counts['mate$mateIn'] ?? 0) + 1;
      }
    }
    for (final entry in counts.entries) {
      final category =
          Map<String, dynamic>.from(categories[entry.key] as Map? ?? const {});
      category['count'] = entry.value;
      categories[entry.key] = category;
    }
    copy['categories'] = categories;
    copy['generated'] = generated.toIso8601String();
    copy['total'] = puzzles.length;
    copy['version'] = '${copy['version'] ?? '1.1'}-validated';
    copy['puzzles'] = puzzles;
    return _PuzzleDocument(
      raw: copy,
      puzzles: const <_PuzzleRecord>[],
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class _PuzzleRecord {
  _PuzzleRecord({
    required this.id,
    required this.title,
    required this.mateIn,
    required this.fen,
    required this.solution,
    required this.raw,
  });

  final String id;
  final String title;
  final int mateIn;
  final String fen;
  final List<String> solution;
  final Map<String, dynamic> raw;

  factory _PuzzleRecord.fromJson(Map<String, dynamic> json) {
    return _PuzzleRecord(
      id: json['id'] as String,
      title: json['title'] as String? ?? json['id'] as String,
      mateIn: json['mateIn'] as int,
      fen: json['fen'] as String,
      solution: List<String>.from(json['solution'] as List<dynamic>),
      raw: json,
    );
  }
}

class _PuzzleValidationResult {
  _PuzzleValidationResult({
    required this.id,
    required this.mateIn,
    required this.title,
    required this.strictPass,
    required this.relaxedPass,
    required this.forcedMateStart,
    required this.exactMateLengthStart,
    required this.solutionLengthMatches,
    required this.firstMoveMatches,
    required this.uniqueFirstMove,
    required this.sameMateCandidates,
    required this.branchUnique,
    required this.linePerfect,
    required this.finalMateResolved,
    required this.failReasons,
    required this.startEval,
    required this.finalEval,
    required this.lineChecks,
    required this.branchChecks,
  });

  final String id;
  final int mateIn;
  final String title;
  final bool strictPass;
  final bool relaxedPass;
  final bool forcedMateStart;
  final bool exactMateLengthStart;
  final bool solutionLengthMatches;
  final bool firstMoveMatches;
  final bool uniqueFirstMove;
  final List<String> sameMateCandidates;
  final bool branchUnique;
  final bool linePerfect;
  final bool finalMateResolved;
  final List<String> failReasons;
  final _EvalResult? startEval;
  final _EvalResult? finalEval;
  final List<Map<String, dynamic>> lineChecks;
  final List<Map<String, dynamic>> branchChecks;

  Map<String, dynamic> validationMetadata() => {
        'strictPass': strictPass,
        'relaxedPass': relaxedPass,
        'forcedMateStart': forcedMateStart,
        'exactMateLengthStart': exactMateLengthStart,
        'solutionLengthMatches': solutionLengthMatches,
        'firstMoveMatches': firstMoveMatches,
        'uniqueFirstMove': uniqueFirstMove,
        'sameMateCandidates': sameMateCandidates,
        'branchUnique': branchUnique,
        'linePerfect': linePerfect,
        'finalMateResolved': finalMateResolved,
        'depth': startEval?.depth,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'mateIn': mateIn,
        'strictPass': strictPass,
        'relaxedPass': relaxedPass,
        'forcedMateStart': forcedMateStart,
        'exactMateLengthStart': exactMateLengthStart,
        'solutionLengthMatches': solutionLengthMatches,
        'firstMoveMatches': firstMoveMatches,
        'uniqueFirstMove': uniqueFirstMove,
        'sameMateCandidates': sameMateCandidates,
        'branchUnique': branchUnique,
        'linePerfect': linePerfect,
        'finalMateResolved': finalMateResolved,
        'failReasons': failReasons,
        'startEval': startEval?.toJson(),
        'finalEval': finalEval?.toJson(),
        'lineChecks': lineChecks,
        'branchChecks': branchChecks,
        'validation': validationMetadata(),
      };
}

class _UciEngineClient {
  _UciEngineClient(this.enginePath);

  final String enginePath;

  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Completer<List<String>>? _pendingResponse;
  bool Function(String line)? _responseComplete;
  List<String> _capturedLines = const <String>[];
  final List<String> _stderrTail = <String>[];
  int _configuredMultiPv = 1;

  Future<void> initialize({required int multiPv}) async {
    if (_process != null) return;

    final executable = File(enginePath);
    if (!executable.existsSync()) {
      throw FileSystemException('Engine executable not found', enginePath);
    }

    _process = await Process.start(
      executable.path,
      const <String>[],
      workingDirectory: executable.parent.path,
    );

    _stdoutSubscription = _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStdoutLine);
    _stderrSubscription = _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStderrLine);

    await _sendAndWait('uci', until: (line) => line == 'uciok');
    await _sendCommand('setoption name UCI_Variant value janggi');
    await _sendCommand('setoption name Threads value 1');
    await _sendCommand('setoption name Hash value 128');
    await _ensureMultiPv(multiPv);
    await _waitReady();
    await _sendCommand('ucinewgame');
    await _waitReady();
  }

  Future<_EvalResult?> analyzePosition(
    String fen,
    List<String> moves,
    int depth,
  ) async {
    _ensureInitialized();
    await _ensureMultiPv(1);
    await _setPosition(fen, moves);
    final lines = await _sendAndWait(
      'go depth $depth',
      until: (line) => line.startsWith('bestmove '),
    );
    return _EvalResult.fromUciLines(lines, depth: depth);
  }

  Future<List<_PvLine>> analyzeMultiPv(
    String fen,
    List<String> moves,
    int depth,
    int multiPv,
  ) async {
    _ensureInitialized();
    await _ensureMultiPv(multiPv);
    await _setPosition(fen, moves);
    final lines = await _sendAndWait(
      'go depth $depth',
      until: (line) => line.startsWith('bestmove '),
    );
    return _PvLine.parseAll(lines.join('\n'));
  }

  Future<void> dispose() async {
    final process = _process;
    if (process == null) return;

    try {
      process.stdin.writeln('quit');
      process.stdin.close();
    } catch (_) {
      // Best-effort shutdown only.
    }

    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _process = null;
  }

  Future<void> _ensureMultiPv(int multiPv) async {
    if (_configuredMultiPv == multiPv) return;
    await _sendCommand('setoption name MultiPV value $multiPv');
    await _waitReady();
    _configuredMultiPv = multiPv;
  }

  Future<void> _setPosition(String fen, List<String> moves) async {
    final command = moves.isEmpty
        ? 'position fen $fen'
        : 'position fen $fen moves ${moves.join(' ')}';
    await _sendCommand(command);
    await _waitReady();
  }

  Future<void> _sendCommand(String command) async {
    _ensureInitialized();
    _process!.stdin.writeln(command);
  }

  Future<void> _waitReady() async {
    await _sendAndWait('isready', until: (line) => line == 'readyok');
  }

  Future<List<String>> _sendAndWait(
    String command, {
    required bool Function(String line) until,
  }) async {
    _ensureInitialized();
    if (_pendingResponse != null) {
      throw StateError('Engine already has a pending command');
    }

    final completer = Completer<List<String>>();
    _pendingResponse = completer;
    _responseComplete = until;
    _capturedLines = <String>[];
    _process!.stdin.writeln(command);

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingResponse = null;
        _responseComplete = null;
        _capturedLines = const <String>[];
        throw TimeoutException(
            'Timed out waiting for engine response: $command');
      },
    );
  }

  void _handleStdoutLine(String line) {
    final completer = _pendingResponse;
    if (completer == null) {
      return;
    }

    _capturedLines.add(line);
    if (_responseComplete?.call(line) != true) {
      return;
    }

    final captured = List<String>.from(_capturedLines);
    _pendingResponse = null;
    _responseComplete = null;
    _capturedLines = const <String>[];
    if (!completer.isCompleted) {
      completer.complete(captured);
    }
  }

  void _handleStderrLine(String line) {
    _stderrTail.add(line);
    if (_stderrTail.length > 40) {
      _stderrTail.removeAt(0);
    }
  }

  void _ensureInitialized() {
    if (_process == null) {
      throw StateError('Engine not initialized');
    }
  }
}

class _EvalResult {
  _EvalResult({
    required this.type,
    required this.value,
    required this.bestmove,
    required this.raw,
    required this.depth,
  });

  final String type;
  final int? value;
  final String? bestmove;
  final String raw;
  final int depth;

  factory _EvalResult.fromUciLines(
    List<String> lines, {
    required int depth,
  }) {
    final bestmoveLine = lines.lastWhere(
      (line) => line.startsWith('bestmove '),
      orElse: () => '',
    );
    final bestmoveMatch =
        RegExp(r'^bestmove\s+([a-i](?:10|[1-9])[a-i](?:10|[1-9])[a-z]*)')
            .firstMatch(bestmoveLine);

    final infoLines = _PvLine.parseAll(lines.join('\n'));
    _PvLine? bestLine;
    for (final line in infoLines) {
      if (line.multiPv == 1) {
        bestLine = line;
      }
    }
    bestLine ??= infoLines.isEmpty ? null : infoLines.last;
    RegExpMatch? scoreMatch;
    for (final match in RegExp(r'\bscore\s+(cp|mate)\s+(-?\d+)')
        .allMatches(lines.join('\n'))) {
      scoreMatch = match;
    }

    return _EvalResult(
      type: bestLine?.scoreType ?? scoreMatch?.group(1) ?? 'unknown',
      value: bestLine?.scoreValue ?? int.tryParse(scoreMatch?.group(2) ?? ''),
      bestmove: bestmoveMatch?.group(1) ?? bestLine?.firstMove,
      raw: lines.join('\n'),
      depth: depth,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'bestmove': bestmove,
        'depth': depth,
        'raw': raw,
      };
}

class _PvLine {
  _PvLine({
    required this.multiPv,
    required this.scoreType,
    required this.scoreValue,
    required this.firstMove,
    required this.raw,
  });

  final int multiPv;
  final String? scoreType;
  final int? scoreValue;
  final String? firstMove;
  final String raw;

  static List<_PvLine> parseAll(String raw) {
    final lines = <_PvLine>[];
    for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (!line.startsWith('info ')) continue;
      if (!line.contains(' pv ')) continue;
      if (!line.contains(' score ')) continue;

      final multiPvMatch = RegExp(r'\bmultipv\s+(\d+)').firstMatch(line);
      final scoreMatch =
          RegExp(r'\bscore\s+(cp|mate)\s+(-?\d+)').firstMatch(line);
      final pvMatch =
          RegExp(r'\bpv\s+([a-i](?:10|[1-9])[a-i](?:10|[1-9])[a-z]*)')
              .firstMatch(line);
      if (multiPvMatch == null && scoreMatch == null && pvMatch == null) {
        continue;
      }

      lines.add(
        _PvLine(
          multiPv: int.tryParse(multiPvMatch?.group(1) ?? '') ?? 1,
          scoreType: scoreMatch?.group(1),
          scoreValue: int.tryParse(scoreMatch?.group(2) ?? ''),
          firstMove: pvMatch?.group(1),
          raw: line,
        ),
      );
    }

    final deduped = <int, _PvLine>{};
    for (final line in lines) {
      deduped[line.multiPv] = line;
    }
    final result = deduped.values.toList()
      ..sort((a, b) => a.multiPv.compareTo(b.multiPv));
    return result;
  }
}
