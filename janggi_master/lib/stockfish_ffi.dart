import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'models/rule_mode.dart';

// Define the C function signatures
typedef StockfishInitC = Void Function();
typedef StockfishCommandC = Pointer<Char> Function(Pointer<Char>);
typedef StockfishCleanupC = Void Function();
typedef StockfishAnalyzeC = Pointer<Char> Function(
    Pointer<Char>, Pointer<Char>, Int32);
typedef StockfishPositionStateC = Pointer<Char> Function(
    Pointer<Char>, Pointer<Char>, Pointer<Char>);

// Define the Dart function types
typedef StockfishInit = void Function();
typedef StockfishCommand = Pointer<Char> Function(Pointer<Char>);
typedef StockfishCleanup = void Function();
typedef StockfishAnalyze = Pointer<Char> Function(
    Pointer<Char>, Pointer<Char>, int);
typedef StockfishPositionState = Pointer<Char> Function(
    Pointer<Char>, Pointer<Char>, Pointer<Char>);

class EnginePositionState {
  final String sideToMove;
  final List<String> legalMoves;
  final bool inCheck;
  final bool bikjang;
  final bool canPass;
  final bool gameOver;
  final String winner;
  final String reason;

  const EnginePositionState({
    required this.sideToMove,
    required this.legalMoves,
    required this.inCheck,
    required this.bikjang,
    required this.canPass,
    required this.gameOver,
    required this.winner,
    required this.reason,
  });

  factory EnginePositionState.fromJson(Map<String, dynamic> json) {
    return EnginePositionState(
      sideToMove: json['sideToMove'] as String? ?? 'blue',
      legalMoves: (json['legalMoves'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      inCheck: json['inCheck'] as bool? ?? false,
      bikjang: json['bikjang'] as bool? ?? false,
      canPass: json['canPass'] as bool? ?? false,
      gameOver: json['gameOver'] as bool? ?? false,
      winner: json['winner'] as String? ?? 'none',
      reason: json['reason'] as String? ?? 'ongoing',
    );
  }
}

class StockfishFFI {
  static DynamicLibrary? _lib;
  static bool _initialized = false;
  static const int _defaultHashMb = 64;
  static const int _maxDefaultThreads = 4;
  static final RegExp _uciMovePattern =
      RegExp(r'^([a-i])(10|[1-9])([a-i])(10|[1-9])$', caseSensitive: false);
  static const int _minHashMb = 16;
  static const int _maxHashMb = 512;
  static const int _maxThreads = 64;
  static String _activeVariant = RuleMode.officialKja.engineVariantName;

  static void _log(String message) {
    debugPrint(message);
  }

  // Lazy load the library
  static DynamicLibrary get _library {
    if (_lib == null) {
      String libPath;
      if (Platform.isWindows) {
        libPath = 'stockfish.dll';
      } else if (Platform.isAndroid) {
        libPath = 'libstockfish.so';
      } else if (Platform.isLinux) {
        libPath = 'libstockfish.so';
      } else {
        throw UnsupportedError('Platform not supported');
      }
      _lib = DynamicLibrary.open(libPath);
    }
    return _lib!;
  }

  // Look up the C functions
  static final StockfishInit _stockfishInit = _library
      .lookup<NativeFunction<StockfishInitC>>('stockfish_init')
      .asFunction();

  static final StockfishCommand _stockfishCommand = _library
      .lookup<NativeFunction<StockfishCommandC>>('stockfish_command')
      .asFunction();

  static final StockfishCleanup _stockfishCleanup = _library
      .lookup<NativeFunction<StockfishCleanupC>>('stockfish_cleanup')
      .asFunction();

  static final StockfishAnalyze _stockfishAnalyze = _library
      .lookup<NativeFunction<StockfishAnalyzeC>>('stockfish_analyze')
      .asFunction();

  static final StockfishPositionState _stockfishPositionState = _library
      .lookup<NativeFunction<StockfishPositionStateC>>(
          'stockfish_position_state')
      .asFunction();

  static int _defaultThreads() {
    final cpuCount = Platform.numberOfProcessors;
    if (cpuCount <= 0) return 1;
    if (cpuCount > _maxDefaultThreads) return _maxDefaultThreads;
    return cpuCount;
  }

  static int _sanitizeThreads(int value) {
    return value.clamp(1, _maxThreads).toInt();
  }

  static int _sanitizeHashMb(int value) {
    return value.clamp(_minHashMb, _maxHashMb).toInt();
  }

  static String _commandUnchecked(String cmd) {
    final cmdP = cmd.toNativeUtf8();
    final resultP = _stockfishCommand(cmdP.cast<Char>());
    final result = resultP.cast<Utf8>().toDartString();
    malloc.free(cmdP);
    return result.trim();
  }

  static String _normalizeVariant(String? variant) {
    final normalized = variant?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return RuleMode.officialKja.engineVariantName;
    }
    return normalized;
  }

  static void _ensureVariant(String variant) {
    if (!_initialized) {
      throw StateError('Stockfish not initialized. Call init() first.');
    }

    final resolvedVariant = _normalizeVariant(variant);
    if (_activeVariant == resolvedVariant) {
      return;
    }

    _log('Switching variant to $resolvedVariant...');
    _commandUnchecked('setoption name UCI_Variant value $resolvedVariant');
    _commandUnchecked('ucinewgame');
    final ready = _commandUnchecked('isready');
    _log('isready response after variant switch: $ready');
    _activeVariant = resolvedVariant;
  }

  // Public Dart methods
  static void init({
    int? threads,
    int? hashMb,
    String variant = 'janggi',
  }) {
    final resolvedVariant = _normalizeVariant(variant);
    if (!_initialized) {
      try {
        final resolvedThreads = _sanitizeThreads(threads ?? _defaultThreads());
        final resolvedHashMb = _sanitizeHashMb(hashMb ?? _defaultHashMb);

        _log('Initializing Stockfish engine...');
        _stockfishInit();

        // Initialize UCI protocol
        _log('Sending UCI initialization commands...');
        final result1 = _commandUnchecked('uci');
        _log('UCI response: $result1');

        // Set variant before any position-dependent commands.
        _log('Setting variant to $resolvedVariant...');
        _commandUnchecked('setoption name UCI_Variant value $resolvedVariant');
        _activeVariant = resolvedVariant;

        // Configure engine resources for mobile stability/performance.
        _log('Setting Threads to $resolvedThreads...');
        _commandUnchecked('setoption name Threads value $resolvedThreads');

        _log('Setting Hash to ${resolvedHashMb}MB...');
        _commandUnchecked('setoption name Hash value $resolvedHashMb');

        // Keep MultiPV deterministic for game play.
        _log('Setting MultiPV to 1 for stable best-move parsing...');
        _commandUnchecked('setoption name MultiPV value 1');

        // Send isready to confirm
        final result3 = _commandUnchecked('isready');
        _log('isready response: $result3');

        _initialized = true;
        _log(
          'Stockfish engine initialized successfully with $resolvedVariant variant',
        );
      } catch (e) {
        _log('ERROR initializing Stockfish: $e');
        rethrow;
      }
    } else {
      _ensureVariant(resolvedVariant);
      _log('Stockfish already initialized');
    }
  }

  static String command(String cmd) {
    if (!_initialized) {
      throw StateError('Stockfish not initialized. Call init() first.');
    }

    return _commandUnchecked(cmd);
  }

  static void cleanup() {
    if (_initialized) {
      _stockfishCleanup();
      _initialized = false;
      _activeVariant = RuleMode.officialKja.engineVariantName;
      _log('Stockfish engine cleaned up');
    }
  }

  // Helper method to check if engine is ready
  static bool isReady() {
    if (!_initialized) return false;
    final response = command('isready');
    return response.contains('readyok');
  }

  // Helper method to start a new game
  static void newGame({String variant = 'janggi'}) {
    _ensureVariant(variant);
    command('ucinewgame');
  }

  // Helper method to set position
  static void setPosition({
    String? fen,
    List<String>? moves,
    String variant = 'janggi',
  }) {
    _ensureVariant(variant);
    String cmd = 'position ';
    if (fen != null) {
      debugPrint('StockfishFFI.setPosition: Using FEN: $fen');
      cmd += 'fen $fen';
    } else {
      debugPrint('StockfishFFI.setPosition: Using default startpos FEN');
      // Janggi FEN - standard mapping (rank + 1)
      // FEN reads from rank 10 (top) to rank 1 (bottom)
      // Direct mapping: Stockfish rank = Flutter rank + 1
      //
      // IMPORTANT: Fairy-Stockfish Janggi has uppercase (White) at bottom!
      // Piece letters: R=rook(차), H=horse(마), B=elephant(상... using e?), A=alfil(사), K=king(장), C=cannon(포), P=pawn(병)
      // Fairy-Stockfish usually uses:
      // h = horse (mao/ma 1+1)
      // e = elephant (same 2+2 ? or pseudo-janggi elephant)
      // Let's use 'h' and 'e' as planned.
      //
      // FEN Line 1 (rank 10) → Flutter rank 9 (Red back): rheakaehr (lowercase)
      // FEN Line 2 (rank 9) → Flutter rank 8 (Red general): 4k4 (lowercase)
      // FEN Line 3 (rank 8) → Flutter rank 7 (Red cannons): 1c5c1 (lowercase)
      // FEN Line 4 (rank 7) → Flutter rank 6 (Red soldiers): p1p1p1p1p (lowercase)
      // FEN Line 5-6 (rank 6-5) → Flutter rank 5-4 (empty): 9/9
      // FEN Line 7 (rank 4) → Flutter rank 3 (Blue soldiers): P1P1P1P1P (uppercase)
      // FEN Line 8 (rank 3) → Flutter rank 2 (Blue cannons): 1C5C1 (uppercase)
      // FEN Line 9 (rank 2) → Flutter rank 1 (Blue general): 4K4 (uppercase)
      // FEN Line 10 (rank 1) → Flutter rank 0 (Blue back): RHEAKAEHR (uppercase)
      //
      // Blue (uppercase/WHITE) moves first
      cmd +=
          'fen rheakaehr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RHEAKAEHR w - - 0 1';
    }

    if (moves != null && moves.isNotEmpty) {
      cmd += ' moves ${moves.join(' ')}';
    }

    command(cmd);
  }

  // Helper method to get best move
  static String? getBestMove({
    int depth = 10,
    int? movetime,
    bool allowPass = false,
  }) {
    String cmd = 'go depth $depth';
    if (movetime != null && movetime > 0) {
      cmd += ' movetime $movetime';
    }

    debugPrint('StockfishFFI.getBestMove: Sending command: $cmd');
    final response = command(cmd);
    debugPrint('StockfishFFI.getBestMove: Full response:\n$response');
    final selectedMove = _selectBestMoveFromEngineResponse(
      response,
      allowPass: allowPass,
    );

    if (selectedMove == null) {
      debugPrint('StockfishFFI.getBestMove: No bestmove found in response!');
    } else {
      debugPrint(
          'StockfishFFI.getBestMove: Using validated move $selectedMove');
    }
    return selectedMove;
  }

  static bool isUsableUciMove(String move) {
    final normalized = move.trim().toLowerCase();
    if (normalized.isEmpty || normalized == '0000' || normalized == '(none)') {
      return false;
    }

    final match = _uciMovePattern.firstMatch(normalized);
    if (match == null) {
      return false;
    }

    final from = '${match.group(1)}${match.group(2)}';
    final to = '${match.group(3)}${match.group(4)}';
    return from != to;
  }

  static bool isPassUciMove(String move) {
    final normalized = move.trim().toLowerCase();
    final match = _uciMovePattern.firstMatch(normalized);
    if (match == null) {
      return false;
    }

    final from = '${match.group(1)}${match.group(2)}';
    final to = '${match.group(3)}${match.group(4)}';
    return from == to;
  }

  static bool _isRecognizedUciMove(String move, {required bool allowPass}) {
    return isUsableUciMove(move) || (allowPass && isPassUciMove(move));
  }

  static String? _extractPvMove(String line, {required bool allowPass}) {
    if (!line.contains('info') || !line.contains(' pv ')) {
      return null;
    }

    final pvIndex = line.indexOf(' pv ');
    if (pvIndex == -1) {
      return null;
    }

    final pvMoves = line.substring(pvIndex + 4).trim().split(RegExp(r'\s+'));
    if (pvMoves.isEmpty) {
      return null;
    }

    final firstMove = pvMoves.first.trim();
    if (!_isRecognizedUciMove(firstMove, allowPass: allowPass)) {
      debugPrint(
          'StockfishFFI.selectBestMoveFromEngineResponse: Ignoring invalid PV move "$firstMove"');
      return null;
    }

    return firstMove;
  }

  static String? _selectBestMoveFromEngineResponse(
    String response, {
    required bool allowPass,
  }) {
    final lines = response.split(RegExp(r'\r?\n'));

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (!line.startsWith('bestmove')) {
        continue;
      }

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) {
        continue;
      }

      final move = parts[1].trim();
      if (_isRecognizedUciMove(move, allowPass: allowPass)) {
        return move;
      }

      debugPrint(
          'StockfishFFI.selectBestMoveFromEngineResponse: Ignoring invalid bestmove "$move"');
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      final pvMove = _extractPvMove(line, allowPass: allowPass);
      if (pvMove != null) {
        return pvMove;
      }
    }

    return null;
  }

  @visibleForTesting
  static String? selectBestMoveFromEngineResponse(String response) {
    return _selectBestMoveFromEngineResponse(response, allowPass: false);
  }

  /// Analyze a position and return score + bestmove directly from engine.
  /// Returns: {'type': 'cp'/'mate', 'value': int, 'bestmove': String?}
  /// This bypasses stdout parsing and gets score directly from Thread->rootMoves.
  static Map<String, dynamic>? analyze(
    String fen, {
    int depth = 10,
    String variant = 'janggi',
  }) {
    if (!_initialized) {
      throw StateError('Stockfish not initialized. Call init() first.');
    }

    final variantP = _normalizeVariant(variant).toNativeUtf8();
    final fenP = fen.toNativeUtf8();
    final resultP =
        _stockfishAnalyze(variantP.cast<Char>(), fenP.cast<Char>(), depth);
    final result = resultP.cast<Utf8>().toDartString();
    malloc.free(variantP);
    malloc.free(fenP);

    // debugPrint('StockfishFFI.analyze: Result: "$result"');

    if (result.startsWith('error:')) {
      debugPrint('StockfishFFI.analyze: Error: $result');
      return null;
    }

    // Parse: "cp 300 bestmove e9f9" or "mate 5 bestmove a1a2"
    final parts = result.split(' ');
    if (parts.length >= 2) {
      final type = parts[0]; // 'cp' or 'mate'
      final value = int.tryParse(parts[1]);

      if (value != null && (type == 'cp' || type == 'mate')) {
        String? bestmove;
        // Look for 'bestmove' in parts
        for (int i = 2; i < parts.length - 1; i++) {
          if (parts[i] == 'bestmove') {
            bestmove = parts[i + 1];
            break;
          }
        }

        return {
          'type': type,
          'value': value,
          'bestmove': bestmove,
        };
      }
    }

    debugPrint('StockfishFFI.analyze: Failed to parse result: $result');
    return null;
  }

  static EnginePositionState? getPositionState({
    required String rootFen,
    List<String>? moves,
    String variant = 'janggi',
  }) {
    if (!_initialized) {
      throw StateError('Stockfish not initialized. Call init() first.');
    }

    final variantP = _normalizeVariant(variant).toNativeUtf8();
    final fenP = rootFen.toNativeUtf8();
    final movesP =
        (moves == null || moves.isEmpty ? '' : moves.join(' ')).toNativeUtf8();

    try {
      final resultP = _stockfishPositionState(
        variantP.cast<Char>(),
        fenP.cast<Char>(),
        movesP.cast<Char>(),
      );
      final result = resultP.cast<Utf8>().toDartString();
      if (result.startsWith('error:')) {
        debugPrint('StockfishFFI.getPositionState: $result');
        return null;
      }

      final decoded = jsonDecode(result);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('StockfishFFI.getPositionState: Unexpected payload $result');
        return null;
      }

      return EnginePositionState.fromJson(decoded);
    } catch (e) {
      debugPrint('StockfishFFI.getPositionState: Error: $e');
      return null;
    } finally {
      malloc.free(variantP);
      malloc.free(fenP);
      malloc.free(movesP);
    }
  }

  /// Run best-move search in a background isolate to avoid blocking the UI.
  static Future<String?> getBestMoveIsolated({
    required String fen,
    String variant = 'janggi',
    int depth = 10,
    int? movetime,
    bool allowPass = true,
    int? threads,
    int? hashMb,
  }) {
    return compute<Map<String, dynamic>, String?>(
      _getBestMoveInIsolate,
      _buildIsolateRequest(
        variant: variant,
        threads: threads,
        hashMb: hashMb,
        extra: <String, dynamic>{
          'fen': fen,
          'depth': depth,
          'movetime': movetime,
          'allowPass': allowPass,
        },
      ),
    );
  }

  static Future<String?> getBestMoveFromHistoryIsolated({
    required String rootFen,
    required List<String> moves,
    String variant = 'janggi',
    int depth = 10,
    int? movetime,
    int? threads,
    int? hashMb,
  }) {
    return compute<Map<String, dynamic>, String?>(
      _getBestMoveFromHistoryInIsolate,
      _buildIsolateRequest(
        variant: variant,
        threads: threads,
        hashMb: hashMb,
        extra: <String, dynamic>{
          'rootFen': rootFen,
          'moves': moves,
          'depth': depth,
          'movetime': movetime,
        },
      ),
    );
  }

  /// Run direct analyze() in a background isolate to avoid blocking the UI.
  static Future<Map<String, dynamic>?> analyzeIsolated(
    String fen, {
    String variant = 'janggi',
    int depth = 10,
    int? threads,
    int? hashMb,
  }) {
    return compute<Map<String, dynamic>, Map<String, dynamic>?>(
      _analyzeInIsolate,
      _buildIsolateRequest(
        variant: variant,
        threads: threads,
        hashMb: hashMb,
        extra: <String, dynamic>{
          'fen': fen,
          'depth': depth,
        },
      ),
    );
  }

  /// Warm up the native engine in a background isolate.
  static Future<void> warmupIsolated({
    int? threads,
    int? hashMb,
    String variant = 'janggi',
  }) async {
    await compute<Map<String, dynamic>, bool>(
      _warmupInIsolate,
      _buildIsolateRequest(
        variant: variant,
        threads: threads,
        hashMb: hashMb,
      ),
    );
  }

  static Map<String, dynamic> _buildIsolateRequest({
    required String variant,
    int? threads,
    int? hashMb,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) {
    return <String, dynamic>{
      'variant': variant,
      'threads': threads,
      'hashMb': hashMb,
      ...extra,
    };
  }
}

String? _getBestMoveInIsolate(Map<String, dynamic> request) {
  final fen = request['fen'] as String;
  final depth = request['depth'] as int? ?? 10;
  final movetime = request['movetime'] as int?;
  final allowPass = request['allowPass'] as bool? ?? true;

  return _runWithInitializedEngine<String?>(request, () {
    final variant = _requestVariant(request);
    StockfishFFI.setPosition(fen: fen, variant: variant);
    return StockfishFFI.getBestMove(
      depth: depth,
      movetime: movetime,
      allowPass: allowPass,
    );
  });
}

String? _getBestMoveFromHistoryInIsolate(Map<String, dynamic> request) {
  final rootFen = request['rootFen'] as String;
  final moves = (request['moves'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<String>()
      .toList(growable: false);
  final depth = request['depth'] as int? ?? 10;
  final movetime = request['movetime'] as int?;

  return _runWithInitializedEngine<String?>(request, () {
    final variant = _requestVariant(request);
    StockfishFFI.setPosition(fen: rootFen, moves: moves, variant: variant);
    return StockfishFFI.getBestMove(
      depth: depth,
      movetime: movetime,
      allowPass: true,
    );
  });
}

Map<String, dynamic>? _analyzeInIsolate(Map<String, dynamic> request) {
  final fen = request['fen'] as String;
  final depth = request['depth'] as int? ?? 10;

  return _runWithInitializedEngine<Map<String, dynamic>?>(request, () {
    final variant = _requestVariant(request);
    return StockfishFFI.analyze(fen, depth: depth, variant: variant);
  });
}

bool _warmupInIsolate(Map<String, dynamic> request) {
  return _runWithInitializedEngine<bool>(request, () {
    return true;
  });
}

String _requestVariant(Map<String, dynamic> request) {
  return request['variant'] as String? ?? 'janggi';
}

T _runWithInitializedEngine<T>(
  Map<String, dynamic> request,
  T Function() body,
) {
  final threads = request['threads'] as int?;
  final hashMb = request['hashMb'] as int?;
  final variant = _requestVariant(request);

  try {
    StockfishFFI.init(threads: threads, hashMb: hashMb, variant: variant);
    return body();
  } finally {
    StockfishFFI.cleanup();
  }
}
