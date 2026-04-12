import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/puzzle_progress.dart';
import '../services/custom_puzzle_service.dart';
import '../services/puzzle_progress_service.dart';
import '../utils/puzzle_share_codec.dart';
import 'custom_puzzle_editor_screen.dart';
import 'puzzle_game_screen.dart';

class PuzzleListScreen extends StatefulWidget {
  const PuzzleListScreen({super.key});

  @override
  State<PuzzleListScreen> createState() => _PuzzleListScreenState();
}

class _PuzzleListScreenState extends State<PuzzleListScreen> {
  Map<String, dynamic>? _puzzleData;
  List<Map<String, dynamic>> _customPuzzles = <Map<String, dynamic>>[];
  PuzzleProgressSnapshot _progress = PuzzleProgressSnapshot.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final jsonString =
          await rootBundle.loadString('assets/puzzles/puzzles.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final custom = await CustomPuzzleService.loadPuzzles();
      final progress = await PuzzleProgressService.loadSnapshot();

      if (!mounted) return;
      setState(() {
        _puzzleData = data;
        _customPuzzles = custom;
        _progress = progress;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading puzzle data: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getPuzzlesByMateIn(int mateIn) {
    if (_puzzleData == null) {
      return <Map<String, dynamic>>[];
    }

    final puzzles = _puzzleData!['puzzles'] as List<dynamic>? ?? <dynamic>[];
    return puzzles
        .where((puzzle) => puzzle['mateIn'] == mateIn)
        .map((puzzle) => Map<String, dynamic>.from(puzzle as Map))
        .toList();
  }

  int _getSolvedCount(List<Map<String, dynamic>> puzzles) {
    return puzzles
        .where((puzzle) => _progress.entryFor(_puzzleIdOf(puzzle)).isSolved)
        .length;
  }

  int _getAttemptCount(List<Map<String, dynamic>> puzzles) {
    return puzzles.fold(
      0,
      (sum, puzzle) => sum + _progress.entryFor(_puzzleIdOf(puzzle)).attempts,
    );
  }

  String _puzzleIdOf(Map<String, dynamic> puzzle) {
    return puzzle['id'] as String? ?? '';
  }

  Future<void> _showPuzzleList({
    required int mateIn,
    required String title,
    required List<Map<String, dynamic>> puzzles,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzleCategoryScreen(
          title: title,
          mateIn: mateIn,
          puzzles: puzzles,
        ),
      ),
    );
    _loadData();
  }

  Future<void> _openCustomCategory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomPuzzleCategoryScreen(),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final mate1 = _getPuzzlesByMateIn(1);
    final mate2 = _getPuzzlesByMateIn(2);
    final mate3 = _getPuzzlesByMateIn(3);
    final totalBuiltinCount = mate1.length + mate2.length + mate3.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '묘수풀이',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _puzzleData == null
                        ? const Center(
                            child: Text(
                              '퍼즐 데이터를 불러오지 못했습니다.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildProgressSummaryCard(
                                totalBuiltinCount: totalBuiltinCount,
                              ),
                              const SizedBox(height: 12),
                              _buildCategoryCard(
                                title: '1수 외통',
                                subtitle: '한 수 안에 탈출수를 막는 퍼즐',
                                icon: Icons.looks_one,
                                color: Colors.green,
                                count: mate1.length,
                                solvedCount: _getSolvedCount(mate1),
                                attemptCount: _getAttemptCount(mate1),
                                onTap: () => _showPuzzleList(
                                  mateIn: 1,
                                  title: '1수 외통',
                                  puzzles: mate1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildCategoryCard(
                                title: '2수 외통',
                                subtitle: '두 수 안에 탈출수를 막는 퍼즐',
                                icon: Icons.looks_two,
                                color: Colors.orange,
                                count: mate2.length,
                                solvedCount: _getSolvedCount(mate2),
                                attemptCount: _getAttemptCount(mate2),
                                onTap: () => _showPuzzleList(
                                  mateIn: 2,
                                  title: '2수 외통',
                                  puzzles: mate2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildCategoryCard(
                                title: '3수 외통',
                                subtitle: '세 수 안에 탈출수를 막는 퍼즐',
                                icon: Icons.looks_3,
                                color: Colors.red,
                                count: mate3.length,
                                solvedCount: _getSolvedCount(mate3),
                                attemptCount: _getAttemptCount(mate3),
                                onTap: () => _showPuzzleList(
                                  mateIn: 3,
                                  title: '3수 외통',
                                  puzzles: mate3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildCategoryCard(
                                title: '나만의 퍼즐',
                                subtitle: '직접 만든 퍼즐을 이어서 풀고 관리',
                                icon: Icons.add_box_rounded,
                                color: Colors.indigo,
                                count: _customPuzzles.length,
                                solvedCount: _getSolvedCount(_customPuzzles),
                                attemptCount: _getAttemptCount(_customPuzzles),
                                onTap: _openCustomCategory,
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSummaryCard({
    required int totalBuiltinCount,
  }) {
    final solvedCount = _progress.entries.values
        .where(
            (entry) => entry.isSolved && !entry.puzzleId.startsWith('custom_'))
        .length;
    final successRate = (_progress.successRate * 100).toStringAsFixed(0);

    return Card(
      elevation: 4,
      color: Colors.white.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '진행 요약',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    label: '해결한 퍼즐',
                    value: '$solvedCount / $totalBuiltinCount',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    label: '총 시도',
                    value: '${_progress.totalAttempts}',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    label: '성공률',
                    value: '$successRate%',
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int count,
    required int solvedCount,
    required int attemptCount,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '시도 $attemptCount회',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$solvedCount/$count',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

class PuzzleCategoryScreen extends StatefulWidget {
  const PuzzleCategoryScreen({
    super.key,
    required this.title,
    required this.mateIn,
    required this.puzzles,
  });

  final String title;
  final int mateIn;
  final List<Map<String, dynamic>> puzzles;

  @override
  State<PuzzleCategoryScreen> createState() => _PuzzleCategoryScreenState();
}

class _PuzzleCategoryScreenState extends State<PuzzleCategoryScreen> {
  PuzzleProgressSnapshot _progress = PuzzleProgressSnapshot.empty();

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress = await PuzzleProgressService.loadSnapshot();
    if (!mounted) return;
    setState(() {
      _progress = progress;
    });
  }

  int get _solvedCount => widget.puzzles
      .where((puzzle) => _progress.entryFor(_puzzleIdOf(puzzle)).isSolved)
      .length;

  String _puzzleIdOf(Map<String, dynamic> puzzle) {
    return puzzle['id'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black.withValues(alpha: 0.7),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$_solvedCount/${widget.puzzles.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.puzzles.length,
                  itemBuilder: (context, index) {
                    final puzzle = widget.puzzles[index];
                    final progress = _progress.entryFor(_puzzleIdOf(puzzle));
                    final isSolved = progress.isSolved;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _colorForMate(widget.mateIn)
                              .withValues(alpha: 0.2),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: _colorForMate(widget.mateIn),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(puzzle['title'] ?? '퍼즐 ${index + 1}'),
                        subtitle: Text(
                          _buildPuzzleSubtitle(
                            toMove: puzzle['toMove'] as String?,
                            progress: progress,
                          ),
                        ),
                        trailing: Icon(
                          isSolved ? Icons.check_circle : Icons.play_arrow,
                          color: isSolved ? Colors.green : null,
                        ),
                        onTap: () => _startPuzzle(context, puzzle),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildPuzzleSubtitle({
    required String? toMove,
    required PuzzleProgressEntry progress,
  }) {
    final side = (toMove ?? 'blue') == 'blue' ? '초 선 차례' : '한 선 차례';
    if (progress.attempts == 0) {
      return '$side · 아직 미도전';
    }
    return '$side · 해결 ${progress.solvedCount}회 · 시도 ${progress.attempts}회';
  }

  Color _colorForMate(int value) {
    switch (value) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.purple;
    }
  }

  Future<void> _startPuzzle(
    BuildContext context,
    Map<String, dynamic> puzzle,
  ) async {
    final gameData = <String, dynamic>{
      'id': puzzle['id'],
      'title': puzzle['title'],
      'fen': puzzle['fen'],
      'solution': puzzle['solution'],
      'mateIn': puzzle['mateIn'],
      'toMove': puzzle['toMove'],
      'source': puzzle['source'],
      'moves': <String>[],
      'startMove': 0,
      'totalMoves': puzzle['mateIn'] as int? ?? 1,
    };

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzleGameScreen(game: gameData),
      ),
    );
    _loadProgress();
  }
}

class CustomPuzzleCategoryScreen extends StatefulWidget {
  const CustomPuzzleCategoryScreen({super.key});

  @override
  State<CustomPuzzleCategoryScreen> createState() =>
      _CustomPuzzleCategoryScreenState();
}

class _CustomPuzzleCategoryScreenState
    extends State<CustomPuzzleCategoryScreen> {
  List<Map<String, dynamic>> _puzzles = <Map<String, dynamic>>[];
  PuzzleProgressSnapshot _progress = PuzzleProgressSnapshot.empty();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPuzzles();
  }

  Future<void> _loadPuzzles() async {
    setState(() {
      _loading = true;
    });

    final puzzles = await CustomPuzzleService.loadPuzzles();
    final progress = await PuzzleProgressService.loadSnapshot();
    puzzles.sort((a, b) {
      final aTime = a['createdAt'] as String? ?? '';
      final bTime = b['createdAt'] as String? ?? '';
      return bTime.compareTo(aTime);
    });

    if (!mounted) return;
    setState(() {
      _puzzles = puzzles;
      _progress = progress;
      _loading = false;
    });
  }

  int get _solvedCount => _puzzles
      .where((puzzle) => _progress.entryFor(_puzzleIdOf(puzzle)).isSolved)
      .length;

  String _puzzleIdOf(Map<String, dynamic> puzzle) {
    return puzzle['id'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black.withValues(alpha: 0.7),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '나만의 퍼즐',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '$_solvedCount/${_puzzles.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.white),
                      tooltip: '퍼즐 생성',
                      onPressed: _createPuzzle,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _puzzles.isEmpty
                        ? const Center(
                            child: Text(
                              '아직 만든 퍼즐이 없습니다.\n오른쪽 상단 + 버튼으로 만들어보세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadPuzzles,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _puzzles.length,
                              itemBuilder: (context, index) {
                                final puzzle = _puzzles[index];
                                final progress =
                                    _progress.entryFor(_puzzleIdOf(puzzle));
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          Colors.indigo.withValues(alpha: 0.15),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.indigo,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(puzzle['title'] ?? '나만의 퍼즐'),
                                    subtitle: Text(
                                      '${puzzle['mateIn'] ?? 1}수 외통 · '
                                      '${(puzzle['toMove'] ?? 'blue') == 'blue' ? '초 선 차례' : '한 선 차례'}'
                                      '${progress.attempts > 0 ? ' · 해결 ${progress.solvedCount}회 / 시도 ${progress.attempts}회' : ''}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (progress.isSolved)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            ),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.content_copy),
                                          color: Colors.indigo.shade400,
                                          tooltip: '공유 코드 복사',
                                          onPressed: () =>
                                              _copyShareCode(puzzle),
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          color: Colors.red.shade400,
                                          tooltip: '삭제',
                                          onPressed: () =>
                                              _deletePuzzle(puzzle),
                                        ),
                                        const Icon(Icons.play_arrow),
                                      ],
                                    ),
                                    onTap: () => _startPuzzle(context, puzzle),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createPuzzle() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomPuzzleEditorScreen(),
      ),
    );
    if (created == true) {
      _loadPuzzles();
    }
  }

  Future<void> _deletePuzzle(Map<String, dynamic> puzzle) async {
    final id = puzzle['id'] as String?;
    if (id == null || id.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('퍼즐 삭제'),
        content: Text('"${puzzle['title'] ?? '이 퍼즐'}"을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await CustomPuzzleService.deletePuzzle(id);
      _loadPuzzles();
    }
  }

  Future<void> _copyShareCode(Map<String, dynamic> puzzle) async {
    try {
      final code = PuzzleShareCodec.encodePuzzle(puzzle);
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 코드가 복사되었습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 코드 생성에 실패했습니다.')),
      );
    }
  }

  Future<void> _startPuzzle(
    BuildContext context,
    Map<String, dynamic> puzzle,
  ) async {
    final gameData = <String, dynamic>{
      'id': puzzle['id'],
      'title': puzzle['title'],
      'fen': puzzle['fen'],
      'solution': List<String>.from(puzzle['solution'] ?? const <String>[]),
      'mateIn': puzzle['mateIn'] ?? 1,
      'toMove': puzzle['toMove'] ?? 'blue',
      'source': puzzle['source'] ?? 'custom',
      'moves': <String>[],
      'startMove': 0,
      'totalMoves': puzzle['mateIn'] as int? ?? 1,
    };

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzleGameScreen(game: gameData),
      ),
    );
    _loadPuzzles();
  }
}
