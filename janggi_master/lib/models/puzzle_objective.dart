import 'piece.dart';

class PuzzleObjective {
  PuzzleObjective._();

  static const String mate = 'mate';
  static const String materialGain = 'material_gain';

  static const String keyObjectiveType = 'objectiveType';
  static const String keyObjective = 'objective';

  static const int chariotValueCp = 900;
  static const int cannonValueCp = 500;
  static const int horseValueCp = 450;
  static const int elephantValueCp = 450;
  static const int guardValueCp = 200;
  static const int soldierValueCp = 100;
  static const int generalValueCp = 10000;

  static const int defaultChariotNetGainCp = 450;
  static const int defaultCannonNetGainCp = 300;
  static const int defaultFinalEvalCp = 250;
  static const int defaultEvalGainCp = 150;

  static String typeOf(Map<String, dynamic> puzzle) {
    return normalizeType(
      puzzle[keyObjectiveType] ?? puzzle['objective_type'],
    );
  }

  static Map<String, dynamic> objectiveOf(Map<String, dynamic> puzzle) {
    return normalizeObjective(
      type: typeOf(puzzle),
      objective: puzzle[keyObjective],
      solution: puzzle['solution'] is List
          ? List<String>.from(puzzle['solution'] as List)
          : const <String>[],
      mateIn: (puzzle['mateIn'] as num?)?.toInt() ??
          (puzzle['mate_in'] as num?)?.toInt(),
    );
  }

  static String normalizeType(dynamic raw) {
    return raw == materialGain ? materialGain : mate;
  }

  static Map<String, dynamic> normalizeObjective({
    required String type,
    dynamic objective,
    List<String> solution = const <String>[],
    int? mateIn,
  }) {
    final normalizedType = normalizeType(type);
    if (normalizedType != materialGain) {
      return <String, dynamic>{};
    }

    final map = objective is Map
        ? Map<String, dynamic>.from(objective)
        : <String, dynamic>{};
    final targetPieceTypes = _normalizeTargetPieceTypes(
      map['targetPieceTypes'],
    );
    final maxPlayerMoves = _positiveInt(
          map['maxPlayerMoves'],
        ) ??
        mateIn ??
        _resolvePlayerMoveCount(solution);
    final minNetMaterialGainCp = _positiveInt(map['minNetMaterialGainCp']) ??
        _defaultNetGainForTargets(targetPieceTypes);

    final normalized = <String, dynamic>{
      'targetPieceTypes': targetPieceTypes,
      'maxPlayerMoves': maxPlayerMoves < 1 ? 1 : maxPlayerMoves,
      'minNetMaterialGainCp': minNetMaterialGainCp,
      'minFinalEvalCp': _intValue(map['minFinalEvalCp']) ?? defaultFinalEvalCp,
      'minEvalGainCp': _intValue(map['minEvalGainCp']) ?? defaultEvalGainCp,
    };

    for (final key in const <String>[
      'verifiedNetMaterialGainCp',
      'verifiedFinalEvalCp',
      'verifiedEvalGainCp',
      'engineDepth',
    ]) {
      final value = _intValue(map[key]);
      if (value != null) {
        normalized[key] = value;
      }
    }

    return normalized;
  }

  static Map<String, dynamic> normalizePuzzleMap(
    Map<String, dynamic> puzzle,
  ) {
    final normalized = Map<String, dynamic>.from(puzzle);
    final type = normalizeType(
      normalized[keyObjectiveType] ?? normalized['objective_type'],
    );
    final solution = normalized['solution'] is List
        ? List<String>.from(normalized['solution'] as List)
        : const <String>[];
    final mateIn = (normalized['mateIn'] as num?)?.toInt() ??
        (normalized['mate_in'] as num?)?.toInt();

    normalized[keyObjectiveType] = type;
    normalized[keyObjective] = normalizeObjective(
      type: type,
      objective: normalized[keyObjective],
      solution: solution,
      mateIn: mateIn,
    );
    return normalized;
  }

  static int playerMoveCount(Map<String, dynamic> puzzle) {
    final type = typeOf(puzzle);
    if (type == materialGain) {
      final objective = objectiveOf(puzzle);
      return _positiveInt(objective['maxPlayerMoves']) ?? 1;
    }
    final mateIn = (puzzle['mateIn'] as num?)?.toInt() ??
        (puzzle['mate_in'] as num?)?.toInt();
    if (mateIn != null && mateIn > 0) {
      return mateIn;
    }
    final solution = puzzle['solution'] is List
        ? List<String>.from(puzzle['solution'] as List)
        : const <String>[];
    return _resolvePlayerMoveCount(solution);
  }

  static String displayLabelForPuzzle(Map<String, dynamic> puzzle) {
    return displayLabel(typeOf(puzzle), objectiveOf(puzzle));
  }

  static String displayLabel(String type, Map<String, dynamic> objective) {
    if (type != materialGain) {
      return '외통';
    }

    final targets = targetPieceTypes(objective);
    if (targets.length == 1) {
      return '${pieceTypeLabel(targets.single)} 획득';
    }
    if (targets.isEmpty) {
      return '기물 획득';
    }
    return '${targets.map(pieceTypeLabel).join('/')} 획득';
  }

  static String instructionForPuzzle(Map<String, dynamic> puzzle) {
    final type = typeOf(puzzle);
    if (type != materialGain) {
      return '주어진 수 안에 상대의 탈출수를 모두 막으세요.';
    }

    final objective = objectiveOf(puzzle);
    final moves = _positiveInt(objective['maxPlayerMoves']) ?? 1;
    final label = displayLabel(type, objective);
    final finalEval =
        _intValue(objective['minFinalEvalCp']) ?? defaultFinalEvalCp;
    return '$moves수 안에 $label 후 유리한 형세를 만드세요. 기준 형세 +$finalEval';
  }

  static List<PieceType> targetPieceTypes(Map<String, dynamic> objective) {
    return _normalizeTargetPieceTypes(objective['targetPieceTypes'])
        .map(pieceTypeFromWire)
        .whereType<PieceType>()
        .toList(growable: false);
  }

  static String pieceTypeToWire(PieceType type) {
    switch (type) {
      case PieceType.general:
        return 'general';
      case PieceType.guard:
        return 'guard';
      case PieceType.horse:
        return 'horse';
      case PieceType.elephant:
        return 'elephant';
      case PieceType.chariot:
        return 'chariot';
      case PieceType.cannon:
        return 'cannon';
      case PieceType.soldier:
        return 'soldier';
    }
  }

  static PieceType? pieceTypeFromWire(dynamic raw) {
    switch (raw) {
      case 'general':
        return PieceType.general;
      case 'guard':
        return PieceType.guard;
      case 'horse':
        return PieceType.horse;
      case 'elephant':
        return PieceType.elephant;
      case 'chariot':
        return PieceType.chariot;
      case 'cannon':
        return PieceType.cannon;
      case 'soldier':
        return PieceType.soldier;
      default:
        return null;
    }
  }

  static String pieceTypeLabel(PieceType type) {
    switch (type) {
      case PieceType.general:
        return '궁';
      case PieceType.guard:
        return '사';
      case PieceType.horse:
        return '마';
      case PieceType.elephant:
        return '상';
      case PieceType.chariot:
        return '차';
      case PieceType.cannon:
        return '포';
      case PieceType.soldier:
        return '졸';
    }
  }

  static int pieceValueCp(PieceType type) {
    switch (type) {
      case PieceType.general:
        return generalValueCp;
      case PieceType.guard:
        return guardValueCp;
      case PieceType.horse:
        return horseValueCp;
      case PieceType.elephant:
        return elephantValueCp;
      case PieceType.chariot:
        return chariotValueCp;
      case PieceType.cannon:
        return cannonValueCp;
      case PieceType.soldier:
        return soldierValueCp;
    }
  }

  static int materialScoreForPieces(Iterable<Piece> pieces) {
    return pieces.fold<int>(
      0,
      (sum, piece) => sum + pieceValueCp(piece.type),
    );
  }

  static MaterialGainRuntimeResult evaluateMaterialGain({
    required Map<String, dynamic> objective,
    required PieceColor playerColor,
    required List<Piece> capturedByBlue,
    required List<Piece> capturedByRed,
  }) {
    final normalized = normalizeObjective(
      type: materialGain,
      objective: objective,
    );
    final targets = targetPieceTypes(normalized);
    final capturedByPlayer =
        playerColor == PieceColor.blue ? capturedByBlue : capturedByRed;
    final capturedByOpponent =
        playerColor == PieceColor.blue ? capturedByRed : capturedByBlue;
    final netGainCp = materialScoreForPieces(capturedByPlayer) -
        materialScoreForPieces(capturedByOpponent);
    final hasTargetCapture = capturedByPlayer.any(
      (piece) => targets.contains(piece.type),
    );
    final minNetGainCp =
        _intValue(normalized['minNetMaterialGainCp']) ?? defaultCannonNetGainCp;
    final verifiedFinalEvalCp = _intValue(normalized['verifiedFinalEvalCp']);
    final minFinalEvalCp =
        _intValue(normalized['minFinalEvalCp']) ?? defaultFinalEvalCp;
    final verifiedEvalGainCp = _intValue(normalized['verifiedEvalGainCp']);
    final minEvalGainCp =
        _intValue(normalized['minEvalGainCp']) ?? defaultEvalGainCp;

    final finalEvalOk =
        verifiedFinalEvalCp == null || verifiedFinalEvalCp >= minFinalEvalCp;
    final evalGainOk =
        verifiedEvalGainCp == null || verifiedEvalGainCp >= minEvalGainCp;
    final success = hasTargetCapture &&
        netGainCp >= minNetGainCp &&
        finalEvalOk &&
        evalGainOk;

    String message;
    if (!hasTargetCapture) {
      message = '목표 기물을 얻지 못했습니다.';
    } else if (netGainCp < minNetGainCp) {
      message = '기물을 얻었지만 순이득이 부족합니다. 순이득 +$netGainCp';
    } else if (!finalEvalOk || !evalGainOk) {
      message = '기물을 얻었지만 검증된 형세 기준을 넘지 못했습니다.';
    } else {
      final label = displayLabel(materialGain, normalized);
      final evalText = verifiedFinalEvalCp == null
          ? ''
          : ', 형세 ${verifiedFinalEvalCp >= 0 ? '+' : ''}$verifiedFinalEvalCp';
      message = '$label 성공, 순이득 +$netGainCp$evalText';
    }

    return MaterialGainRuntimeResult(
      success: success,
      hasTargetCapture: hasTargetCapture,
      netMaterialGainCp: netGainCp,
      verifiedFinalEvalCp: verifiedFinalEvalCp,
      verifiedEvalGainCp: verifiedEvalGainCp,
      message: message,
    );
  }

  static int _resolvePlayerMoveCount(List<String> solution) {
    final count = (solution.length + 1) ~/ 2;
    return count < 1 ? 1 : count;
  }

  static List<String> _normalizeTargetPieceTypes(dynamic raw) {
    final values = raw is List ? raw : const <dynamic>[];
    final normalized = values
        .map((value) => value.toString())
        .where((value) => value == 'chariot' || value == 'cannon')
        .toSet()
        .toList(growable: false)
      ..sort();
    return normalized.isEmpty ? <String>['cannon'] : normalized;
  }

  static int _defaultNetGainForTargets(List<String> targets) {
    return targets.contains('chariot')
        ? defaultChariotNetGainCp
        : defaultCannonNetGainCp;
  }

  static int? _positiveInt(dynamic value) {
    final parsed = _intValue(value);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class MaterialGainRuntimeResult {
  const MaterialGainRuntimeResult({
    required this.success,
    required this.hasTargetCapture,
    required this.netMaterialGainCp,
    required this.verifiedFinalEvalCp,
    required this.verifiedEvalGainCp,
    required this.message,
  });

  final bool success;
  final bool hasTargetCapture;
  final int netMaterialGainCp;
  final int? verifiedFinalEvalCp;
  final int? verifiedEvalGainCp;
  final String message;
}
