/// Represents piece types in Janggi
enum PieceType {
  general,  // 將(General/King)
  guard,    // 士(Guard/Advisor)
  horse,    // 馬(Horse/Knight)
  elephant, // 象(Elephant)
  chariot,  // 車(Chariot/Rook)
  cannon,   // 包(Cannon)
  soldier,  // 卒(Soldier/Pawn)
}

/// Represents piece colors (players)
enum PieceColor {
  red,   // Cho (Red/Han)
  blue,  // Han (Blue/Chu)
}

/// Represents a Janggi piece
class Piece {
  final PieceType type;
  final PieceColor color;

  const Piece({
    required this.type,
    required this.color,
  });

  /// Get Korean character representation
  String get character {
    if (color == PieceColor.red) {
      switch (type) {
        case PieceType.general:
          return '漢';
        case PieceType.guard:
          return '仕';
        case PieceType.horse:
          return '馬';
        case PieceType.elephant:
          return '象';
        case PieceType.chariot:
          return '車';
        case PieceType.cannon:
          return '包';
        case PieceType.soldier:
          return '卒';
      }
    } else {
      switch (type) {
        case PieceType.general:
          return '楚';
        case PieceType.guard:
          return '士';
        case PieceType.horse:
          return '馬';
        case PieceType.elephant:
          return '象';
        case PieceType.chariot:
          return '車';
        case PieceType.cannon:
          return '砲';
        case PieceType.soldier:
          return '兵';
      }
    }
  }

  /// Get English name
  String get name {
    switch (type) {
      case PieceType.general:
        return color == PieceColor.red ? 'Han' : 'Chu';
      case PieceType.guard:
        return 'Guard';
      case PieceType.horse:
        return 'Horse';
      case PieceType.elephant:
        return 'Elephant';
      case PieceType.chariot:
        return 'Chariot';
      case PieceType.cannon:
        return 'Cannon';
      case PieceType.soldier:
        return 'Soldier';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Piece && other.type == type && other.color == color;
  }

  @override
  int get hashCode => Object.hash(type, color);

  @override
  String toString() => '$color $name';

  Piece copyWith({
    PieceType? type,
    PieceColor? color,
  }) {
    return Piece(
      type: type ?? this.type,
      color: color ?? this.color,
    );
  }
}
