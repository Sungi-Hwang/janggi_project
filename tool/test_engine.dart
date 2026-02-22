import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// FFI signatures
typedef StockfishInitC = Void Function();
typedef StockfishCommandC = Pointer<Char> Function(Pointer<Char>);
typedef StockfishCleanupC = Void Function();

typedef StockfishInit = void Function();
typedef StockfishCommand = Pointer<Char> Function(Pointer<Char>);
typedef StockfishCleanup = void Function();

void main() async {
  print('Loading Stockfish DLL...');
  // Adjust path to where stockfish.dll is
  final libPath = 'janggi_master/stockfish.dll'; 
  final dylib = DynamicLibrary.open(libPath);

  final stockfishInit = dylib
      .lookup<NativeFunction<StockfishInitC>>('stockfish_init')
      .asFunction<StockfishInit>();
  final stockfishCommand = dylib
      .lookup<NativeFunction<StockfishCommandC>>('stockfish_command')
      .asFunction<StockfishCommand>();

  print('Initializing...');
  stockfishInit();

  String sendCmd(String cmd) {
    print('>> $cmd');
    final cmdP = cmd.toNativeUtf8();
    final resultP = stockfishCommand(cmdP.cast<Char>());
    final result = resultP.cast<Utf8>().toDartString();
    malloc.free(cmdP);
    print('<< $result');
    return result;
  }

  // Init UCI
  sendCmd('uci');
  sendCmd('setoption name UCI_Variant value janggi');
  sendCmd('isready');

  // Problematic FEN
  // "2ba1a1b1/4rk3/1cn2n1c1/p1p2ppBr/9/6P2/P1P1P2P1/2N2C1C1/4K4/R1BA1AN2 b - - 0 1"
  // Note: Standard FEN for Janggi might differ if I am using wrong chars.
  // Testing with chars: n, b.
  final fen = "2ea1a1e1/4rk3/1ch2h1c1/p1p2ppHr/9/6P2/P1P1P2P1/2H2C1C1/4K4/R1EA1AEH2 b - - 0 1";
  
  print('Setting position FEN: $fen');
  sendCmd('position fen $fen');

  print('Go for best move...');
  sendCmd('go depth 10');

  // Wait for a bit (simulate thinking if blocking, though stockfish command might be blocking or immediate)
  // Usually 'go' returns immediately if threaded, or blocks if not.
  // The FFI wrapper provided implies blocking/synchronous return for some commands?
  // Stockfish 'go' usually is async and outputs info lines, then bestmove.
  // But 'stockfish_command' usually manages standard I/O redirection or returns immediate output.
  // If it's the standard simple FFI interface, 'go' might not return until done OR return nothing and print to stdout.
  // However, the original code uses:
  // final result = command('go ...');
  // So it expects the output in the return value?
  // Standard Stockfish logic: 'go' starts search. Output comes via callbacks or stdout.
  // The 'stockfish_command' function in 'stockfish_ffi.dart' seems to capture output?
  // If it captures output, then 'go' must block until finished? 
  // Let's assume it blocks or we read output.
  
  // Clean up handled by OS on exit
}
