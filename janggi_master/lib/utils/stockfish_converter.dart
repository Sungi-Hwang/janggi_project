import '../models/position.dart';
import '../models/piece.dart';
import '../models/board.dart';

/// Converts between Flutter coordinates and Stockfish UCI coordinates
///
/// Flutter board orientation:
/// - Files: 0-8 (a-i, left to right)
/// - Ranks: 0-9 (bottom to top)
/// - Blue (초) at bottom (ranks 0-3) - MOVES FIRST
/// - Red (한) at top (ranks 7-9)
///
/// Fairy-Stockfish Janggi orientation:
/// - Files: a-i
/// - Ranks: 1-10 in UCI (rank 1 = bottom, rank 10 = top)
/// - Uppercase (White) at bottom (ranks 1-4) - MOVES FIRST
/// - Lowercase (Black) at top (ranks 7-10)
///
/// Color mapping (to match board orientation):
/// - Blue (초, bottom, moves first) → White (uppercase) in FEN
/// - Red (한, top) → Black (lowercase) in FEN
///
/// Coordinate mapping:
/// - Files: same (a-i maps to 0-8)
/// - Ranks: Direct mapping +1
///   - Flutter rank 0 (bottom) → Stockfish rank 1 (UCI)
///   - Flutter rank 9 (top) → Stockfish rank 10 (UCI)
class StockfishConverter {
  /// Convert Flutter position to Stockfish UCI notation
  /// Example: Position(file: 4, rank: 0) -> "e1" (bottom)
  /// Example: Position(file: 4, rank: 9) -> "e10" (top)
  static String toUCI(Position pos) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + pos.file);
    // Direct mapping: Flutter rank 0 (bottom) -> Stockfish rank 1
    // Flutter rank 9 (top) -> Stockfish rank 10
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
    // Direct mapping: Stockfish rank 1 -> Flutter rank 0
    // Stockfish rank 10 -> Flutter rank 9
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

  /// Convert Board to FEN notation
  /// currentPlayer: who should move next (Blue or Red)
  static String boardToFEN(Board board, PieceColor currentPlayer) {
    final buffer = StringBuffer();

    // FEN reads from rank 10 (top) to rank 1 (bottom)
    // Flutter: rank 9 = top (Red), rank 0 = bottom (Blue)
    for (int rank = 9; rank >= 0; rank--) {
      int emptyCount = 0;

      for (int file = 0; file < 9; file++) {
        final pos = Position(file: file, rank: rank);
        final piece = board.getPiece(pos);

        if (piece == null) {
          emptyCount++;
        } else {
          // Write empty count if any
          if (emptyCount > 0) {
            buffer.write(emptyCount);
            emptyCount = 0;
          }

          // Write piece
          // IMPORTANT: Use Fairy-Stockfish Janggi piece letters!
          // From variants.ini: r=rook, n=knight, b=bishop, a=alfil, k=king, c=cannon, p=pawn
          String pieceChar;
          switch (piece.type) {
            case PieceType.general:
              pieceChar = 'k';  // king
              break;
            case PieceType.guard:
              pieceChar = 'a';  // alfil
              break;
            case PieceType.horse:
              pieceChar = 'n';  // knight (Fairy-Stockfish uses 'n' for horse)
              break;
            case PieceType.elephant:
              pieceChar = 'b';  // bishop (Fairy-Stockfish uses 'b' for elephant)
              break;
            case PieceType.chariot:
              pieceChar = 'r';  // rook
              break;
            case PieceType.cannon:
              pieceChar = 'c';  // cannon
              break;
            case PieceType.soldier:
              pieceChar = 'p';  // pawn
              break;
          }

          // IMPORTANT: Fairy-Stockfish Janggi uses:
          // - Uppercase (White) at bottom (rank 1-4)
          // - Lowercase (Black) at top (rank 7-10)
          // But our Flutter board has:
          // - Blue at bottom (rank 0-3)
          // - Red at top (rank 7-9)
          // So we need to SWAP: Blue=Uppercase, Red=Lowercase
          if (piece.color == PieceColor.blue) {
            pieceChar = pieceChar.toUpperCase();
          }
          // Red pieces stay lowercase

          buffer.write(pieceChar);
        }
      }

      // Write remaining empty count
      if (emptyCount > 0) {
        buffer.write(emptyCount);
      }

      // Add rank separator (except for last rank)
      if (rank > 0) {
        buffer.write('/');
      }
    }

    // Add turn indicator
    // After swapping: Blue=WHITE (uppercase), Red=BLACK (lowercase)
    buffer.write(currentPlayer == PieceColor.blue ? ' w' : ' b');

    // Add remaining FEN fields (castling, en passant, halfmove, fullmove)
    buffer.write(' - - 0 1');

    return buffer.toString();
  }
}
