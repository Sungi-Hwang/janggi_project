import 'lib/stockfish_ffi.dart';

void main() {
  print('=== UCI Coordinate Test ===\n');

  // Initialize
  print('1. Initializing...');
  StockfishFFI.init();
  print('   ✓ Done\n');

  // Wait for ready
  print('2. Waiting for ready...');
  StockfishFFI.isReady();
  print('   ✓ Ready\n');

  // Set UCI variant
  print('3. Setting variant to janggi...');
  final response = StockfishFFI.command('setoption name UCI_Variant value janggi');
  print('   Response: $response\n');

  // Get starting position
  print('4. Setting start position...');
  StockfishFFI.command('position startpos');
  print('   ✓ Done\n');

  // Get a move
  print('5. Getting best move from start position...');
  final move = StockfishFFI.getBestMove(depth: 3);
  print('   Best move: $move\n');

  // Try a specific move and see if it's valid
  print('6. Testing move h1h2 (should be invalid - no piece there)...');
  final testResult = StockfishFFI.command('position startpos moves h1h2');
  print('   Result: $testResult\n');

  // Try a valid move for Blue/WHITE (bottom)
  print('7. Testing move b3c3 (soldier move, if ranks are 1-10)...');
  final test2 = StockfishFFI.command('position startpos moves b4b5');
  print('   Result: $test2\n');

  // Get position after move
  print('8. Getting best move after b4b5...');
  final move2 = StockfishFFI.getBestMove(depth: 2);
  print('   Best move: $move2\n');

  StockfishFFI.cleanup();
  print('\n=== Test Complete ===');
}
