import 'package:janggi_master/stockfish_ffi.dart';

void main() {
  print('=== Stockfish Test ===');

  try {
    print('1. Initializing Stockfish...');
    StockfishFFI.init();
    print('   ✓ Initialized');

    print('\n2. Testing isReady...');
    final ready = StockfishFFI.isReady();
    print('   ✓ Ready: $ready');

    print('\n3. Testing UCI command...');
    final uciResponse = StockfishFFI.command('uci');
    print('   Response: $uciResponse');

    print('\n4. Setting initial position...');
    StockfishFFI.setPosition();
    print('   ✓ Position set');

    print('\n5. Getting best move (depth 1)...');
    print('   This is where it might hang...');
    final bestMove = StockfishFFI.getBestMove(depth: 1);
    print('   ✓ Best move: $bestMove');

    print('\n6. Cleanup...');
    StockfishFFI.cleanup();
    print('   ✓ Cleaned up');

    print('\n=== Test Complete ===');
  } catch (e, stackTrace) {
    print('\n!!! ERROR !!!');
    print('Error: $e');
    print('Stack trace:\n$stackTrace');
  }
}
