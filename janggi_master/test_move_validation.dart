import 'lib/stockfish_ffi.dart';

void main() {
  print('=== Move Validation Test ===\n');

  StockfishFFI.init();
  StockfishFFI.isReady();

  // Test 1: Valid move
  print('Test 1: position startpos moves e4e5 (soldier forward)');
  final result1 = StockfishFFI.command('position startpos moves e4e5');
  print('Result: $result1');
  final move1 = StockfishFFI.getBestMove(depth: 2);
  print('Best move after e4e5: $move1\n');

  // Test 2: Invalid move
  print('Test 2: position startpos moves a1a2 (invalid - no piece can move there)');
  final result2 = StockfishFFI.command('position startpos moves a1a2');
  print('Result: $result2');
  final move2 = StockfishFFI.getBestMove(depth: 2);
  print('Best move after a1a2: $move2\n');

  // Test 3: Check current turn
  print('Test 3: Who moves first?');
  final moveStart = StockfishFFI.command('position startpos');
  print('Setting startpos: $moveStart');
  final firstMove = StockfishFFI.getBestMove(depth: 1);
  print('First move (should be WHITE/Blue): $firstMove\n');

  StockfishFFI.cleanup();
  print('=== Test Complete ===');
}
