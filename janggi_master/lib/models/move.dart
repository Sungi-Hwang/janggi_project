import 'piece.dart';
import 'position.dart';

/// Represents a move in Janggi
class Move {
  final Position from;
  final Position to;
  final Piece? capturedPiece;
  final bool isCheck;
  final bool isCheckmate;

  const Move({
    required this.from,
    required this.to,
    this.capturedPiece,
    this.isCheck = false,
    this.isCheckmate = false,
  });

  /// Create move from UCI notation (e.g., "e2e4")
  factory Move.fromUCI(String uci, {Piece? capturedPiece}) {
    if (uci.length < 4) {
      throw ArgumentError('Invalid UCI notation: $uci');
    }

    final fromFile = uci[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final fromRank = int.parse(uci[1]);
    final toFile = uci[2].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toRank = int.parse(uci[3]);

    return Move(
      from: Position(file: fromFile, rank: fromRank),
      to: Position(file: toFile, rank: toRank),
      capturedPiece: capturedPiece,
    );
  }

  /// Convert to UCI notation for Stockfish
  /// Stockfish uses ranks 1-10, but Flutter uses 0-9
  String toUCI() {
    final fromFile = String.fromCharCode('a'.codeUnitAt(0) + from.file);
    final fromRank = from.rank + 1; // Convert Flutter rank (0-9) to Stockfish rank (1-10)
    final toFile = String.fromCharCode('a'.codeUnitAt(0) + to.file);
    final toRank = to.rank + 1; // Convert Flutter rank (0-9) to Stockfish rank (1-10)
    return '$fromFile$fromRank$toFile$toRank';
  }

  /// Check if this is a capture move
  bool get isCapture => capturedPiece != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Move && other.from == from && other.to == to;
  }

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(toUCI());
    if (isCapture) buffer.write('x${capturedPiece!.character}');
    if (isCheckmate) {
      buffer.write('#');
    } else if (isCheck) {
      buffer.write('+');
    }
    return buffer.toString();
  }

  Move copyWith({
    Position? from,
    Position? to,
    Piece? capturedPiece,
    bool? isCheck,
    bool? isCheckmate,
  }) {
    return Move(
      from: from ?? this.from,
      to: to ?? this.to,
      capturedPiece: capturedPiece ?? this.capturedPiece,
      isCheck: isCheck ?? this.isCheck,
      isCheckmate: isCheckmate ?? this.isCheckmate,
    );
  }
}
