import 'piece.dart';
import 'position.dart';

/// Represents the Janggi board state
/// 9 files x 10 ranks
class Board {
  // Internal board representation: board[rank][file]
  final List<List<Piece?>> _board;

  Board() : _board = List.generate(10, (_) => List.filled(9, null));

  /// Create board from copy
  Board.copy(Board other)
      : _board = List.generate(
          10,
          (rank) => List.generate(
            9,
            (file) => other._board[rank][file],
          ),
        );

  /// Get piece at position
  Piece? getPiece(Position pos) {
    if (!pos.isValid) return null;
    return _board[pos.rank][pos.file];
  }

  /// Set piece at position
  void setPiece(Position pos, Piece? piece) {
    if (!pos.isValid) return;
    _board[pos.rank][pos.file] = piece;
  }

  /// Move piece from one position to another
  /// Returns captured piece if any
  Piece? movePiece(Position from, Position to) {
    final piece = getPiece(from);
    if (piece == null) return null;

    // FIX: from과 to가 같으면 아무것도 하지 않음
    if (from == to) return null;

    final captured = getPiece(to);
    setPiece(to, piece);
    setPiece(from, null);

    return captured;
  }

  /// Check if position is empty
  bool isEmpty(Position pos) => getPiece(pos) == null;

  /// Check if position has piece of specific color
  bool hasColor(Position pos, PieceColor color) {
    final piece = getPiece(pos);
    return piece != null && piece.color == color;
  }

  /// Find position of a specific piece (only finds first occurrence)
  Position? findPiece(PieceType type, PieceColor color) {
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = _board[rank][file];
        if (piece != null && piece.type == type && piece.color == color) {
          return Position(file: file, rank: rank);
        }
      }
    }
    return null;
  }

  /// Find all pieces of a specific color
  List<Position> findAllPieces(PieceColor color) {
    final positions = <Position>[];
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = _board[rank][file];
        if (piece != null && piece.color == color) {
          positions.add(Position(file: file, rank: rank));
        }
      }
    }
    return positions;
  }

  /// Clear the board
  void clear() {
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        _board[rank][file] = null;
      }
    }
  }

  /// Set up initial Janggi position
  /// 楚(Cho/Blue) = 파란색 = 선공 = bottom (ranks 0-3)
  /// 漢(Han/Red) = 빨간색 = 후공 = top (ranks 6-9)
  /// 외상 배치 (차-상-마)
  void setupInitialPosition() {
    clear();

    // Blue pieces 楚 (bottom, ranks 0-3) - 선공, 파란색
    // Rank 0: Back row - 외상 배치 (Chariot-Elephant-Horse on both sides)
    setPiece(Position(file: 0, rank: 0), Piece(type: PieceType.chariot, color: PieceColor.blue));
    setPiece(Position(file: 1, rank: 0), Piece(type: PieceType.elephant, color: PieceColor.blue));
    setPiece(Position(file: 2, rank: 0), Piece(type: PieceType.horse, color: PieceColor.blue));
    setPiece(Position(file: 3, rank: 0), Piece(type: PieceType.guard, color: PieceColor.blue));
    // File 4 empty at rank 0
    setPiece(Position(file: 5, rank: 0), Piece(type: PieceType.guard, color: PieceColor.blue));
    setPiece(Position(file: 6, rank: 0), Piece(type: PieceType.horse, color: PieceColor.blue));
    setPiece(Position(file: 7, rank: 0), Piece(type: PieceType.elephant, color: PieceColor.blue));
    setPiece(Position(file: 8, rank: 0), Piece(type: PieceType.chariot, color: PieceColor.blue));

    // Rank 1: General in palace center
    setPiece(Position(file: 4, rank: 1), Piece(type: PieceType.general, color: PieceColor.blue));

    // Rank 2: Cannons
    setPiece(Position(file: 1, rank: 2), Piece(type: PieceType.cannon, color: PieceColor.blue));
    setPiece(Position(file: 7, rank: 2), Piece(type: PieceType.cannon, color: PieceColor.blue));

    // Rank 3: Soldiers
    setPiece(Position(file: 0, rank: 3), Piece(type: PieceType.soldier, color: PieceColor.blue));
    setPiece(Position(file: 2, rank: 3), Piece(type: PieceType.soldier, color: PieceColor.blue));
    setPiece(Position(file: 4, rank: 3), Piece(type: PieceType.soldier, color: PieceColor.blue));
    setPiece(Position(file: 6, rank: 3), Piece(type: PieceType.soldier, color: PieceColor.blue));
    setPiece(Position(file: 8, rank: 3), Piece(type: PieceType.soldier, color: PieceColor.blue));

    // Red pieces 漢 (top, ranks 6-9) - 후공, 빨간색
    // Rank 6: Soldiers
    setPiece(Position(file: 0, rank: 6), Piece(type: PieceType.soldier, color: PieceColor.red));
    setPiece(Position(file: 2, rank: 6), Piece(type: PieceType.soldier, color: PieceColor.red));
    setPiece(Position(file: 4, rank: 6), Piece(type: PieceType.soldier, color: PieceColor.red));
    setPiece(Position(file: 6, rank: 6), Piece(type: PieceType.soldier, color: PieceColor.red));
    setPiece(Position(file: 8, rank: 6), Piece(type: PieceType.soldier, color: PieceColor.red));

    // Rank 7: Cannons
    setPiece(Position(file: 1, rank: 7), Piece(type: PieceType.cannon, color: PieceColor.red));
    setPiece(Position(file: 7, rank: 7), Piece(type: PieceType.cannon, color: PieceColor.red));

    // Rank 8: General in palace center
    setPiece(Position(file: 4, rank: 8), Piece(type: PieceType.general, color: PieceColor.red));

    // Rank 9: Back row - 외상 배치 (Chariot-Elephant-Horse on both sides)
    setPiece(Position(file: 0, rank: 9), Piece(type: PieceType.chariot, color: PieceColor.red));
    setPiece(Position(file: 1, rank: 9), Piece(type: PieceType.elephant, color: PieceColor.red));
    setPiece(Position(file: 2, rank: 9), Piece(type: PieceType.horse, color: PieceColor.red));
    setPiece(Position(file: 3, rank: 9), Piece(type: PieceType.guard, color: PieceColor.red));
    // File 4 empty at rank 9
    setPiece(Position(file: 5, rank: 9), Piece(type: PieceType.guard, color: PieceColor.red));
    setPiece(Position(file: 6, rank: 9), Piece(type: PieceType.horse, color: PieceColor.red));
    setPiece(Position(file: 7, rank: 9), Piece(type: PieceType.elephant, color: PieceColor.red));
    setPiece(Position(file: 8, rank: 9), Piece(type: PieceType.chariot, color: PieceColor.red));
  }

  /// Create a copy of this board
  Board copy() => Board.copy(this);

  @override
  String toString() {
    final buffer = StringBuffer();
    for (int rank = 9; rank >= 0; rank--) {
      buffer.write('$rank ');
      for (int file = 0; file < 9; file++) {
        final piece = _board[rank][file];
        if (piece != null) {
          buffer.write('${piece.character} ');
        } else {
          buffer.write('·  ');
        }
      }
      buffer.writeln();
    }
    buffer.write('  a  b  c  d  e  f  g  h  i');
    return buffer.toString();
  }
}
