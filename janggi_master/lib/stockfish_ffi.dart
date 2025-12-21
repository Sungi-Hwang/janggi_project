import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

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
      debugPrint('StockfishFFI.setPosition: Using FEN: $fen');
      cmd += 'fen $fen';
    } else {
      debugPrint('StockfishFFI.setPosition: Using default startpos FEN');
      // Janggi FEN - standard mapping (rank + 1)
      // FEN reads from rank 10 (top) to rank 1 (bottom)
      // Direct mapping: Stockfish rank = Flutter rank + 1
      //
      // IMPORTANT: Fairy-Stockfish Janggi has uppercase (White) at bottom!
      // Piece letters: R=rook(차), N=knight(마), B=bishop(상), A=alfil(사), K=king(장), C=cannon(포), P=pawn(병)
      // FEN Line 1 (rank 10) → Flutter rank 9 (Red back): rnba1abnr (lowercase)
      // FEN Line 2 (rank 9) → Flutter rank 8 (Red general): 4k4 (lowercase)
      // FEN Line 3 (rank 8) → Flutter rank 7 (Red cannons): 1c5c1 (lowercase)
      // FEN Line 4 (rank 7) → Flutter rank 6 (Red soldiers): p1p1p1p1p (lowercase)
      // FEN Line 5-6 (rank 6-5) → Flutter rank 5-4 (empty): 9/9
      // FEN Line 7 (rank 4) → Flutter rank 3 (Blue soldiers): P1P1P1P1P (uppercase)
      // FEN Line 8 (rank 3) → Flutter rank 2 (Blue cannons): 1C5C1 (uppercase)
      // FEN Line 9 (rank 2) → Flutter rank 1 (Blue general): 4K4 (uppercase)
      // FEN Line 10 (rank 1) → Flutter rank 0 (Blue back): RNBA1ABNR (uppercase)
      //
      // Blue (uppercase/WHITE) moves first
      cmd += 'fen rnba1abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ABNR w - - 0 1';
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

    debugPrint('StockfishFFI.getBestMove: Sending command: $cmd');
    final response = command(cmd);
    debugPrint('StockfishFFI.getBestMove: Full response:\n$response');

    // Parse the bestmove from response
    final lines = response.split('\n');
    for (final line in lines) {
      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        if (parts.length >= 2) {
          debugPrint('StockfishFFI.getBestMove: Parsed bestmove: ${parts[1]}');
          return parts[1];
        }
      }
    }
    debugPrint('StockfishFFI.getBestMove: No bestmove found in response!');
    return null;
  }
}
