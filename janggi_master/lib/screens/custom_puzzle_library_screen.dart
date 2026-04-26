import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/puzzle_progress.dart';
import '../services/custom_puzzle_service.dart';
import '../services/puzzle_progress_service.dart';
import '../utils/puzzle_share_codec.dart';
import 'custom_puzzle_editor_screen.dart';
import 'puzzle_game_screen.dart';

class CustomPuzzleLibraryScreen extends StatefulWidget {
  const CustomPuzzleLibraryScreen({super.key});

  @override
  State<CustomPuzzleLibraryScreen> createState() =>
      _CustomPuzzleLibraryScreenState();
}

class _CustomPuzzleLibraryScreenState extends State<CustomPuzzleLibraryScreen> {
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

    final puzzles = await CustomPuzzleService.loadCreatedPuzzles();
    final progress = await PuzzleProgressService.loadSnapshot();

    if (!mounted) return;
    setState(() {
      _puzzles = puzzles;
      _progress = progress;
      _loading = false;
    });
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
    final id = puzzle['id'] as String? ?? '';
    if (id.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('문제 삭제'),
        content: Text('"${puzzle['title'] ?? '이 문제'}"를 삭제할까요?'),
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

    if (shouldDelete != true) return;
    await CustomPuzzleService.deletePuzzle(id);
    _loadPuzzles();
  }

  Future<void> _copyShareCode(Map<String, dynamic> puzzle) async {
    try {
      final code = PuzzleShareCodec.encodePuzzle(puzzle);
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 코드를 복사했습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 코드를 생성하지 못했습니다.')),
      );
    }
  }

  Future<void> _startPuzzle(Map<String, dynamic> puzzle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzleGameScreen(
          game: <String, dynamic>{
            'id': puzzle['id'],
            'title': puzzle['title'],
            'fen': puzzle['fen'],
            'solution':
                List<String>.from(puzzle['solution'] ?? const <String>[]),
            'mateIn': (puzzle['mateIn'] as num?)?.toInt() ?? 1,
            'toMove': puzzle['toMove'] ?? 'blue',
            'source': puzzle['source'] ?? 'custom',
            'moves': <String>[],
            'startMove': 0,
            'totalMoves': (puzzle['mateIn'] as num?)?.toInt() ?? 1,
          },
        ),
      ),
    );
    _loadPuzzles();
  }

  String _puzzleIdOf(Map<String, dynamic> puzzle) {
    return puzzle['id'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final solvedCount = _puzzles
        .where((puzzle) => _progress.entryFor(_puzzleIdOf(puzzle)).isSolved)
        .length;

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
                        '내가 만든 문제',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '$solvedCount/${_puzzles.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.white),
                      tooltip: '문제 생성',
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
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '아직 만든 문제가 없습니다.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '오른쪽 위의 추가 버튼으로 새 문제를 만들어 보세요.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                                final mateIn =
                                    (puzzle['mateIn'] as num?)?.toInt() ?? 1;
                                final toMove = puzzle['toMove'] == 'red'
                                    ? '한 차례'
                                    : '초 차례';

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
                                    title:
                                        Text(puzzle['title'] as String? ?? '내 문제'),
                                    subtitle: Text(
                                      '$mateIn수 문제 · $toMove'
                                      '${progress.attempts > 0 ? ' · 해결 ${progress.solvedCount}회 / 시도 ${progress.attempts}회' : ' · 아직 도전 전'}',
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
                                          tooltip: '공유 코드 복사',
                                          onPressed: () =>
                                              _copyShareCode(puzzle),
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          color: Colors.red,
                                          tooltip: '삭제',
                                          onPressed: () =>
                                              _deletePuzzle(puzzle),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.play_arrow),
                                          tooltip: '플레이',
                                          onPressed: () =>
                                              _startPuzzle(puzzle),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _startPuzzle(puzzle),
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
}
