import 'lib/stockfish_ffi.dart';

void main() {
  StockfishFFI.init();
  
  print('Check UCI_Variant option:');
  var result = StockfishFFI.command('setoption name UCI_Variant value janggi');
  print('Set variant result: $result\n');

  StockfishFFI.isReady();

  print('Get variant info:');
  result = StockfishFFI.command('uci');
  print('UCI info:\n$result\n');

  StockfishFFI.cleanup();
}
