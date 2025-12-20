import '../models/position.dart';

/// Converts between Flutter coordinates and Stockfish UCI coordinates
///
/// Flutter (Blue at bottom):
/// - Files: 0-8 (a-i)
/// - Ranks: 0-9 (bottom to top)
/// - Blue (초) at bottom (ranks 0-3)
/// - Red (한) at top (ranks 6-9)
///
/// Stockfish (using color-swapped FEN):
/// - Files: a-i
/// - Ranks: 1-10 in UCI (rank 1 = bottom, rank 10 = top)
/// - Blue (BLACK) at bottom (FEN line 10 = rank 1-4, lowercase)
/// - Red (WHITE) at top (FEN line 1 = rank 7-10, uppercase)
/// - Colors are swapped: Blue=BLACK (lowercase), Red=WHITE (uppercase)
///
/// Coordinate mapping:
/// - Files: same (a-i maps to 0-8)
/// - Ranks: FLIPPED! Stockfish rank = 10 - Flutter rank
///   - Flutter rank 0 (bottom, Blue) → Stockfish rank 10 (FEN line 1, reversed)
///   - Flutter rank 9 (top, Red) → Stockfish rank 1 (FEN line 10, reversed)
class StockfishConverter {
  /// Convert Flutter position to Stockfish UCI notation
  /// Example: Position(file: 4, rank: 0) -> "e1" (bottom)
  /// Example: Position(file: 4, rank: 9) -> "e10" (top)
  static String toUCI(Position pos) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + pos.file);
    // FEN reads from rank 10 (top) to rank 1 (bottom)
    // Flutter: rank 0=bottom, rank 9=top
    // Stockfish: rank 1=bottom, rank 10=top
    // So: Stockfish rank = Flutter rank + 1
    final rank = (pos.rank + 1).toString();
    return '$file$rank';
  }

  /// Convert Stockfish UCI notation to Flutter position
  /// Example: "e4" -> Position(file: 4, rank: 3)
  /// Example: "b10" -> Position(file: 1, rank: 9)
  static Position fromUCI(String uci) {
    if (uci.length < 2) {
      throw ArgumentError('Invalid UCI notation: $uci');
    }

    final file = uci[0].toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);

    // Parse rank - could be 1 or 2 digits (1-10)
    final rankStr = uci.substring(1);
    final stockfishRank = int.parse(rankStr);
    // Direct mapping: Stockfish 1-10 -> Flutter 0-9
    final rank = stockfishRank - 1;

    if (file < 0 || file > 8 || rank < 0 || rank > 9) {
      throw ArgumentError('Position out of bounds: $uci (file=$file, rank=$rank, stockfishRank=$stockfishRank)');
    }

    return Position(file: file, rank: rank);
  }

  /// Convert Flutter move to Stockfish UCI move
  /// Example: from e3 to e4 -> "e3e4"
  static String moveToUCI(Position from, Position to) {
    return '${toUCI(from)}${toUCI(to)}';
  }
}
