import 'lib/stockfish_ffi.dart';

void main() {
  print('=== Valid Move Test ===\n');

  StockfishFFI.init();
  StockfishFFI.isReady();

  // Test Stockfish's own suggested move
  print('Test: Using Stockfish\'s own suggested move');
  final firstMove = StockfishFFI.getBestMove(depth: 1);
  print('Stockfish suggests: $firstMove');

  if (firstMove != null) {
    print('\nNow applying that move back to Stockfish...');
    final result = StockfishFFI.command('position startpos moves $firstMove');
    print('Result: $result');

    final nextMove = StockfishFFI.getBestMove(depth: 1);
    print('Next best move: $nextMove (should be BLACK\'s move)\n');
  }

  StockfishFFI.cleanup();
  print('=== Test Complete ===');
}
