class PuzzleProgressEntry {
  const PuzzleProgressEntry({
    required this.puzzleId,
    this.attempts = 0,
    this.solvedCount = 0,
    this.failedCount = 0,
    this.firstSolvedAt,
    this.lastSolvedAt,
    this.lastAttemptedAt,
  });

  factory PuzzleProgressEntry.empty(String puzzleId) {
    return PuzzleProgressEntry(puzzleId: puzzleId);
  }

  factory PuzzleProgressEntry.fromJson(
    String puzzleId,
    Map<String, dynamic> json,
  ) {
    return PuzzleProgressEntry(
      puzzleId: puzzleId,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      solvedCount: (json['solvedCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
      firstSolvedAt: _parseDateTime(json['firstSolvedAt']),
      lastSolvedAt: _parseDateTime(json['lastSolvedAt']),
      lastAttemptedAt: _parseDateTime(json['lastAttemptedAt']),
    );
  }

  final String puzzleId;
  final int attempts;
  final int solvedCount;
  final int failedCount;
  final DateTime? firstSolvedAt;
  final DateTime? lastSolvedAt;
  final DateTime? lastAttemptedAt;

  bool get isSolved => solvedCount > 0;

  double get successRate {
    if (attempts <= 0) {
      return 0;
    }
    return solvedCount / attempts;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attempts': attempts,
      'solvedCount': solvedCount,
      'failedCount': failedCount,
      'firstSolvedAt': firstSolvedAt?.toIso8601String(),
      'lastSolvedAt': lastSolvedAt?.toIso8601String(),
      'lastAttemptedAt': lastAttemptedAt?.toIso8601String(),
    };
  }

  PuzzleProgressEntry copyWith({
    int? attempts,
    int? solvedCount,
    int? failedCount,
    DateTime? firstSolvedAt,
    DateTime? lastSolvedAt,
    DateTime? lastAttemptedAt,
    bool keepFirstSolvedAt = true,
  }) {
    return PuzzleProgressEntry(
      puzzleId: puzzleId,
      attempts: attempts ?? this.attempts,
      solvedCount: solvedCount ?? this.solvedCount,
      failedCount: failedCount ?? this.failedCount,
      firstSolvedAt:
          keepFirstSolvedAt ? (firstSolvedAt ?? this.firstSolvedAt) : null,
      lastSolvedAt: lastSolvedAt ?? this.lastSolvedAt,
      lastAttemptedAt: lastAttemptedAt ?? this.lastAttemptedAt,
    );
  }

  PuzzleProgressEntry recordSolved(DateTime completedAt) {
    return copyWith(
      attempts: attempts + 1,
      solvedCount: solvedCount + 1,
      firstSolvedAt: firstSolvedAt ?? completedAt,
      lastSolvedAt: completedAt,
      lastAttemptedAt: completedAt,
    );
  }

  PuzzleProgressEntry recordFailure(DateTime completedAt) {
    return copyWith(
      attempts: attempts + 1,
      failedCount: failedCount + 1,
      lastAttemptedAt: completedAt,
    );
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}

class PuzzleProgressSnapshot {
  const PuzzleProgressSnapshot({
    required this.entries,
  });

  factory PuzzleProgressSnapshot.empty() {
    return const PuzzleProgressSnapshot(
        entries: <String, PuzzleProgressEntry>{});
  }

  final Map<String, PuzzleProgressEntry> entries;

  PuzzleProgressEntry entryFor(String puzzleId) {
    return entries[puzzleId] ?? PuzzleProgressEntry.empty(puzzleId);
  }

  Set<String> get solvedPuzzleIds {
    return entries.values
        .where((entry) => entry.isSolved)
        .map((entry) => entry.puzzleId)
        .toSet();
  }

  int get solvedPuzzleCount {
    return entries.values.where((entry) => entry.isSolved).length;
  }

  int get totalAttempts {
    return entries.values.fold(0, (sum, entry) => sum + entry.attempts);
  }

  int get totalSolvedAttempts {
    return entries.values.fold(0, (sum, entry) => sum + entry.solvedCount);
  }

  int get totalFailedAttempts {
    return entries.values.fold(0, (sum, entry) => sum + entry.failedCount);
  }

  double get successRate {
    if (totalAttempts <= 0) {
      return 0;
    }
    return totalSolvedAttempts / totalAttempts;
  }
}
