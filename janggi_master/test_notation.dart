import 'lib/stockfish_ffi.dart';

void main() {
  StockfishFFI.init();
  StockfishFFI.isReady();

  print('Test different notations for soldier move:');
  
  print('\n1. Try e4e5 (UCI standard):');
  StockfishFFI.command('position startpos moves e4e5');
  
  print('\n2. What if we use pass move first?');
  var result = StockfishFFI.command('position startpos moves e9e9');
  print('Pass move result: $result');
  var move = StockfishFFI.getBestMove(depth: 1);
  print('After pass, bestmove: $move (should be BLACK)');

  print('\n3. Try a lateral soldier move e4f4:');
  StockfishFFI.command('position startpos');
  result = StockfishFFI.command('position startpos moves e4f4');
  print('Lateral move result: $result');

  StockfishFFI.cleanup();
}
