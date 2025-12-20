import 'lib/stockfish_ffi.dart';

void main() {
  print('=== List Legal Moves Test ===\n');

  StockfishFFI.init();
  StockfishFFI.isReady();

  // Set to starting position
  StockfishFFI.command('position startpos');

  // Request legal moves using perft
  print('Requesting legal moves from starting position...');
  final result = StockfishFFI.command('go perft 1');
  print(result);

  StockfishFFI.cleanup();
  print('\n=== Test Complete ===');
}
