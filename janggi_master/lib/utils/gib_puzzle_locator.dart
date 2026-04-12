import '../models/piece.dart';
import '../stockfish_ffi.dart';
import '../utils/gib_parser.dart';

/// Stockfish-assisted helpers for locating the tactical start of a GIB line.
///
/// Separated from [GibParser] so pure Dart CLI tools can import the parser
/// without pulling in Flutter-only engine bindings.
class GibPuzzleLocator {
  static Future<Map<String, dynamic>?> _evaluatePosition(
    List<String> gibMoves,
    int moveIdx,
  ) async {
    final board = GibParser.replayMovesToPosition(gibMoves, upToMove: moveIdx);
    if (board == null) return null;

    final currentPlayer =
        (moveIdx % 2 == 0) ? PieceColor.blue : PieceColor.red;
    final fen = GibParser.boardToFen(board, currentPlayer);
    final result = await StockfishFFI.analyzeIsolated(fen, depth: 10);
    if (result == null) {
      return {'type': 'cp', 'value': 0};
    }
    return {
      'type': result['type'],
      'value': result['value'],
    };
  }

  /// Find the move index where the decisive mating sequence begins.
  static Future<int> findPuzzleStartPosition(
    List<String> gibMoves, {
    int minMovesFromEnd = 5,
    int maxMovesFromEnd = 30,
  }) async {
    final totalMoves = gibMoves.length;
    final startSearchFrom =
        (totalMoves - minMovesFromEnd).clamp(0, totalMoves);
    final endSearchAt = (totalMoves - maxMovesFromEnd).clamp(0, totalMoves);

    String? previousType;

    for (int moveIdx = startSearchFrom; moveIdx >= endSearchAt; moveIdx--) {
      final eval = await _evaluatePosition(gibMoves, moveIdx);
      if (eval == null) continue;

      final currentType = eval['type'] as String?;
      if (previousType == 'mate' && currentType == 'cp') {
        return moveIdx + 1;
      }
      previousType = currentType;
    }

    return (totalMoves * 0.7).round().clamp(10, totalMoves - 5);
  }
}
