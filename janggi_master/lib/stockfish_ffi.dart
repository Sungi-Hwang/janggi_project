import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Define the C function signatures
typedef StockfishInitC = Void Function();
typedef StockfishCommandC = Pointer<Char> Function(Pointer<Char>);
typedef StockfishCleanupC = Void Function();

// Define the Dart function types
typedef StockfishInit = void Function();
typedef StockfishCommand = Pointer<Char> Function(Pointer<Char>);
typedef StockfishCleanup = void Function();

class StockfishFFI {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

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
  static final StockfishInit _stockfishInit =
      _library.lookup<NativeFunction<StockfishInitC>>('stockfish_init').asFunction();

  static final StockfishCommand _stockfishCommand =
      _library.lookup<NativeFunction<StockfishCommandC>>('stockfish_command').asFunction();

  static final StockfishCleanup _stockfishCleanup =
      _library.lookup<NativeFunction<StockfishCleanupC>>('stockfish_cleanup').asFunction();

  // Public Dart methods
  static void init() {
    if (!_initialized) {
      try {
        print('Initializing Stockfish engine...');
        _stockfishInit();

        // Initialize UCI protocol
        print('Sending UCI initialization commands...');
        final cmdP1 = 'uci'.toNativeUtf8();
        final resultP1 = _stockfishCommand(cmdP1.cast<Char>());
        final result1 = resultP1.cast<Utf8>().toDartString();
        malloc.free(cmdP1);
        print('UCI response: $result1');

        // Set variant to janggi
        print('Setting variant to janggi...');
        final cmdP2 = 'setoption name UCI_Variant value janggi'.toNativeUtf8();
        _stockfishCommand(cmdP2.cast<Char>());
        malloc.free(cmdP2);

        // Send isready to confirm
        final cmdP3 = 'isready'.toNativeUtf8();
        final resultP3 = _stockfishCommand(cmdP3.cast<Char>());
        final result3 = resultP3.cast<Utf8>().toDartString();
        malloc.free(cmdP3);
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

    final cmdP = cmd.toNativeUtf8();
    final resultP = _stockfishCommand(cmdP.cast<Char>());
    final result = resultP.cast<Utf8>().toDartString();
    malloc.free(cmdP);
    return result.trim();
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
      cmd += 'fen $fen';
    } else {
      // Janggi FEN - reads from rank 10 (top, Red) to rank 1 (bottom, Blue)
      // FEN uses: uppercase=Red(한), lowercase=Blue(초)
      // Flutter rank 9 (Red back): R E H A _ A H E R → REHA1AHER
      // Flutter rank 8 (Red general): _ _ _ _ K _ _ _ _ → 4K4
      // Flutter rank 7 (Red cannons): _ C _ _ _ _ _ C _ → 1C5C1
      // Flutter rank 6 (Red soldiers): P _ P _ P _ P _ P → P1P1P1P1P
      // Flutter rank 5-4 (empty): 9/9
      // Flutter rank 3 (Blue soldiers): p _ p _ p _ p _ p → p1p1p1p1p
      // Flutter rank 2 (Blue cannons): _ c _ _ _ _ _ c _ → 1c5c1
      // Flutter rank 1 (Blue general): _ _ _ _ k _ _ _ _ → 4k4
      // Flutter rank 0 (Blue back): r e h a _ a h e r → reha1aher
      // Blue (lowercase/BLACK) moves first, so use 'b' for BLACK to move
      cmd += 'fen REHA1AHER/4K4/1C5C1/P1P1P1P1P/9/9/p1p1p1p1p/1c5c1/4k4/reha1aher b - - 0 1';
    }

    if (moves != null && moves.isNotEmpty) {
      cmd += ' moves ${moves.join(' ')}';
    }

    command(cmd);
  }

  // Helper method to get best move
  static String? getBestMove({int depth = 10, int? movetime}) {
    String cmd = 'go';
    if (movetime != null) {
      cmd += ' movetime $movetime';
    } else {
      cmd += ' depth $depth';
    }

    final response = command(cmd);

    // Parse the bestmove from response
    final lines = response.split('\n');
    for (final line in lines) {
      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        if (parts.length >= 2) {
          return parts[1];
        }
      }
    }
    return null;
  }
}
