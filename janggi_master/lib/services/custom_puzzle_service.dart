import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CustomPuzzleService {
  static const String _keyCustomPuzzles = 'custom_puzzles_v1';

  static Future<List<Map<String, dynamic>>> loadPuzzles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCustomPuzzles);
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> savePuzzles(List<Map<String, dynamic>> puzzles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomPuzzles, json.encode(puzzles));
  }

  static Future<void> addPuzzle(Map<String, dynamic> puzzle) async {
    final puzzles = await loadPuzzles();
    puzzles.add(puzzle);
    await savePuzzles(puzzles);
  }

  static Future<void> deletePuzzle(String id) async {
    final puzzles = await loadPuzzles();
    puzzles.removeWhere((p) => p['id'] == id);
    await savePuzzles(puzzles);
  }

  static String nextId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'custom_$timestamp';
  }
}
