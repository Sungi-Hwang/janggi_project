/// Represents piece types in Janggi.
enum PieceType {
  general,
  guard,
  horse,
  elephant,
  chariot,
  cannon,
  soldier,
}

/// Represents piece colors (players).
///
/// This app uses:
/// - blue = 초 (楚), first move, bottom side
/// - red = 한 (漢), second move, top side
enum PieceColor {
  red,
  blue,
}

/// Represents initial piece setup configurations.
///
/// 외상 = 차-상-마
/// 내상 = 차-마-상
enum PieceSetup {
  /// 상마마상
  elephantHorseHorseElephant,

  /// 상마상마
  elephantHorseElephantHorse,

  /// 마상상마
  horseElephantElephantHorse,

  /// 마상마상
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
        return '외상 배치 (차상마 · 마상차)';
      case PieceSetup.elephantHorseElephantHorse:
        return '차상마 · 상마차';
      case PieceSetup.horseElephantElephantHorse:
        return '차마상 · 상마차';
      case PieceSetup.horseElephantHorseElephant:
        return '내상 배치 (차마상 · 마상차)';
    }
  }
}

extension PieceTypeVisualExtension on PieceType {
  /// Visual size ratio for a more Korean Janggi-like hierarchy.
  ///
  /// 궁/차 are slightly larger, 사 is smaller, 졸/병 is the smallest.
  double get faceScale {
    switch (this) {
      case PieceType.general:
        return 1.08;
      case PieceType.chariot:
        return 1.03;
      case PieceType.horse:
      case PieceType.elephant:
        return 0.98;
      case PieceType.cannon:
        return 0.96;
      case PieceType.guard:
        return 0.91;
      case PieceType.soldier:
        return 0.82;
    }
  }

  double get glyphScale {
    switch (this) {
      case PieceType.general:
        return 1.05;
      case PieceType.chariot:
        return 1.0;
      case PieceType.horse:
      case PieceType.elephant:
      case PieceType.cannon:
        return 0.98;
      case PieceType.guard:
        return 0.95;
      case PieceType.soldier:
        return 0.9;
    }
  }
}

/// Represents a Janggi piece.
class Piece {
  final PieceType type;
  final PieceColor color;

  const Piece({
    required this.type,
    required this.color,
  });

  /// Korean Hanja used on a traditional Korean Janggi piece set.
  ///
  /// - blue (초): 楚, 士, 馬, 象, 車, 包, 卒
  /// - red (한): 漢, 士, 馬, 象, 車, 包, 兵
  String get character {
    if (color == PieceColor.red) {
      switch (type) {
        case PieceType.general:
          return '漢';
        case PieceType.guard:
          return '士';
        case PieceType.horse:
          return '馬';
        case PieceType.elephant:
          return '象';
        case PieceType.chariot:
          return '車';
        case PieceType.cannon:
          return '包';
        case PieceType.soldier:
          return '兵';
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
          return '包';
        case PieceType.soldier:
          return '卒';
      }
    }
  }

  /// English name.
  String get name {
    switch (type) {
      case PieceType.general:
        return color == PieceColor.red ? 'Han' : 'Cho';
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
