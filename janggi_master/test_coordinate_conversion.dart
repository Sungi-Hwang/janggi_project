import 'lib/stockfish_ffi.dart';

void main() {
  print('=== Coordinate Conversion Test ===\n');

  // Initialize
  StockfishFFI.init();
  StockfishFFI.isReady();

  // Test: User moves Blue elephant from h0 to f3
  // Flutter: h0 (file 7, rank 0) to f3 (file 5, rank 3)
  // UCI: should be h1f4 (rank + 1)
  print('User move: h0->f3 (Flutter)');
  print('Expected UCI: h1f4\n');

  StockfishFFI.command('position startpos moves h1f4');

  final move = StockfishFFI.getBestMove(depth: 3);
  print('AI response: $move');

  if (move != null) {
    // Parse move (e.g., "b1c3")
    final fromFile = move[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final fromRank = int.parse(move[1]) - 1;
    final toFile = move[2].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toRank = int.parse(move[3]) - 1;

    print('AI move UCI: $move');
    print('AI move Flutter: ${String.fromCharCode(fromFile + 'a'.codeUnitAt(0))}$fromRank -> ${String.fromCharCode(toFile + 'a'.codeUnitAt(0))}$toRank');
  }

  StockfishFFI.cleanup();
  print('\n=== Test Complete ===');
}
