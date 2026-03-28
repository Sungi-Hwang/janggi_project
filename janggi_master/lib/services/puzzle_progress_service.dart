import 'package:shared_preferences/shared_preferences.dart';

class PuzzleProgressService {
  static const String _solvedPuzzleIdsKey = 'solved_puzzle_ids';

  static Future<Set<String>> loadSolvedPuzzleIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_solvedPuzzleIdsKey) ?? const <String>[];
    return ids.toSet();
  }

  static Future<bool> isSolved(String puzzleId) async {
    final solvedIds = await loadSolvedPuzzleIds();
    return solvedIds.contains(puzzleId);
  }

  static Future<void> markSolved(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_solvedPuzzleIdsKey) ?? const <String>[];
    final solvedIds = ids.toSet()..add(puzzleId);
    await prefs.setStringList(
      _solvedPuzzleIdsKey,
      solvedIds.toList()..sort(),
    );
  }
}
