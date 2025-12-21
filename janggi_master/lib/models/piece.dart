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

/// Represents initial piece setup configurations
/// 외상 = Elephant outside (Chariot-Elephant-Horse)
/// 내상 = Elephant inside (Chariot-Horse-Elephant)
enum PieceSetup {
  /// 상마마상 (Elephant-Horse-Horse-Elephant)
  /// Left: 차상마, Right: 마상차
  elephantHorseHorseElephant,

  /// 상마상마 (Elephant-Horse-Elephant-Horse)
  /// Left: 차상마, Right: 상마차
  elephantHorseElephantHorse,

  /// 마상상마 (Horse-Elephant-Elephant-Horse)
  /// Left: 차마상, Right: 상마차
  horseElephantElephantHorse,

  /// 마상마상 (Horse-Elephant-Horse-Elephant)
  /// Left: 차마상, Right: 마상차
  horseElephantHorseElephant,
}

extension PieceSetupExtension on PieceSetup {
  String get displayName {
    switch (this) {
      case PieceSetup.elephantHorseHorseElephant:
        return '상마마상';
      case PieceSetup.elephantHorseElephantHorse:
        return '상마상마';
      case PieceSetup.horseElephantElephantHorse:
        return '마상상마';
      case PieceSetup.horseElephantHorseElephant:
        return '마상마상';
    }
  }

  String get description {
    switch (this) {
      case PieceSetup.elephantHorseHorseElephant:
        return '외상 배치 (차상마-마상차)';
      case PieceSetup.elephantHorseElephantHorse:
        return '차상마-상마차';
      case PieceSetup.horseElephantElephantHorse:
        return '차마상-상마차';
      case PieceSetup.horseElephantHorseElephant:
        return '내상 배치 (차마상-마상차)';
    }
  }
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
