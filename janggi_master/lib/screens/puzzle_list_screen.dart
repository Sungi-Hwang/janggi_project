import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/custom_puzzle_service.dart';
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
      if (!mounted) return;
      setState(() {
        _puzzleData = data;
        _customPuzzles = custom;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading puzzle data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshCustomPuzzles() async {
    final custom = await CustomPuzzleService.loadPuzzles();
    if (!mounted) return;
    setState(() {
      _customPuzzles = custom;
    });
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
                        child: CircularProgressIndicator(color: Colors.white))
                    : _puzzleData == null
                        ? const Center(
                            child: Text(
                              '퍼즐 데이터를 불러오지 못했습니다.',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildCategoryCard(
                                title: '1수 외통',
                                subtitle: '한 수 만에 외통을 잡는 묘수',
                                icon: Icons.looks_one,
                                color: Colors.green,
                                count: _getPuzzlesByMateIn(1).length,
                                onTap: () => _showPuzzleList(
                                  mateIn: 1,
                                  title: '1수 외통',
                                  puzzles: _getPuzzlesByMateIn(1),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildCategoryCard(
                                title: '2수 외통',
                                subtitle: '두 수 만에 외통을 잡는 묘수',
                                icon: Icons.looks_two,
                                color: Colors.orange,
                                count: _getPuzzlesByMateIn(2).length,
                                onTap: () => _showPuzzleList(
                                  mateIn: 2,
                                  title: '2수 외통',
                                  puzzles: _getPuzzlesByMateIn(2),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildCategoryCard(
                                title: '3수 외통',
                                subtitle: '세 수 만에 외통을 잡는 묘수',
                                icon: Icons.looks_3,
                                color: Colors.red,
                                count: _getPuzzlesByMateIn(3).length,
                                onTap: () => _showPuzzleList(
                                  mateIn: 3,
                                  title: '3수 외통',
                                  puzzles: _getPuzzlesByMateIn(3),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildCategoryCard(
                                title: '나만의 묘수풀이',
                                subtitle: '직접 생성/관리하는 퍼즐',
                                icon: Icons.add_box_rounded,
                                color: Colors.indigo,
                                count: _customPuzzles.length,
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

  Widget _buildCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int count,
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
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count문제',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
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

  List<Map<String, dynamic>> _getPuzzlesByMateIn(int mateIn) {
    if (_puzzleData == null) return <Map<String, dynamic>>[];
    final puzzles = _puzzleData!['puzzles'] as List<dynamic>? ?? <dynamic>[];
    return puzzles
        .where((p) => p['mateIn'] == mateIn)
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
  }

  void _showPuzzleList({
    required int mateIn,
    required String title,
    required List<Map<String, dynamic>> puzzles,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzleCategoryScreen(
          title: title,
          mateIn: mateIn,
          puzzles: puzzles,
        ),
      ),
    );
  }

  Future<void> _openCustomCategory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomPuzzleCategoryScreen(),
      ),
    );
    _refreshCustomPuzzles();
  }
}

class PuzzleCategoryScreen extends StatelessWidget {
  final String title;
  final int mateIn;
  final List<Map<String, dynamic>> puzzles;

  const PuzzleCategoryScreen({
    super.key,
    required this.title,
    required this.mateIn,
    required this.puzzles,
  });

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
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${puzzles.length}문제',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: puzzles.length,
                  itemBuilder: (context, index) {
                    final puzzle = puzzles[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _colorForMate(mateIn).withValues(alpha: 0.2),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: _colorForMate(mateIn),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(puzzle['title'] ?? '묘수 ${index + 1}'),
                        subtitle: Text(
                          '${puzzle['toMove'] == 'blue' ? '초' : '한'}나라 차례',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        trailing: const Icon(Icons.play_arrow),
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

  void _startPuzzle(BuildContext context, Map<String, dynamic> puzzle) {
    final gameData = <String, dynamic>{
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzleGameScreen(game: gameData),
      ),
    );
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
    puzzles.sort((a, b) {
      final aTime = a['createdAt'] as String? ?? '';
      final bTime = b['createdAt'] as String? ?? '';
      return bTime.compareTo(aTime);
    });
    if (!mounted) return;
    setState(() {
      _puzzles = puzzles;
      _loading = false;
    });
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
                        '나만의 묘수풀이',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '${_puzzles.length}문제',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.white),
                      tooltip: '묘수 생성',
                      onPressed: _createPuzzle,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : _puzzles.isEmpty
                        ? const Center(
                            child: Text(
                              '아직 만든 퍼즐이 없습니다.\n우측 상단 + 버튼으로 생성하세요.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadPuzzles,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _puzzles.length,
                              itemBuilder: (context, index) {
                                final puzzle = _puzzles[index];
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
                                    title: Text(puzzle['title'] ?? '나만의 묘수'),
                                    subtitle: Text(
                                      '${puzzle['mateIn'] ?? 1}수 외통 · ${puzzle['toMove'] == 'blue' ? '초' : '한'}나라 차례',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
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
        content: Text('"${puzzle['title'] ?? '이 퍼즐'}" 을(를) 삭제할까요?'),
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

  void _startPuzzle(BuildContext context, Map<String, dynamic> puzzle) {
    final gameData = <String, dynamic>{
      'title': puzzle['title'],
      'fen': puzzle['fen'],
      'solution': List<String>.from(puzzle['solution'] ?? <String>[]),
      'mateIn': puzzle['mateIn'] ?? 1,
      'toMove': puzzle['toMove'] ?? 'blue',
      'source': puzzle['source'] ?? 'custom',
      'moves': <String>[],
      'startMove': 0,
      'totalMoves': puzzle['mateIn'] as int? ?? 1,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzleGameScreen(game: gameData),
      ),
    );
  }
}
