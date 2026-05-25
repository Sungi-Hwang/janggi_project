import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/community_config.dart';
import '../utils/generated_puzzle_quality_guard.dart';

class RandomPuzzleService {
  static const int _cacheTarget = 2;
  static const int _recentLimit = 80;
  static const String _recentIdsKey = 'generated_puzzle_recent_ids_v1';
  static const String _statsKey = 'generated_puzzle_stats_v1';
  static const String _feedbackKey = 'generated_puzzle_feedback_v1';

  static final Random _random = Random();
  static final List<RandomPuzzleSelection> _cache = <RandomPuzzleSelection>[];
  static Future<void>? _fillFuture;
  static List<Map<String, dynamic>>? _remoteCandidates;
  static DateTime? _remoteLoadedAt;

  static Future<RandomPuzzleSelection> generate() async {
    if (_cache.isNotEmpty) {
      final selection = _cache.removeAt(0);
      await _markSeen(selection.puzzle);
      warmUp();
      return selection;
    }

    if (_fillFuture != null) {
      await _fillFuture;
      if (_cache.isNotEmpty) {
        final selection = _cache.removeAt(0);
        await _markSeen(selection.puzzle);
        warmUp();
        return selection;
      }
    }

    final selection = await _selectFresh();
    await _markSeen(selection.puzzle);
    warmUp();
    return selection;
  }

  static void warmUp() {
    if (_fillFuture != null || _cache.length >= _cacheTarget) return;
    _fillFuture = _fillCache();
  }

  static Future<void> recordAttempt({
    required String puzzleId,
    required bool solved,
    int attempts = 1,
    bool hintUsed = false,
    DateTime? completedAt,
  }) async {
    if (puzzleId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await _updateLocalStats(prefs, completedAt ?? DateTime.now());

    if (!CommunityConfig.canUseSupabase) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client.from('generated_puzzle_attempts').insert(<String, dynamic>{
        'user_id': user.id,
        'puzzle_id': puzzleId,
        'solved': solved,
        'attempts': attempts < 1 ? 1 : attempts,
        'hint_used': hintUsed,
        'completed_at': (completedAt ?? DateTime.now()).toIso8601String(),
      });
    } catch (_) {
      // Local progress has already been recorded; remote sync can fail silently.
    }
  }

  static Future<int?> feedbackFor(String puzzleId) async {
    if (puzzleId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final local = _decodeFeedback(prefs.getString(_feedbackKey));
    final localVote = (local[puzzleId] as num?)?.toInt();
    if (localVote == 1 || localVote == -1) return localVote;

    if (!CommunityConfig.canUseSupabase) return null;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await client
          .from('generated_puzzle_feedback')
          .select('vote')
          .eq('user_id', user.id)
          .eq('puzzle_id', puzzleId)
          .maybeSingle();
      final vote = (row?['vote'] as num?)?.toInt();
      if (vote == 1 || vote == -1) {
        final normalizedVote = vote!;
        await _setLocalFeedback(prefs, puzzleId, normalizedVote);
        return normalizedVote;
      }
    } catch (_) {
      // Feedback is optional; missing migrations or network issues are ignored.
    }
    return null;
  }

  static Future<void> recordFeedback({
    required String puzzleId,
    required int vote,
  }) async {
    if (puzzleId.isEmpty || (vote != 1 && vote != -1)) return;

    final prefs = await SharedPreferences.getInstance();
    await _setLocalFeedback(prefs, puzzleId, vote);

    if (!CommunityConfig.canUseSupabase) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client.from('generated_puzzle_feedback').upsert(
        <String, dynamic>{
          'user_id': user.id,
          'puzzle_id': puzzleId,
          'vote': vote,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,puzzle_id',
      );
    } catch (_) {
      // Local feedback remains available when remote sync cannot complete.
    }
  }

  static Future<void> _fillCache() async {
    try {
      while (_cache.length < _cacheTarget) {
        final selection = await _selectFresh(
          excludeIds: _cache
              .map((selection) => selection.puzzle['id'])
              .whereType<String>()
              .toSet(),
        );
        _cache.add(selection);
      }
    } catch (_) {
      // A foreground request can still use the bundled fallback.
    } finally {
      _fillFuture = null;
    }
  }

  static Future<RandomPuzzleSelection> _selectFresh({
    Set<String> excludeIds = const <String>{},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final recentIds = prefs.getStringList(_recentIdsKey) ?? const <String>[];
    final excluded = <String>{...recentIds, ...excludeIds};

    final candidates = await _loadCandidates();
    final unseen = candidates.where((puzzle) {
      final id = puzzle['id'] as String?;
      return id != null && !excluded.contains(id);
    }).toList(growable: false);
    final pool = unseen.isNotEmpty ? unseen : candidates;
    if (pool.isEmpty) {
      throw const RandomPuzzleException('표시할 묘수를 찾지 못했습니다.');
    }

    return RandomPuzzleSelection(
      puzzle: Map<String, dynamic>.from(
        pool[_random.nextInt(pool.length)],
      ),
      attemptCount: _todayCountFromPrefs(prefs) + 1,
      threeMoveChancePercent: 100,
    );
  }

  static Future<List<Map<String, dynamic>>> _loadCandidates() async {
    final remote = await _loadRemoteCandidates();
    if (remote.isNotEmpty) return remote;
    return _loadBundledFallback();
  }

  static Future<List<Map<String, dynamic>>> _loadRemoteCandidates() async {
    if (!CommunityConfig.canUseSupabase) {
      return const <Map<String, dynamic>>[];
    }
    final loadedAt = _remoteLoadedAt;
    final cached = _remoteCandidates;
    if (loadedAt != null &&
        cached != null &&
        DateTime.now().difference(loadedAt) < const Duration(minutes: 5)) {
      return cached;
    }

    try {
      final response = await Supabase.instance.client
          .from('generated_puzzles')
          .select(
            'id,title,fen,solution,mate_in,to_move,source,quality_score,created_at,published_at',
          )
          .eq('status', 'published')
          .eq('mate_in', 3)
          .order('published_at', ascending: false)
          .limit(120);
      final rows = (response as List)
          .whereType<Map>()
          .map((row) => _normalizePuzzleRow(Map<String, dynamic>.from(row)))
          .where(_isPlayableGeneratedPuzzle)
          .toList(growable: false);
      _remoteCandidates = rows;
      _remoteLoadedAt = DateTime.now();
      return rows;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  static Future<List<Map<String, dynamic>>> _loadBundledFallback() async {
    final raw = await rootBundle.loadString('assets/puzzles/puzzles.json');
    final decoded = json.decode(raw);
    if (decoded is! Map || decoded['puzzles'] is! List) {
      return const <Map<String, dynamic>>[];
    }

    return (decoded['puzzles'] as List)
        .whereType<Map>()
        .map((rawPuzzle) {
          final puzzle = Map<String, dynamic>.from(rawPuzzle);
          return <String, dynamic>{
            ...puzzle,
            'id': 'fallback_${puzzle['id']}',
            'title': '예비 생성 묘수',
            'source': 'bundled_generated_fallback',
            'feedType': 'generated',
          };
        })
        .where(_isPlayableGeneratedPuzzle)
        .toList(growable: false);
  }

  static Map<String, dynamic> _normalizePuzzleRow(Map<String, dynamic> row) {
    final mateIn = (row['mate_in'] as num?)?.toInt() ??
        (row['mateIn'] as num?)?.toInt() ??
        0;
    return <String, dynamic>{
      'id': row['id']?.toString(),
      'title': (row['title'] as String?)?.trim().isNotEmpty == true
          ? row['title']
          : '생성 묘수',
      'fen': row['fen'],
      'solution': row['solution'] is List
          ? List<String>.from(row['solution'] as List)
          : const <String>[],
      'mateIn': mateIn,
      'difficulty': mateIn,
      'toMove': row['to_move'] ?? row['toMove'] ?? _sideFromFen(row['fen']),
      'source': row['source'] ?? 'generated_selfplay_feed',
      'qualityScore': (row['quality_score'] as num?)?.toDouble() ?? 0.0,
      'publishedAt': row['published_at'],
      'feedType': 'generated',
    };
  }

  static bool _isPlayableGeneratedPuzzle(Map<String, dynamic> puzzle) {
    final mateIn = (puzzle['mateIn'] as num?)?.toInt();
    if (mateIn == null || mateIn != 3) return false;
    final requiredLength = mateIn * 2 - 1;
    final fen = puzzle['fen'];
    if (fen is! String || fen.trim().isEmpty) return false;
    final solution = puzzle['solution'];
    if (solution is! List) return false;
    if (solution.length != requiredLength) return false;
    return !GeneratedPuzzleQualityGuard.hasImmediateGeneralCapture(
      fen: fen,
      toMove: puzzle['toMove'] as String?,
    );
  }

  static Future<void> _markSeen(Map<String, dynamic> puzzle) async {
    final id = puzzle['id'] as String?;
    if (id == null || id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final recent = <String>[
      id,
      ...prefs.getStringList(_recentIdsKey) ?? const <String>[],
    ];
    final deduped = <String>[];
    for (final item in recent) {
      if (!deduped.contains(item)) deduped.add(item);
      if (deduped.length >= _recentLimit) break;
    }
    await prefs.setStringList(_recentIdsKey, deduped);
    await _updateLocalStats(prefs, DateTime.now(), countSeen: true);
  }

  static Future<void> _updateLocalStats(
    SharedPreferences prefs,
    DateTime at, {
    bool countSeen = false,
  }) async {
    final today = _dateKey(at);
    final decoded = _decodeStats(prefs.getString(_statsKey));
    final previousDate = decoded['date'] as String?;
    final yesterday = _dateKey(at.subtract(const Duration(days: 1)));
    var streak = (decoded['streak'] as num?)?.toInt() ?? 0;
    var todayCount = (decoded['todayCount'] as num?)?.toInt() ?? 0;

    if (previousDate != today) {
      streak = previousDate == yesterday ? streak + 1 : 1;
      todayCount = 0;
    }
    if (countSeen) {
      todayCount++;
    }

    await prefs.setString(
      _statsKey,
      json.encode(<String, dynamic>{
        'date': today,
        'todayCount': todayCount,
        'streak': streak,
      }),
    );
  }

  static int _todayCountFromPrefs(SharedPreferences prefs) {
    final decoded = _decodeStats(prefs.getString(_statsKey));
    if (decoded['date'] != _dateKey(DateTime.now())) return 0;
    return (decoded['todayCount'] as num?)?.toInt() ?? 0;
  }

  static Map<String, dynamic> _decodeStats(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = json.decode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Map<String, dynamic> _decodeFeedback(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = json.decode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _setLocalFeedback(
    SharedPreferences prefs,
    String puzzleId,
    int vote,
  ) async {
    final decoded = _decodeFeedback(prefs.getString(_feedbackKey));
    decoded[puzzleId] = vote;
    await prefs.setString(_feedbackKey, json.encode(decoded));
  }

  static String _dateKey(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static String _sideFromFen(Object? fen) {
    if (fen is! String) return 'blue';
    final parts = fen.split(RegExp(r'\s+'));
    return parts.length > 1 && parts[1] == 'b' ? 'red' : 'blue';
  }
}

class RandomPuzzleSelection {
  const RandomPuzzleSelection({
    required this.puzzle,
    required this.attemptCount,
    required this.threeMoveChancePercent,
  });

  final Map<String, dynamic> puzzle;
  final int attemptCount;
  final int threeMoveChancePercent;
}

class RandomPuzzleException implements Exception {
  const RandomPuzzleException(this.message);

  final String message;

  @override
  String toString() => message;
}
