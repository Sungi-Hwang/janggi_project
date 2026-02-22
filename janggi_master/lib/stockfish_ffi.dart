import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// Define the C function signatures
typedef StockfishInitC = Void Function();
typedef StockfishCommandC = Pointer<Char> Function(Pointer<Char>);
typedef StockfishCleanupC = Void Function();
typedef StockfishAnalyzeC = Pointer<Char> Function(Pointer<Char>, Int32);

// Define the Dart function types
typedef StockfishInit = void Function();
typedef StockfishCommand = Pointer<Char> Function(Pointer<Char>);
typedef StockfishCleanup = void Function();
typedef StockfishAnalyze = Pointer<Char> Function(Pointer<Char>, int);

class StockfishFFI {
  static DynamicLibrary? _lib;
  static bool _initialized = false;
  static const int _defaultHashMb = 64;
  static const int _maxDefaultThreads = 4;
  static const int _minHashMb = 16;
  static const int _maxHashMb = 512;
  static const int _maxThreads = 64;

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

  // Public Dart methods
  static void init({int? threads, int? hashMb}) {
    if (!_initialized) {
      try {
        final resolvedThreads = _sanitizeThreads(threads ?? _defaultThreads());
        final resolvedHashMb = _sanitizeHashMb(hashMb ?? _defaultHashMb);

        print('Initializing Stockfish engine...');
        _stockfishInit();

        // Initialize UCI protocol
        print('Sending UCI initialization commands...');
        final result1 = _commandUnchecked('uci');
        print('UCI response: $result1');

        // Set variant to janggi
        print('Setting variant to janggi...');
        _commandUnchecked('setoption name UCI_Variant value janggi');

        // Configure engine resources for mobile stability/performance.
        print('Setting Threads to $resolvedThreads...');
        _commandUnchecked('setoption name Threads value $resolvedThreads');

        print('Setting Hash to ${resolvedHashMb}MB...');
        _commandUnchecked('setoption name Hash value $resolvedHashMb');

        // Set MultiPV for variety in moves (analyze top 3 moves)
        print('Setting MultiPV to 3 for move variety...');
        _commandUnchecked('setoption name MultiPV value 3');

        // Send isready to confirm
        final result3 = _commandUnchecked('isready');
        print('isready response: $result3');

        _initialized = true;
        print('Stockfish engine initialized successfully with Janggi variant');
      } catch (e) {
        print('ERROR initializing Stockfish: $e');
        rethrow;
      }
    } else {
      print('Stockfish already initialized');
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
      print('Stockfish engine cleaned up');
    }
  }

  // Helper method to check if engine is ready
  static bool isReady() {
    if (!_initialized) return false;
    final response = command('isready');
    return response.contains('readyok');
  }

  // Helper method to start a new game
  static void newGame() {
    command('ucinewgame');
  }

  // Helper method to set position
  static void setPosition({String? fen, List<String>? moves}) {
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
  static String? getBestMove({int depth = 10, int? movetime}) {
    String cmd = 'go depth $depth';
    if (movetime != null && movetime > 0) {
      cmd += ' movetime $movetime';
    }

    debugPrint('StockfishFFI.getBestMove: Sending command: $cmd');
    final response = command(cmd);
    debugPrint('StockfishFFI.getBestMove: Full response:\n$response');

    // Parse all PV lines to get top moves (for variety)
    final lines = response.split('\n');
    final topMoves = <String>[];

    for (final line in lines) {
      // Look for "info ... pv <move>" lines from MultiPV
      // IMPORTANT: Use ' pv ' (with spaces) to avoid matching 'multipv'
      if (line.contains('info') && line.contains(' pv ')) {
        final pvIndex = line.indexOf(' pv ');
        if (pvIndex != -1) {
          final moveStart = pvIndex + 4; // +4 because ' pv ' is 4 characters
          final moveEnd = line.indexOf(' ', moveStart);
          final move = moveEnd == -1
              ? line.substring(moveStart).trim()
              : line.substring(moveStart, moveEnd).trim();
          debugPrint('StockfishFFI.getBestMove: Parsing PV line: "$line"');
          debugPrint('StockfishFFI.getBestMove: Extracted move: "$move"');
          if (move.isNotEmpty && !topMoves.contains(move)) {
            topMoves.add(move);
          }
        }
      }
    }

    // If we have multiple top moves, randomly pick one (weighted towards better moves)
    String? selectedMove;
    if (topMoves.isNotEmpty) {
      // 60% chance to pick best move, 30% for 2nd, 10% for 3rd
      final random = DateTime.now().microsecond % 100;
      if (random < 60 && topMoves.isNotEmpty) {
        selectedMove = topMoves[0]; // Best move
      } else if (random < 90 && topMoves.length > 1) {
        selectedMove = topMoves[1]; // 2nd best move
      } else if (topMoves.length > 2) {
        selectedMove = topMoves[2]; // 3rd best move
      } else {
        selectedMove = topMoves[0]; // Fallback to best
      }
      debugPrint(
          'StockfishFFI.getBestMove: Top moves: $topMoves, Selected: $selectedMove');
    }

    // Fallback: parse the bestmove from response
    if (selectedMove == null) {
      for (final line in lines) {
        if (line.startsWith('bestmove')) {
          final parts = line.split(' ');
          if (parts.length >= 2) {
            selectedMove = parts[1];
            debugPrint(
                'StockfishFFI.getBestMove: Using bestmove from response: $selectedMove');
            break;
          }
        }
      }
    }

    if (selectedMove == null) {
      debugPrint('StockfishFFI.getBestMove: No bestmove found in response!');
    }
    return selectedMove;
  }

  /// Analyze a position and return score + bestmove directly from engine.
  /// Returns: {'type': 'cp'/'mate', 'value': int, 'bestmove': String?}
  /// This bypasses stdout parsing and gets score directly from Thread->rootMoves.
  static Map<String, dynamic>? analyze(String fen, {int depth = 10}) {
    if (!_initialized) {
      throw StateError('Stockfish not initialized. Call init() first.');
    }

    final fenP = fen.toNativeUtf8();
    final resultP = _stockfishAnalyze(fenP.cast<Char>(), depth);
    final result = resultP.cast<Utf8>().toDartString();
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

  /// Run best-move search in a background isolate to avoid blocking the UI.
  static Future<String?> getBestMoveIsolated({
    required String fen,
    int depth = 10,
    int? movetime,
    int? threads,
    int? hashMb,
  }) {
    return compute<Map<String, dynamic>, String?>(
      _getBestMoveInIsolate,
      <String, dynamic>{
        'fen': fen,
        'depth': depth,
        'movetime': movetime,
        'threads': threads,
        'hashMb': hashMb,
      },
    );
  }

  /// Run direct analyze() in a background isolate to avoid blocking the UI.
  static Future<Map<String, dynamic>?> analyzeIsolated(
    String fen, {
    int depth = 10,
    int? threads,
    int? hashMb,
  }) {
    return compute<Map<String, dynamic>, Map<String, dynamic>?>(
      _analyzeInIsolate,
      <String, dynamic>{
        'fen': fen,
        'depth': depth,
        'threads': threads,
        'hashMb': hashMb,
      },
    );
  }

  /// Warm up the native engine in a background isolate.
  static Future<void> warmupIsolated({int? threads, int? hashMb}) async {
    await compute<Map<String, dynamic>, bool>(
      _warmupInIsolate,
      <String, dynamic>{
        'threads': threads,
        'hashMb': hashMb,
      },
    );
  }
}

String? _getBestMoveInIsolate(Map<String, dynamic> request) {
  final fen = request['fen'] as String;
  final depth = request['depth'] as int? ?? 10;
  final movetime = request['movetime'] as int?;
  final threads = request['threads'] as int?;
  final hashMb = request['hashMb'] as int?;

  try {
    StockfishFFI.init(threads: threads, hashMb: hashMb);
    StockfishFFI.setPosition(fen: fen);
    return StockfishFFI.getBestMove(depth: depth, movetime: movetime);
  } finally {
    StockfishFFI.cleanup();
  }
}

Map<String, dynamic>? _analyzeInIsolate(Map<String, dynamic> request) {
  final fen = request['fen'] as String;
  final depth = request['depth'] as int? ?? 10;
  final threads = request['threads'] as int?;
  final hashMb = request['hashMb'] as int?;

  try {
    StockfishFFI.init(threads: threads, hashMb: hashMb);
    return StockfishFFI.analyze(fen, depth: depth);
  } finally {
    StockfishFFI.cleanup();
  }
}

bool _warmupInIsolate(Map<String, dynamic> request) {
  final threads = request['threads'] as int?;
  final hashMb = request['hashMb'] as int?;

  try {
    StockfishFFI.init(threads: threads, hashMb: hashMb);
    return true;
  } finally {
    StockfishFFI.cleanup();
  }
}
