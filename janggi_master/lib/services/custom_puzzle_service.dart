import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CustomPuzzleService {
  static const String _keyCustomPuzzles = 'custom_puzzles_v1';

  static const String libraryTypeCreated = 'created';
  static const String libraryTypeImported = 'imported';

  static const String importSourceShareCode = 'share_code';
  static const String importSourceCommunityPost = 'community_post';

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
          .map((entry) => _normalizePuzzle(Map<String, dynamic>.from(entry)))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<List<Map<String, dynamic>>> loadCreatedPuzzles() async {
    final puzzles = await loadPuzzles();
    return createdPuzzlesFrom(puzzles);
  }

  static Future<List<Map<String, dynamic>>> loadImportedPuzzles() async {
    final puzzles = await loadPuzzles();
    return importedPuzzlesFrom(puzzles);
  }

  static List<Map<String, dynamic>> createdPuzzlesFrom(
    List<Map<String, dynamic>> puzzles,
  ) {
    return _sortNewestFirst(
      puzzles.where((puzzle) => libraryTypeOf(puzzle) == libraryTypeCreated),
    );
  }

  static List<Map<String, dynamic>> importedPuzzlesFrom(
    List<Map<String, dynamic>> puzzles,
  ) {
    return _sortNewestFirst(
      puzzles.where((puzzle) => libraryTypeOf(puzzle) == libraryTypeImported),
    );
  }

  static String libraryTypeOf(Map<String, dynamic> puzzle) {
    return puzzle['libraryType'] == libraryTypeImported
        ? libraryTypeImported
        : libraryTypeCreated;
  }

  static Future<void> savePuzzles(List<Map<String, dynamic>> puzzles) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = puzzles.map(_normalizePuzzle).toList();
    await prefs.setString(_keyCustomPuzzles, json.encode(normalized));
  }

  static Future<void> addPuzzle(Map<String, dynamic> puzzle) async {
    final puzzles = await loadPuzzles();
    final normalized = _normalizePuzzle(puzzle);
    final id = normalized['id'] as String? ?? '';
    if (id.isNotEmpty) {
      puzzles.removeWhere((existing) => existing['id'] == id);
    }
    puzzles.add(normalized);
    await savePuzzles(puzzles);
  }

  static Future<void> addCreatedPuzzle(Map<String, dynamic> puzzle) async {
    final normalized = Map<String, dynamic>.from(puzzle);
    normalized['id'] = _normalizedId(
      normalized['id'] as String?,
      fallback: nextCreatedId,
    );
    normalized['libraryType'] = libraryTypeCreated;
    normalized['importSource'] = null;
    normalized['source'] = _normalizedSource(
      normalized['source'] as String?,
      fallback: 'custom',
    );
    normalized['createdAt'] = _normalizedCreatedAt(
      normalized['createdAt'] as String?,
    );
    await addPuzzle(normalized);
  }

  static Future<void> addImportedPuzzle(
    Map<String, dynamic> puzzle, {
    String importSource = importSourceShareCode,
  }) async {
    final normalized = Map<String, dynamic>.from(puzzle);
    normalized['id'] = _normalizedId(
      normalized['id'] as String?,
      fallback: nextImportedId,
    );
    normalized['libraryType'] = libraryTypeImported;
    normalized['importSource'] = _normalizeImportSource(importSource);
    normalized['source'] = _normalizedSource(
      normalized['source'] as String?,
      fallback: 'imported',
    );
    normalized['createdAt'] = _normalizedCreatedAt(
      normalized['createdAt'] as String?,
    );
    await addPuzzle(normalized);
  }

  static Future<void> deletePuzzle(String id) async {
    final puzzles = await loadPuzzles();
    puzzles.removeWhere((puzzle) => puzzle['id'] == id);
    await savePuzzles(puzzles);
  }

  static String nextCreatedId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'custom_$timestamp';
  }

  static String nextImportedId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'imported_$timestamp';
  }

  static Map<String, dynamic> _normalizePuzzle(Map<String, dynamic> puzzle) {
    final normalized = Map<String, dynamic>.from(puzzle);
    final libraryType = libraryTypeOf(normalized);

    final rawSolution = normalized['solution'];
    final solution = rawSolution is List
        ? rawSolution.map((move) => move.toString()).toList()
        : <String>[];
    final mateInFromPayload = (normalized['mateIn'] as num?)?.toInt();

    normalized['id'] = _normalizedId(normalized['id'] as String?);
    normalized['title'] = (normalized['title'] as String? ?? '').trim();
    normalized['fen'] = (normalized['fen'] as String? ?? '').trim();
    normalized['solution'] = solution;
    normalized['mateIn'] = mateInFromPayload ?? _resolveMateIn(solution);
    normalized['toMove'] =
        normalized['toMove'] == 'red' ? 'red' : 'blue';
    normalized['libraryType'] = libraryType;
    normalized['importSource'] = libraryType == libraryTypeImported
        ? _normalizeImportSource(normalized['importSource'] as String?)
        : null;
    normalized['source'] = _normalizedSource(
      normalized['source'] as String?,
      fallback: libraryType == libraryTypeImported ? 'imported' : 'custom',
    );
    normalized['createdAt'] = _normalizedCreatedAt(
      normalized['createdAt'] as String?,
    );

    return normalized;
  }

  static String _normalizedId(
    String? raw, {
    String Function()? fallback,
  }) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return fallback?.call() ?? '';
  }

  static String _normalizedSource(
    String? raw, {
    required String fallback,
  }) {
    final trimmed = raw?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : fallback;
  }

  static String? _normalizeImportSource(String? raw) {
    switch (raw) {
      case importSourceShareCode:
        return importSourceShareCode;
      case importSourceCommunityPost:
        return importSourceCommunityPost;
      default:
        return null;
    }
  }

  static String _normalizedCreatedAt(String? raw) {
    final trimmed = raw?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : DateTime.now().toIso8601String();
  }

  static int _resolveMateIn(List<String> solution) {
    final playerMoves = (solution.length + 1) ~/ 2;
    return playerMoves < 1 ? 1 : playerMoves;
  }

  static List<Map<String, dynamic>> _sortNewestFirst(
    Iterable<Map<String, dynamic>> puzzles,
  ) {
    final sorted = puzzles.map(_normalizePuzzle).toList();
    sorted.sort((a, b) {
      final aCreatedAt = a['createdAt'] as String? ?? '';
      final bCreatedAt = b['createdAt'] as String? ?? '';
      return bCreatedAt.compareTo(aCreatedAt);
    });
    return sorted;
  }
}
