/// Represents a position on the Janggi board
/// Janggi board is 9 files (columns) x 10 ranks (rows)
/// File: 0-8 (left to right, a-i)
/// Rank: 0-9 (bottom to top for Red, top to bottom for Blue)
class Position {
  final int file; // 0-8 (a-i)
  final int rank; // 0-9

  const Position({
    required this.file,
    required this.rank,
  });

  /// Create position from algebraic notation (e.g., "a0", "e4")
  factory Position.fromAlgebraic(String notation) {
    if (notation.length < 2) {
      throw ArgumentError('Invalid notation: $notation');
    }

    final file = notation[0].toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(notation.substring(1));

    if (file < 0 || file > 8 || rank < 0 || rank > 9) {
      throw ArgumentError('Position out of bounds: $notation');
    }

    return Position(file: file, rank: rank);
  }

  /// Convert to algebraic notation
  String toAlgebraic() {
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    return '$fileChar$rank';
  }

  /// Check if position is valid on board
  bool get isValid {
    return file >= 0 && file <= 8 && rank >= 0 && rank <= 9;
  }

  /// Check if position is in palace (fortress)
  /// Blue palace (초): files d-f (3-5), ranks 0-2 (bottom)
  /// Red palace (한): files d-f (3-5), ranks 7-9 (top)
  bool isInPalace({required bool isRedPalace}) {
    if (isRedPalace) {
      // Red palace at top: ranks 7-9
      return file >= 3 && file <= 5 && rank >= 7 && rank <= 9;
    } else {
      // Blue palace at bottom: ranks 0-2
      return file >= 3 && file <= 5 && rank >= 0 && rank <= 2;
    }
  }

  /// Get all positions on diagonal lines in palace
  List<Position> getPalaceDiagonals({required bool isRedPalace}) {
    if (!isInPalace(isRedPalace: isRedPalace)) return [];

    final baseRank = isRedPalace ? 7 : 0;
    final center = Position(file: 4, rank: baseRank + 1);

    // If this is center, return all corners
    if (file == 4 && rank == baseRank + 1) {
      return [
        Position(file: 3, rank: baseRank),
        Position(file: 5, rank: baseRank),
        Position(file: 3, rank: baseRank + 2),
        Position(file: 5, rank: baseRank + 2),
      ];
    }

    // If this is a corner, return center
    if ((file == 3 || file == 5) && (rank == baseRank || rank == baseRank + 2)) {
      return [center];
    }

    return [];
  }

  /// Calculate distance to another position
  int distanceTo(Position other) {
    return (file - other.file).abs() + (rank - other.rank).abs();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Position && other.file == file && other.rank == rank;
  }

  @override
  int get hashCode => Object.hash(file, rank);

  @override
  String toString() => toAlgebraic();

  Position copyWith({
    int? file,
    int? rank,
  }) {
    return Position(
      file: file ?? this.file,
      rank: rank ?? this.rank,
    );
  }

  /// Create a new position with offset
  Position offset(int fileOffset, int rankOffset) {
    return Position(
      file: file + fileOffset,
      rank: rank + rankOffset,
    );
  }
}
