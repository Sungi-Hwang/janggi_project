import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle_progress.dart';

class PuzzleProgressService {
  static const String _legacySolvedPuzzleIdsKey = 'solved_puzzle_ids';
  static const String _puzzleProgressKey = 'puzzle_progress_v2';

  static Future<PuzzleProgressSnapshot> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _loadEntries(prefs);
    return PuzzleProgressSnapshot(entries: entries);
  }

  static Future<Map<String, PuzzleProgressEntry>> loadProgressMap() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadEntries(prefs);
  }

  static Future<PuzzleProgressEntry> loadProgress(String puzzleId) async {
    final entries = await loadProgressMap();
    return entries[puzzleId] ?? PuzzleProgressEntry.empty(puzzleId);
  }

  static Future<Set<String>> loadSolvedPuzzleIds() async {
    final snapshot = await loadSnapshot();
    return snapshot.solvedPuzzleIds;
  }

  static Future<bool> isSolved(String puzzleId) async {
    final progress = await loadProgress(puzzleId);
    return progress.isSolved;
  }

  static Future<void> markSolved(String puzzleId) async {
    await recordSolvedAttempt(puzzleId);
  }

  static Future<void> recordSolvedAttempt(
    String puzzleId, {
    DateTime? completedAt,
  }) async {
    if (puzzleId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final entries = await _loadEntries(prefs);
    final current = entries[puzzleId] ?? PuzzleProgressEntry.empty(puzzleId);
    entries[puzzleId] = current.recordSolved(completedAt ?? DateTime.now());
    await _saveEntries(prefs, entries);
  }

  static Future<void> recordFailedAttempt(
    String puzzleId, {
    DateTime? completedAt,
  }) async {
    if (puzzleId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final entries = await _loadEntries(prefs);
    final current = entries[puzzleId] ?? PuzzleProgressEntry.empty(puzzleId);
    entries[puzzleId] = current.recordFailure(completedAt ?? DateTime.now());
    await _saveEntries(prefs, entries);
  }

  static Future<Map<String, PuzzleProgressEntry>> _loadEntries(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_puzzleProgressKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) {
          final entries = <String, PuzzleProgressEntry>{};
          for (final entry in decoded.entries) {
            final key = entry.key;
            final value = entry.value;
            if (key is! String || value is! Map) {
              continue;
            }
            entries[key] = PuzzleProgressEntry.fromJson(
              key,
              Map<String, dynamic>.from(value),
            );
          }

          final merged = _mergeLegacySolvedEntries(
            prefs,
            currentEntries: entries,
          );
          if (merged.length != entries.length) {
            await _saveEntries(prefs, merged);
            return merged;
          }
          return merged;
        }
      } catch (_) {
        // Fall back to legacy solved IDs if the stored progress payload is
        // corrupted or from an older incompatible format.
      }
    }

    final migrated = _migrateLegacySolvedIds(prefs);
    if (migrated.isNotEmpty) {
      await _saveEntries(prefs, migrated);
    }
    return migrated;
  }

  static Map<String, PuzzleProgressEntry> _migrateLegacySolvedIds(
    SharedPreferences prefs,
  ) {
    final legacyIds =
        prefs.getStringList(_legacySolvedPuzzleIdsKey) ?? const <String>[];
    return <String, PuzzleProgressEntry>{
      for (final id in legacyIds)
        id: PuzzleProgressEntry(
          puzzleId: id,
          attempts: 1,
          solvedCount: 1,
        ),
    };
  }

  static Map<String, PuzzleProgressEntry> _mergeLegacySolvedEntries(
    SharedPreferences prefs, {
    required Map<String, PuzzleProgressEntry> currentEntries,
  }) {
    final merged = <String, PuzzleProgressEntry>{
      ...currentEntries,
    };
    final legacyIds =
        prefs.getStringList(_legacySolvedPuzzleIdsKey) ?? const <String>[];
    for (final id in legacyIds) {
      merged.putIfAbsent(
        id,
        () => PuzzleProgressEntry(
          puzzleId: id,
          attempts: 1,
          solvedCount: 1,
        ),
      );
    }
    return merged;
  }

  static Future<void> _saveEntries(
    SharedPreferences prefs,
    Map<String, PuzzleProgressEntry> entries,
  ) async {
    final encoded = <String, dynamic>{
      for (final entry in entries.entries) entry.key: entry.value.toJson(),
    };
    await prefs.setString(_puzzleProgressKey, json.encode(encoded));
    final solvedIds = entries.values
        .where((entry) => entry.isSolved)
        .map((entry) => entry.puzzleId)
        .toList()
      ..sort();
    await prefs.setStringList(_legacySolvedPuzzleIdsKey, solvedIds);
  }
}
