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
  void setupInitialPosition({
    PieceSetup blueSetup = PieceSetup.horseElephantHorseElephant,
    PieceSetup redSetup = PieceSetup.horseElephantHorseElephant,
  }) {
    clear();

    // Blue pieces 楚 (bottom, ranks 0-3) - 선공, 파란색
    // Rank 0: Back row
    _setupBackRow(0, PieceColor.blue, blueSetup);

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

    // Rank 9: Back row
    _setupBackRow(9, PieceColor.red, redSetup);
  }

  /// Setup back row based on piece configuration
  /// Rank: 0 for Blue, 9 for Red
  void _setupBackRow(int rank, PieceColor color, PieceSetup setup) {
    // Chariots always at corners
    setPiece(Position(file: 0, rank: rank), Piece(type: PieceType.chariot, color: color));
    setPiece(Position(file: 8, rank: rank), Piece(type: PieceType.chariot, color: color));

    // Guards always at files 3 and 5
    setPiece(Position(file: 3, rank: rank), Piece(type: PieceType.guard, color: color));
    setPiece(Position(file: 5, rank: rank), Piece(type: PieceType.guard, color: color));

    // File 4 (center) is always empty

    // Setup horses and elephants based on configuration
    switch (setup) {
      case PieceSetup.elephantHorseHorseElephant:
        // 상마마상: Left(차상마), Right(마상차)
        setPiece(Position(file: 1, rank: rank), Piece(type: PieceType.elephant, color: color));
        setPiece(Position(file: 2, rank: rank), Piece(type: PieceType.horse, color: color));
        setPiece(Position(file: 6, rank: rank), Piece(type: PieceType.horse, color: color));
        setPiece(Position(file: 7, rank: rank), Piece(type: PieceType.elephant, color: color));
        break;

      case PieceSetup.elephantHorseElephantHorse:
        // 상마상마: Left(차상마), Right(상마차)
        setPiece(Position(file: 1, rank: rank), Piece(type: PieceType.elephant, color: color));
        setPiece(Position(file: 2, rank: rank), Piece(type: PieceType.horse, color: color));
        setPiece(Position(file: 6, rank: rank), Piece(type: PieceType.elephant, color: color));
        setPiece(Position(file: 7, rank: rank), Piece(type: PieceType.horse, color: color));
        break;

      case PieceSetup.horseElephantElephantHorse:
        // 마상상마: Left(차마상), Right(상마차)
        setPiece(Position(file: 1, rank: rank), Piece(type: PieceType.horse, color: color));
        setPiece(Position(file: 2, rank: rank), Piece(type: PieceType.elephant, color: color));
        setPiece(Position(file: 6, rank: rank), Piece(type: PieceType.elephant, color: color));
        setPiece(Position(file: 7, rank: rank), Piece(type: PieceType.horse, color: color));
        break;

      case PieceSetup.horseElephantHorseElephant:
        // 마상마상: Left(차마상), Right(마상차) - 내상 (default)
        setPiece(Position(file: 1, rank: rank), Piece(type: PieceType.horse, color: color));
        setPiece(Position(file: 2, rank: rank), Piece(type: PieceType.elephant, color: color));
        setPiece(Position(file: 6, rank: rank), Piece(type: PieceType.horse, color: color));
        setPiece(Position(file: 7, rank: rank), Piece(type: PieceType.elephant, color: color));
        break;
    }
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
