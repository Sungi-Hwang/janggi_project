import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/stockfish_ffi.dart';

void main() {
  test('selectBestMoveFromEngineResponse prefers a valid bestmove', () {
    const response = '''
info depth 10 score mate 3 pv e10e10
bestmove d2a2 ponder e2f3
''';

    expect(
      StockfishFFI.selectBestMoveFromEngineResponse(response),
      'd2a2',
    );
  });

  test('selectBestMoveFromEngineResponse falls back to first valid PV move', () {
    const response = '''
info depth 12 multipv 1 score mate 2 pv d2a2 e2f3
info depth 12 multipv 2 score mate 2 pv e10e10
bestmove e10e10
''';

    expect(
      StockfishFFI.selectBestMoveFromEngineResponse(response),
      'd2a2',
    );
  });

  test('isUsableUciMove rejects null-move and same-square outputs', () {
    expect(StockfishFFI.isUsableUciMove('0000'), isFalse);
    expect(StockfishFFI.isUsableUciMove('e10e10'), isFalse);
    expect(StockfishFFI.isUsableUciMove('d2a2'), isTrue);
    expect(StockfishFFI.isUsableUciMove('b10c8'), isTrue);
  });
}
