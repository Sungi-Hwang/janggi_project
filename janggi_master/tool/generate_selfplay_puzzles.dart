import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:janggi_master/models/board.dart';
import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/position.dart';
import 'package:janggi_master/utils/stockfish_converter.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  final generator = _SelfPlayPuzzleGenerator(options);
  try {
    await generator.run();
  } finally {
    await generator.dispose();
  }
}

class _CliOptions {
  _CliOptions({
    required this.outputPath,
    required this.enginePath,
    required this.targetCount,
    required this.maxGames,
    required this.maxPly,
    required this.playDepth,
    required this.probeDepth,
    required this.solveDepth,
    required this.multiPv,
    required this.seed,
    required this.mode,
    required this.targetMate,
    required this.allowedMates,
    required this.minPieces,
    required this.targetMate3Percent,
    required this.scanDuringGameEvery,
    required this.scanRecentCount,
    required this.richStarts,
    required this.checkpoint,
    required this.tailCandidatesOnly,
  });

  final String outputPath;
  final String enginePath;
  final int targetCount;
  final int maxGames;
  final int maxPly;
  final int playDepth;
  final int probeDepth;
  final int solveDepth;
  final int multiPv;
  final int seed;
  final String mode;
  final int targetMate;
  final Set<int> allowedMates;
  final int minPieces;
  final int targetMate3Percent;
  final int scanDuringGameEvery;
  final int scanRecentCount;
  final bool richStarts;
  final bool checkpoint;
  final bool tailCandidatesOnly;

  static _CliOptions parse(List<String> args) {
    final defaultExe = Platform.isWindows
        ? 'engine/src/stockfish.exe'
        : 'engine/src/stockfish';

    var outputPath = 'dev/test_tmp/selfplay_puzzles.json';
    var enginePath = defaultExe;
    var targetCount = 10;
    var maxGames = 24;
    var maxPly = 140;
    var playDepth = 5;
    var probeDepth = 8;
    var solveDepth = 10;
    var multiPv = 4;
    var seed = 20260321;
    var mode = 'weak-strong';
    var targetMate = 3;
    var allowedMates = <int>{3};
    var allowedMatesExplicit = false;
    var minPieces = 10;
    var targetMate3Percent = 100;
    var scanDuringGameEvery = 12;
    var scanRecentCount = 16;
    var richStarts = true;
    var checkpoint = true;
    var tailCandidatesOnly = false;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--output':
          outputPath = args[++i];
          break;
        case '--engine':
          enginePath = args[++i];
          break;
        case '--count':
          targetCount = int.parse(args[++i]);
          break;
        case '--games':
          maxGames = int.parse(args[++i]);
          break;
        case '--max-ply':
          maxPly = int.parse(args[++i]);
          break;
        case '--play-depth':
          playDepth = int.parse(args[++i]);
          break;
        case '--probe-depth':
          probeDepth = int.parse(args[++i]);
          break;
        case '--solve-depth':
          solveDepth = int.parse(args[++i]);
          break;
        case '--multipv':
          multiPv = int.parse(args[++i]);
          break;
        case '--seed':
          seed = int.parse(args[++i]);
          break;
        case '--mode':
          mode = args[++i];
          if (!const {'balanced', 'weak-strong'}.contains(mode)) {
            stderr.writeln('--mode must be balanced or weak-strong');
            exit(64);
          }
          break;
        case '--target-mate':
          targetMate = int.parse(args[++i]);
          if (targetMate < 1 || targetMate > 3) {
            stderr.writeln('--target-mate must be 1, 2, or 3');
            exit(64);
          }
          if (!allowedMatesExplicit) {
            allowedMates = <int>{targetMate};
          }
          break;
        case '--allowed-mates':
          allowedMatesExplicit = true;
          allowedMates = args[++i]
              .split(',')
              .map((value) => int.tryParse(value.trim()))
              .whereType<int>()
              .where((value) => value >= 1 && value <= 3)
              .toSet();
          if (allowedMates.isEmpty) {
            stderr
                .writeln('--allowed-mates must contain at least one of 1,2,3');
            exit(64);
          }
          break;
        case '--min-pieces':
          minPieces = int.parse(args[++i]);
          break;
        case '--target-mate3-percent':
          targetMate3Percent = int.parse(args[++i]);
          if (targetMate3Percent < 0 || targetMate3Percent > 100) {
            stderr.writeln('--target-mate3-percent must be between 0 and 100');
            exit(64);
          }
          break;
        case '--scan-during-game-every':
          scanDuringGameEvery = int.parse(args[++i]);
          break;
        case '--scan-recent':
          scanRecentCount = int.parse(args[++i]);
          break;
        case '--rich-starts':
          richStarts = true;
          break;
        case '--no-rich-starts':
          richStarts = false;
          break;
        case '--checkpoint':
          checkpoint = true;
          break;
        case '--no-checkpoint':
          checkpoint = false;
          break;
        case '--tail-candidates-only':
          tailCandidatesOnly = true;
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

    return _CliOptions(
      outputPath: outputPath,
      enginePath: enginePath,
      targetCount: targetCount,
      maxGames: maxGames,
      maxPly: maxPly,
      playDepth: playDepth,
      probeDepth: probeDepth,
      solveDepth: solveDepth,
      multiPv: multiPv,
      seed: seed,
      mode: mode,
      targetMate: targetMate,
      allowedMates: allowedMates,
      minPieces: minPieces,
      targetMate3Percent: targetMate3Percent,
      scanDuringGameEvery: scanDuringGameEvery,
      scanRecentCount: scanRecentCount,
      richStarts: richStarts,
      checkpoint: checkpoint,
      tailCandidatesOnly: tailCandidatesOnly,
    );
  }

  static void _printUsage() {
    stdout.writeln('''
Usage: dart run tool/generate_selfplay_puzzles.dart [options]

Options:
  --output <path>       Output puzzle catalog JSON
  --engine <path>       Engine path (default: engine/src/stockfish.exe)
  --count <n>           Number of puzzles to extract (default: 10)
  --games <n>           Max self-play games to try (default: 24)
  --max-ply <n>         Max plies per game (default: 140)
  --play-depth <n>      Search depth for self-play moves (default: 5)
  --probe-depth <n>     Search depth for mate probe (default: 8)
  --solve-depth <n>     Search depth for solution line generation (default: 10)
  --multipv <n>         MultiPV used for move variety (default: 4)
  --seed <n>            Random seed (default: 20260321)
  --mode <name>         balanced or weak-strong (default: weak-strong)
  --target-mate <n>     Mate length to mine when --allowed-mates is omitted
                        (default: 3)
  --allowed-mates <csv> Mate lengths to accept, e.g. 3 (default: 3)
  --min-pieces <n>      Minimum total pieces in the FEN before probing
                        (default: 10)
  --target-mate3-percent <n>
                        Target share of 3-move puzzles when 2 and 3 are allowed
                        (default: 100)
  --scan-during-game-every <n>
                        Also scan recent positions every n plies (default: 12)
  --scan-recent <n>     Number of recent positions to scan (default: 16)
  --rich-starts         Keep more material in randomized starts for deeper puzzles
  --no-rich-starts      Disable rich randomized starts
  --checkpoint          Save checkpoint JSON whenever a puzzle is found
                        (default: on)
  --no-checkpoint       Only write final output
  --tail-candidates-only
                        Save unverified final 5-ply game tails as mate-3
                        candidates for later engine validation
''');
  }
}

class _SelfPlayPuzzleGenerator {
  _SelfPlayPuzzleGenerator(this.options)
      : _random = Random(options.seed),
        _engine = _UciEngineClient(options.enginePath);

  static const String _startFen =
      'rnbakabnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBAKABNR w - - 0 1';

  final _CliOptions options;
  final Random _random;
  final _UciEngineClient _engine;
  final Set<String> _seenPositions = <String>{};
  final Set<String> _scannedPositions = <String>{};
  final List<Map<String, dynamic>> _puzzles = <Map<String, dynamic>>[];

  Future<void> run() async {
    stdout.writeln(
      'Generating ${options.targetCount} self-play puzzles '
      '(mode=${options.mode}, targetMate=${options.targetMate}, '
      'games=${options.maxGames}, maxPly=${options.maxPly}, seed=${options.seed})...',
    );

    for (var gameIndex = 1;
        gameIndex <= options.maxGames && _puzzles.length < options.targetCount;
        gameIndex++) {
      await _engine.dispose();
      await _engine.initialize(multiPv: max(3, options.multiPv));
      try {
        await _playSingleGame(gameIndex);
      } on TimeoutException catch (error) {
        stdout
            .writeln('Game $gameIndex skipped after timeout: ${error.message}');
      }
    }

    final document = _buildDocument();
    _writeJson(options.outputPath, document);

    stdout.writeln(
      'Generated ${_puzzles.length} puzzles -> ${options.outputPath}',
    );
    stdout.writeln(jsonEncode({
      'generated': _puzzles.length,
      'target': options.targetCount,
      'gamesTried': options.maxGames,
      'output': options.outputPath,
    }));
  }

  Future<void> _playSingleGame(int gameIndex) async {
    var currentFen = await _buildStartFen(gameIndex);
    final seenInGame = <String, int>{_fenKey(currentFen): 1};
    final history = <_RecordedPosition>[
      _RecordedPosition(fen: currentFen, ply: 1),
    ];
    final playedMoves = <String>[];

    stdout.writeln(
      'Self-play game $gameIndex started '
      '(found=${_puzzles.length}/${options.targetCount})',
    );

    for (var ply = 1; ply <= options.maxPly; ply++) {
      if (_puzzles.length >= options.targetCount) {
        return;
      }

      final move = await _chooseSelfPlayMove(
        fen: currentFen,
        gameIndex: gameIndex,
        ply: ply,
      );

      if (move == null) {
        stdout.writeln('Game $gameIndex stopped at ply $ply: no move');
        if (options.tailCandidatesOnly) {
          _addTailCandidate(
            gameIndex: gameIndex,
            terminalPly: ply,
            history: history,
            playedMoves: playedMoves,
          );
        } else {
          await _scanRecentPositions(gameIndex, history);
        }
        return;
      }

      final nextFen = await _engine.applyMoveAndGetFen(currentFen, move);
      if (nextFen == null) {
        stdout.writeln(
            'Game $gameIndex stopped at ply $ply: failed to resolve FEN');
        return;
      }

      currentFen = nextFen;
      playedMoves.add(move);
      history.add(_RecordedPosition(fen: currentFen, ply: ply + 1));

      if (!options.tailCandidatesOnly &&
          options.scanDuringGameEvery > 0 &&
          ply % options.scanDuringGameEvery == 0) {
        await _scanRecentPositions(gameIndex, history);
      }

      final key = _fenKey(currentFen);
      final repetition = (seenInGame[key] ?? 0) + 1;
      seenInGame[key] = repetition;
      if (repetition >= 3) {
        stdout.writeln('Game $gameIndex stopped at ply $ply: repetition');
        if (!options.tailCandidatesOnly) {
          await _scanRecentPositions(gameIndex, history);
        }
        return;
      }
    }

    if (!options.tailCandidatesOnly) {
      await _scanRecentPositions(gameIndex, history);
    }
  }

  void _addTailCandidate({
    required int gameIndex,
    required int terminalPly,
    required List<_RecordedPosition> history,
    required List<String> playedMoves,
  }) {
    const tailLength = 5;
    if (!options.allowedMates.contains(3) || playedMoves.length < tailLength) {
      return;
    }
    if (!_canAcceptMateIn(3)) return;

    final startMoveIndex = playedMoves.length - tailLength;
    final startRecord = history[startMoveIndex];
    final solution = playedMoves.sublist(startMoveIndex);
    if (solution.length != tailLength) return;

    final key = _fenKey(startRecord.fen);
    if (!_seenPositions.add(key)) return;
    if (options.minPieces > 0 &&
        _pieceCountFromFen(startRecord.fen) < options.minPieces) {
      return;
    }

    final puzzleNumber = _puzzles.length + 1;
    final puzzle = <String, dynamic>{
      'id': 'sp_tail_${puzzleNumber.toString().padLeft(4, '0')}',
      'difficulty': 3,
      'mateIn': 3,
      'title': 'Self-play tail 3-move candidate #$puzzleNumber',
      'fen': startRecord.fen,
      'solution': solution,
      'toMove': _sideFromFen(startRecord.fen),
      'source':
          'Weak-strong self-play Game $gameIndex, Tail before ply $terminalPly',
      'generator': {
        'type': 'self_play_tail_candidate',
        'mode': options.mode,
        'targetMate': 3,
        'gameIndex': gameIndex,
        'startPly': startRecord.ply,
        'terminalPly': terminalPly,
        'seed': options.seed,
        'playDepth': options.playDepth,
      },
    };
    _puzzles.add(puzzle);
    if (options.checkpoint) {
      _writeJson(options.outputPath, _buildDocument());
    }
    stdout.writeln(
      'Tail candidate ${_puzzles.length}/${options.targetCount}: '
      '${puzzle['id']} source=${puzzle['source']}',
    );
  }

  Future<String> _buildStartFen(int gameIndex) async {
    for (var attempt = 0; attempt < 24; attempt++) {
      final board = Board();
      board.setupInitialPosition();

      final removable = <Position>[];
      for (var rank = 0; rank < 10; rank++) {
        for (var file = 0; file < 9; file++) {
          final pos = Position(file: file, rank: rank);
          final piece = board.getPiece(pos);
          if (piece == null || piece.type == PieceType.general) {
            continue;
          }
          removable.add(pos);
        }
      }

      removable.shuffle(_random);
      for (final pos in removable) {
        final piece = board.getPiece(pos);
        if (piece == null) continue;

        final keepChance = options.richStarts
            ? switch (piece.type) {
                PieceType.guard => 0.75,
                PieceType.chariot => 0.72,
                PieceType.cannon => 0.68,
                PieceType.horse => 0.66,
                PieceType.elephant => 0.62,
                PieceType.soldier => 0.55,
                PieceType.general => 1.0,
              }
            : switch (piece.type) {
                PieceType.guard => 0.35,
                PieceType.chariot => 0.35,
                PieceType.cannon => 0.30,
                PieceType.horse => 0.28,
                PieceType.elephant => 0.24,
                PieceType.soldier => 0.20,
                PieceType.general => 1.0,
              };

        if (_random.nextDouble() > keepChance) {
          board.setPiece(pos, null);
        }
      }

      _ensureMinimumMaterial(board, PieceColor.blue);
      _ensureMinimumMaterial(board, PieceColor.red);

      final currentPlayer =
          (gameIndex + attempt).isEven ? PieceColor.blue : PieceColor.red;
      final fen = StockfishConverter.boardToFEN(board, currentPlayer);
      final legalMoves = await _engine.listLegalMoves(fen);
      if (legalMoves.isNotEmpty) {
        return fen;
      }
    }

    return _startFen;
  }

  void _ensureMinimumMaterial(Board board, PieceColor color) {
    final pieces = <Position>[];
    final reserves = <Position>[];

    for (var rank = 0; rank < 10; rank++) {
      for (var file = 0; file < 9; file++) {
        final pos = Position(file: file, rank: rank);
        final piece = board.getPiece(pos);
        if (piece == null ||
            piece.color != color ||
            piece.type == PieceType.general) {
          continue;
        }
        pieces.add(pos);
      }
    }

    final requiredPieces = options.richStarts ? 4 : 2;
    if (pieces.length >= requiredPieces) {
      return;
    }

    final template = Board();
    template.setupInitialPosition();
    for (var rank = 0; rank < 10; rank++) {
      for (var file = 0; file < 9; file++) {
        final pos = Position(file: file, rank: rank);
        final piece = template.getPiece(pos);
        if (piece == null ||
            piece.color != color ||
            piece.type == PieceType.general) {
          continue;
        }
        if (board.getPiece(pos) == null) {
          reserves.add(pos);
        }
      }
    }

    reserves.shuffle(_random);
    while (pieces.length < requiredPieces && reserves.isNotEmpty) {
      final pos = reserves.removeLast();
      final templatePiece = template.getPiece(pos);
      if (templatePiece != null) {
        board.setPiece(pos, templatePiece);
        pieces.add(pos);
      }
    }
  }

  Future<void> _scanRecentPositions(
    int gameIndex,
    List<_RecordedPosition> history,
  ) async {
    if (_puzzles.length >= options.targetCount) return;

    final recent =
        history.reversed.take(options.scanRecentCount).toList(growable: false);
    for (final record in recent) {
      if (_puzzles.length >= options.targetCount) return;
      try {
        final found = await _tryExtractPuzzle(
          fen: record.fen,
          gameIndex: gameIndex,
          ply: record.ply,
        );
        if (found && _puzzles.length >= options.targetCount) {
          return;
        }
      } on TimeoutException {
        // Skip slow endgame positions and continue.
      }
    }
  }

  Future<bool> _tryExtractPuzzle({
    required String fen,
    required int gameIndex,
    required int ply,
  }) async {
    final key = _fenKey(fen);
    if (_seenPositions.contains(key) || _scannedPositions.contains(key)) {
      return false;
    }
    _scannedPositions.add(key);
    if (options.minPieces > 0 && _pieceCountFromFen(fen) < options.minPieces) {
      return false;
    }
    final rootEval = await _engine.analyzePosition(fen, options.probeDepth);
    final rootMateIn = _mateInFromRootScore(rootEval?.value);
    if (rootEval?.type != 'mate' ||
        rootMateIn == null ||
        !options.allowedMates.contains(rootMateIn)) {
      return false;
    }

    final candidate = await _findShortestMateCandidate(fen);
    if (candidate == null) {
      return false;
    }
    if (!_canAcceptMateIn(candidate.mateIn)) {
      return false;
    }

    final solution = await _buildSolutionLineFromFirstMove(
      firstMove: candidate.firstMove,
      fenAfterFirstMove: candidate.nextFen,
      mateIn: candidate.mateIn,
    );
    if (solution == null) {
      return false;
    }

    _seenPositions.add(key);
    final puzzleNumber = _puzzles.length + 1;
    final title = 'Generated ${candidate.mateIn}-move puzzle #$puzzleNumber';
    final toMove = _sideFromFen(fen);

    final puzzle = <String, dynamic>{
      'id': 'sp_${puzzleNumber.toString().padLeft(2, '0')}',
      'difficulty': candidate.mateIn,
      'mateIn': candidate.mateIn,
      'title': title,
      'fen': fen,
      'solution': solution,
      'toMove': toMove,
      'source': 'Self-play Game $gameIndex, Ply $ply',
      'generator': {
        'type': 'self_play',
        'mode': options.mode,
        'targetMate': options.targetMate,
        'gameIndex': gameIndex,
        'ply': ply,
        'seed': options.seed,
        'playDepth': options.playDepth,
        'probeDepth': options.probeDepth,
        'solveDepth': options.solveDepth,
      },
    };

    _puzzles.add(puzzle);
    if (options.checkpoint) {
      _writeJson(options.outputPath, _buildDocument());
    }
    stdout.writeln(
      'Puzzle ${_puzzles.length}/${options.targetCount}: '
      '${puzzle['id']} mateIn=${candidate.mateIn} source=${puzzle['source']}',
    );
    return true;
  }

  Future<_MateCandidate?> _findShortestMateCandidate(String fen) async {
    final legalMoves = await _engine.listLegalMoves(fen);
    if (legalMoves.isEmpty) {
      return null;
    }

    final candidatesByMate = <int, List<_MateCandidate>>{
      1: <_MateCandidate>[],
      2: <_MateCandidate>[],
      3: <_MateCandidate>[],
    };

    for (final move in legalMoves) {
      final nextFen = await _engine.applyMoveAndGetFen(fen, move);
      if (nextFen == null) {
        continue;
      }

      final eval = await _engine.analyzePosition(nextFen, options.probeDepth);
      if (eval?.type != 'mate' || eval?.value == null) {
        continue;
      }

      final mateIn = _mateInFromChildScore(eval!.value!);
      if (mateIn == null) {
        continue;
      }

      final confirmed =
          await _engine.analyzePosition(nextFen, options.solveDepth);
      if (confirmed?.type != 'mate' || confirmed?.value == null) {
        continue;
      }

      final confirmedMate = _mateInFromChildScore(confirmed!.value!);
      if (confirmedMate != mateIn) {
        continue;
      }

      candidatesByMate[mateIn]!.add(
        _MateCandidate(
          mateIn: mateIn,
          firstMove: move,
          nextFen: nextFen,
        ),
      );
    }

    final mateOrder = options.allowedMates.toList()..sort();
    for (final mateIn in mateOrder) {
      final hasShorterMate = candidatesByMate.entries.any(
        (entry) => entry.key < mateIn && entry.value.isNotEmpty,
      );
      if (hasShorterMate) {
        return null;
      }
      final candidates = candidatesByMate[mateIn]!;
      if (candidates.length == 1) {
        return candidates.first;
      }
    }

    return null;
  }

  int? _mateInFromChildScore(int value) {
    if (value == 0) {
      return 1;
    }
    if (value < 0) {
      final mateIn = (-value) + 1;
      if (mateIn >= 1 && mateIn <= 3) {
        return mateIn;
      }
    }
    return null;
  }

  int? _mateInFromRootScore(int? value) {
    if (value == null) return null;
    if (value >= 1 && value <= 3) {
      return value;
    }
    return null;
  }

  bool _canAcceptMateIn(int mateIn) {
    final current = _puzzles
        .where((puzzle) => (puzzle['mateIn'] as num?)?.toInt() == mateIn)
        .length;
    return current < _targetCountForMateIn(mateIn);
  }

  int _targetCountForMateIn(int mateIn) {
    if (!options.allowedMates.contains(mateIn)) {
      return 0;
    }
    if (!options.allowedMates.contains(2) ||
        !options.allowedMates.contains(3)) {
      return options.targetCount;
    }
    final mate3Target =
        (options.targetCount * options.targetMate3Percent / 100).round();
    if (mateIn == 3) {
      return mate3Target.clamp(0, options.targetCount);
    }
    if (mateIn == 2) {
      return options.targetCount - mate3Target.clamp(0, options.targetCount);
    }
    return options.targetCount;
  }

  int _pieceCountFromFen(String fen) {
    final boardPart = fen.split(RegExp(r'\s+')).first;
    var count = 0;
    for (final codeUnit in boardPart.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        count++;
      }
    }
    return count;
  }

  Future<List<String>?> _buildSolutionLineFromFirstMove({
    required String firstMove,
    required String fenAfterFirstMove,
    required int mateIn,
  }) async {
    final solutionLength = mateIn * 2 - 1;
    final moves = <String>[firstMove];
    var currentFen = fenAfterFirstMove;

    for (var ply = 1; ply < solutionLength; ply++) {
      final eval =
          await _engine.analyzePosition(currentFen, options.solveDepth);
      final move = eval?.bestmove;
      if (move == null || move == '(none)') {
        return null;
      }

      moves.add(move);
      final nextFen = await _engine.applyMoveAndGetFen(currentFen, move);
      if (nextFen == null) {
        return null;
      }
      currentFen = nextFen;
    }

    final finalEval =
        await _engine.analyzePosition(currentFen, options.solveDepth);
    if (finalEval?.type != 'mate' || finalEval?.value != 0) {
      return null;
    }

    return moves;
  }

  Future<String?> _chooseSelfPlayMove({
    required String fen,
    required int gameIndex,
    required int ply,
  }) async {
    if (options.mode == 'weak-strong') {
      return _chooseWeakStrongMove(
        fen: fen,
        gameIndex: gameIndex,
        ply: ply,
      );
    }

    final sideToMove = _sideFromFen(fen);
    final blueWeak = gameIndex.isEven;
    final weakSide = (blueWeak && sideToMove == 'blue') ||
        (!blueWeak && sideToMove == 'red');

    if (weakSide && ply > 6) {
      final legalMoves = await _engine.listLegalMoves(fen);
      if (legalMoves.isEmpty) {
        return null;
      }

      final filtered =
          legalMoves.where((move) => !move.endsWith('e1')).toList();
      final pool = filtered.isEmpty ? legalMoves : filtered;
      return pool[_random.nextInt(pool.length)];
    }

    List<_PvLine> moveChoices;
    try {
      moveChoices = await _engine.analyzeMultiPv(
        fen,
        options.playDepth,
        options.multiPv,
      );
    } on TimeoutException {
      return null;
    }

    final candidates = moveChoices
        .where((line) => line.firstMove != null)
        .toList(growable: false);
    if (candidates.isEmpty) return null;

    final roll = _random.nextDouble();
    int choiceIndex;
    if (ply <= 10) {
      choiceIndex = roll < 0.72
          ? 0
          : roll < 0.93
              ? 1
              : 2;
    } else {
      choiceIndex = roll < 0.82
          ? 0
          : roll < 0.96
              ? 1
              : 2;
    }

    if (choiceIndex >= candidates.length) {
      choiceIndex = candidates.length - 1;
    }
    return candidates[choiceIndex].firstMove;
  }

  Future<String?> _chooseWeakStrongMove({
    required String fen,
    required int gameIndex,
    required int ply,
  }) async {
    final sideToMove = _sideFromFen(fen);
    final blueWeak = gameIndex.isEven;
    final weakSide = (blueWeak && sideToMove == 'blue') ||
        (!blueWeak && sideToMove == 'red');
    final legalMoves = await _engine.listLegalMoves(fen);
    if (legalMoves.isEmpty) return null;

    if (weakSide && ply > 4) {
      final roll = _random.nextDouble();
      if (roll < 0.50) {
        return legalMoves[_random.nextInt(legalMoves.length)];
      }

      final depth = max(1, options.playDepth - 3);
      final weakLines = await _engine.analyzeMultiPv(
        fen,
        depth,
        max(4, options.multiPv),
      );
      final candidates = weakLines
          .where((line) => line.firstMove != null)
          .map((line) => line.firstMove!)
          .toList(growable: false);
      if (candidates.isEmpty) {
        return legalMoves[_random.nextInt(legalMoves.length)];
      }

      if (roll < 0.78 && candidates.length > 1) {
        final upper = min(4, candidates.length);
        return candidates[1 + _random.nextInt(upper - 1)];
      }
      return candidates.first;
    }

    final strongLines = await _engine.analyzeMultiPv(
      fen,
      max(options.playDepth, options.probeDepth),
      max(3, options.multiPv),
    );
    final candidates = strongLines
        .where((line) => line.firstMove != null)
        .map((line) => line.firstMove!)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return legalMoves[_random.nextInt(legalMoves.length)];
    }

    final roll = _random.nextDouble();
    if (roll < 0.84 || candidates.length == 1) return candidates.first;
    if (roll < 0.96 || candidates.length == 2) return candidates[1];
    return candidates[min(2, candidates.length - 1)];
  }

  Map<String, dynamic> _buildDocument() {
    final counts = <String, int>{
      'mate1': 0,
      'mate2': 0,
      'mate3': 0,
    };

    for (final puzzle in _puzzles) {
      final mateIn = puzzle['mateIn'];
      if (mateIn is int && mateIn >= 1 && mateIn <= 3) {
        counts['mate$mateIn'] = (counts['mate$mateIn'] ?? 0) + 1;
      }
    }

    return <String, dynamic>{
      'version': '1.1-selfplay-preview',
      'generated': DateTime.now().toIso8601String(),
      'total': _puzzles.length,
      'categories': {
        'mate1': {
          'name': '1수 외통',
          'description': '한 수 만에 외통을 잡는 묘수',
          'count': counts['mate1'],
        },
        'mate2': {
          'name': '2수 외통',
          'description': '두 수 만에 외통을 잡는 묘수',
          'count': counts['mate2'],
        },
        'mate3': {
          'name': '3수 외통',
          'description': '세 수 만에 외통을 잡는 묘수',
          'count': counts['mate3'],
        },
      },
      'generator': {
        'type': 'self_play',
        'mode': options.mode,
        'targetMate': options.targetMate,
        'checkpoint': options.checkpoint,
        'tailCandidatesOnly': options.tailCandidatesOnly,
        'seed': options.seed,
        'targetCount': options.targetCount,
        'maxGames': options.maxGames,
        'maxPly': options.maxPly,
        'playDepth': options.playDepth,
        'probeDepth': options.probeDepth,
        'solveDepth': options.solveDepth,
        'multiPv': options.multiPv,
        'allowedMates': options.allowedMates.toList()..sort(),
        'minPieces': options.minPieces,
        'targetMate3Percent': options.targetMate3Percent,
        'scanDuringGameEvery': options.scanDuringGameEvery,
        'scanRecentCount': options.scanRecentCount,
        'richStarts': options.richStarts,
      },
      'puzzles': _puzzles,
    };
  }

  String _fenKey(String fen) {
    final parts = fen.split(RegExp(r'\s+'));
    if (parts.length < 2) return fen;
    return '${parts[0]} ${parts[1]}';
  }

  String _sideFromFen(String fen) {
    final parts = fen.split(RegExp(r'\s+'));
    return parts.length > 1 && parts[1] == 'b' ? 'red' : 'blue';
  }

  Future<void> dispose() {
    return _engine.dispose();
  }
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
        .listen((_) {});

    await _sendAndWait('uci', until: (line) => line == 'uciok');
    await _sendCommand('setoption name UCI_Variant value janggi');
    await _sendCommand('setoption name Threads value 1');
    await _sendCommand('setoption name Hash value 128');
    await _ensureMultiPv(multiPv);
    await _waitReady();
    await _sendCommand('ucinewgame');
    await _waitReady();
  }

  Future<_EvalResult?> analyzePosition(String fen, int depth) async {
    _ensureInitialized();
    await _ensureMultiPv(1);
    await _setFen(fen);
    final lines = await _sendAndWait(
      'go depth $depth',
      until: (line) => line.startsWith('bestmove '),
    );
    return _EvalResult.fromUciLines(lines, depth: depth);
  }

  Future<List<_PvLine>> analyzeMultiPv(
    String fen,
    int depth,
    int multiPv,
  ) async {
    _ensureInitialized();
    await _ensureMultiPv(multiPv);
    await _setFen(fen);
    final lines = await _sendAndWait(
      'go depth $depth',
      until: (line) => line.startsWith('bestmove '),
    );
    return _PvLine.parseAll(lines.join('\n'));
  }

  Future<List<String>> listLegalMoves(String fen) async {
    _ensureInitialized();
    await _setFen(fen);
    final lines = await _sendAndWait(
      'go perft 1',
      until: (line) => line.startsWith('Nodes searched:'),
    );

    final moves = <String>[];
    for (final line in lines) {
      final match =
          RegExp(r'^([a-i](?:10|[1-9])[a-i](?:10|[1-9])[a-z]*):\s+\d+$')
              .firstMatch(line.trim());
      if (match != null) {
        moves.add(match.group(1)!);
      }
    }
    return moves;
  }

  Future<String?> applyMoveAndGetFen(String fen, String move) async {
    _ensureInitialized();
    final position = 'position fen $fen moves $move';
    await _sendCommand(position);
    await _waitReady();
    final lines = await _sendAndWait(
      'd',
      until: (line) => line.startsWith('Chased:'),
    );
    for (final line in lines) {
      if (line.startsWith('Fen: ')) {
        return line.substring('Fen: '.length).trim();
      }
    }
    return null;
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

  Future<void> _setFen(String fen) async {
    await _sendCommand('position fen $fen');
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
          'Timed out waiting for engine response: $command',
        );
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
    required this.depth,
  });

  final String type;
  final int? value;
  final String? bestmove;
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

    return _EvalResult(
      type: bestLine?.scoreType ?? 'unknown',
      value: bestLine?.scoreValue,
      bestmove: bestmoveMatch?.group(1) ?? bestLine?.firstMove,
      depth: depth,
    );
  }
}

class _PvLine {
  _PvLine({
    required this.multiPv,
    required this.scoreType,
    required this.scoreValue,
    required this.firstMove,
  });

  final int multiPv;
  final String? scoreType;
  final int? scoreValue;
  final String? firstMove;

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
      if (scoreMatch == null || pvMatch == null) {
        continue;
      }

      lines.add(
        _PvLine(
          multiPv: int.tryParse(multiPvMatch?.group(1) ?? '') ?? 1,
          scoreType: scoreMatch.group(1),
          scoreValue: int.tryParse(scoreMatch.group(2) ?? ''),
          firstMove: pvMatch.group(1),
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

void _writeJson(String path, Object data) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(data)}\n', encoding: utf8);
}

class _RecordedPosition {
  const _RecordedPosition({
    required this.fen,
    required this.ply,
  });

  final String fen;
  final int ply;
}

class _MateCandidate {
  const _MateCandidate({
    required this.mateIn,
    required this.firstMove,
    required this.nextFen,
  });

  final int mateIn;
  final String firstMove;
  final String nextFen;
}
