import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/community_config.dart';
import '../models/community_puzzle.dart';
import '../models/puzzle_objective.dart';

class CommunityPuzzleException implements Exception {
  const CommunityPuzzleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CommunityPuzzleService {
  CommunityPuzzleService({SupabaseClient? client}) : _overrideClient = client;

  final SupabaseClient? _overrideClient;

  SupabaseClient get _client => _overrideClient ?? Supabase.instance.client;

  static const _selectColumns = '''
    id,
    author_id,
    title,
    description,
    fen,
    solution,
    mate_in,
    to_move,
    objective_type,
    objective,
    like_count,
    import_count,
    report_count,
    created_at,
    author:profiles!community_puzzles_author_id_fkey(display_name, avatar_url)
  ''';

  static const _legacySelectColumns = '''
    id,
    author_id,
    title,
    description,
    fen,
    solution,
    mate_in,
    to_move,
    like_count,
    import_count,
    report_count,
    created_at,
    author:profiles!community_puzzles_author_id_fkey(display_name, avatar_url)
  ''';

  bool get isConfigured => CommunityConfig.canUseSupabase;

  Future<List<CommunityPuzzle>> fetchPuzzles({
    CommunityPuzzleSort sort = CommunityPuzzleSort.latest,
  }) async {
    _assertConfigured();

    final rows = await _fetchPublishedRows(sort: sort);
    final likedIds = await _likedPuzzleIds();
    return rows
        .map(
          (row) => CommunityPuzzle.fromJson(
            row,
            hasLiked: likedIds.contains(row['id']),
          ),
        )
        .toList();
  }

  Future<CommunityPuzzle> fetchPuzzle(String puzzleId) async {
    _assertConfigured();
    final response = await _selectPublishedPuzzle(
      puzzleId: puzzleId,
      columns: _selectColumns,
    ).onError<PostgrestException>((error, stackTrace) {
      if (!_isMissingObjectiveColumns(error)) {
        throw error;
      }
      return _selectPublishedPuzzle(
        puzzleId: puzzleId,
        columns: _legacySelectColumns,
      );
    });
    final likedIds = await _likedPuzzleIds();
    final row = Map<String, dynamic>.from(response);
    return CommunityPuzzle.fromJson(
      row,
      hasLiked: likedIds.contains(row['id']),
    );
  }

  Future<void> uploadPuzzle({
    required Map<String, dynamic> puzzle,
    required String description,
  }) async {
    _assertSignedIn();
    final user = _client.auth.currentUser!;
    final title = (puzzle['title'] as String? ?? '').trim();
    final solution = List<String>.from(puzzle['solution'] ?? const <String>[]);
    final objectivePuzzle =
        PuzzleObjective.normalizePuzzleMap(<String, dynamic>{
      ...puzzle,
      'solution': solution,
    });

    if (title.isEmpty) {
      throw const CommunityPuzzleException('제목을 입력해 주세요.');
    }
    if (description.trim().isEmpty) {
      throw const CommunityPuzzleException('한줄 설명을 입력해 주세요.');
    }
    if (solution.isEmpty) {
      throw const CommunityPuzzleException('정답 수순이 있는 문제만 올릴 수 있습니다.');
    }

    final payload = <String, dynamic>{
      'author_id': user.id,
      'title': title,
      'description': description.trim(),
      'fen': puzzle['fen'],
      'solution': solution,
      'mate_in': (puzzle['mateIn'] as num?)?.toInt() ?? 1,
      'to_move': puzzle['toMove'] == 'red' ? 'red' : 'blue',
      'objective_type': objectivePuzzle[PuzzleObjective.keyObjectiveType],
      'objective': objectivePuzzle[PuzzleObjective.keyObjective],
      'status': 'published',
    };

    try {
      await _client.from('community_puzzles').insert(payload);
    } on PostgrestException catch (error) {
      if (!_isMissingObjectiveColumns(error)) {
        rethrow;
      }
      final objectiveType =
          objectivePuzzle[PuzzleObjective.keyObjectiveType] as String;
      if (objectiveType != PuzzleObjective.mate) {
        throw const CommunityPuzzleException(
          '기물획득 문제를 올리려면 Supabase objective 마이그레이션이 필요합니다.',
        );
      }
      final legacyPayload = Map<String, dynamic>.from(payload)
        ..remove('objective_type')
        ..remove('objective');
      await _client.from('community_puzzles').insert(legacyPayload);
    }
  }

  Future<bool> toggleLike(String puzzleId) async {
    _assertSignedIn();
    final userId = _client.auth.currentUser!.id;
    final existing = await _client
        .from('community_puzzle_likes')
        .select('puzzle_id')
        .eq('puzzle_id', puzzleId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('community_puzzle_likes')
          .delete()
          .eq('puzzle_id', puzzleId)
          .eq('user_id', userId);
      return false;
    }

    await _client.from('community_puzzle_likes').insert(<String, dynamic>{
      'puzzle_id': puzzleId,
      'user_id': userId,
    });
    return true;
  }

  Future<void> markImported(String puzzleId) async {
    _assertSignedIn();
    final userId = _client.auth.currentUser!.id;
    final existing = await _client
        .from('community_puzzle_imports')
        .select('puzzle_id')
        .eq('puzzle_id', puzzleId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      return;
    }

    await _client.from('community_puzzle_imports').insert(<String, dynamic>{
      'puzzle_id': puzzleId,
      'user_id': userId,
    });
  }

  Future<void> reportPuzzle(String puzzleId) async {
    _assertSignedIn();
    final userId = _client.auth.currentUser!.id;
    final existing = await _client
        .from('community_puzzle_reports')
        .select('puzzle_id')
        .eq('puzzle_id', puzzleId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      throw const CommunityPuzzleException('이미 신고한 문제입니다.');
    }

    await _client.from('community_puzzle_reports').insert(<String, dynamic>{
      'puzzle_id': puzzleId,
      'user_id': userId,
    });
  }

  Future<Set<String>> _likedPuzzleIds() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return <String>{};
    }

    final response = await _client
        .from('community_puzzle_likes')
        .select('puzzle_id')
        .eq('user_id', user.id);
    return (response as List)
        .whereType<Map>()
        .map((row) => row['puzzle_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<Map<String, dynamic>>> _fetchPublishedRows({
    required CommunityPuzzleSort sort,
  }) async {
    try {
      return await _selectPublishedRows(
        sort: sort,
        columns: _selectColumns,
      );
    } on PostgrestException catch (error) {
      if (!_isMissingObjectiveColumns(error)) {
        rethrow;
      }
      return _selectPublishedRows(
        sort: sort,
        columns: _legacySelectColumns,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _selectPublishedRows({
    required CommunityPuzzleSort sort,
    required String columns,
  }) async {
    dynamic query = _client
        .from('community_puzzles')
        .select(columns)
        .eq('status', 'published');

    if (sort == CommunityPuzzleSort.likes) {
      query = query.order('like_count', ascending: false);
    }
    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> _selectPublishedPuzzle({
    required String puzzleId,
    required String columns,
  }) async {
    final response = await _client
        .from('community_puzzles')
        .select(columns)
        .eq('id', puzzleId)
        .eq('status', 'published')
        .single();
    return Map<String, dynamic>.from(response);
  }

  bool _isMissingObjectiveColumns(PostgrestException error) {
    return error.code == '42703' &&
        (error.message.contains('objective_type') ||
            error.message.contains('objective'));
  }

  void _assertConfigured() {
    if (!CommunityConfig.canUseSupabase) {
      throw const CommunityPuzzleException('Supabase 설정이 필요합니다.');
    }
  }

  void _assertSignedIn() {
    _assertConfigured();
    if (_client.auth.currentUser == null) {
      throw const CommunityPuzzleException('Google 로그인이 필요합니다.');
    }
  }
}
