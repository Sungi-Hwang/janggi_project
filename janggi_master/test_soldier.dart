import 'lib/stockfish_ffi.dart';

void main() {
  StockfishFFI.init();
  StockfishFFI.isReady();

  print('Test 1: Can WHITE soldier at e4 move to e5?');
  var result = StockfishFFI.command('position startpos moves e4e5');
  print('Result: $result\n');

  print('Test 2: Can WHITE soldier at a4 move to a5?');
  result = StockfishFFI.command('position startpos moves a4a5');
  print('Result: $result\n');

  print('Test 3: What moves ARE valid from startpos?');
  final move = StockfishFFI.getBestMove(depth: 1);
  print('Stockfish suggests: $move\n');

  StockfishFFI.cleanup();
}
