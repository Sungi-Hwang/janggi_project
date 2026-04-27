import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/puzzle_progress.dart';
import '../models/puzzle_objective.dart';
import '../services/custom_puzzle_service.dart';
import '../services/puzzle_progress_service.dart';
import '../services/shared_puzzle_import_service.dart';
import '../utils/puzzle_share_codec.dart';
import 'custom_puzzle_library_screen.dart';
import 'puzzle_game_screen.dart';

class PuzzleListScreen extends StatefulWidget {
  const PuzzleListScreen({super.key});

  @override
  State<PuzzleListScreen> createState() => _PuzzleListScreenState();
}

class _PuzzleListScreenState extends State<PuzzleListScreen> {
  final TextEditingController _importController = TextEditingController();

  Map<String, dynamic>? _puzzleData;
  List<Map<String, dynamic>> _createdPuzzles = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _importedPuzzles = <Map<String, dynamic>>[];
  PuzzleProgressSnapshot _progress = PuzzleProgressSnapshot.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final jsonString =
          await rootBundle.loadString('assets/puzzles/puzzles.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final storedPuzzles = await CustomPuzzleService.loadPuzzles();
      final progress = await PuzzleProgressService.loadSnapshot();

      if (!mounted) return;
      setState(() {
        _puzzleData = data;
        _createdPuzzles = CustomPuzzleService.createdPuzzlesFrom(storedPuzzles);
        _importedPuzzles =
            CustomPuzzleService.importedPuzzlesFrom(storedPuzzles);
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

  List<Map<String, dynamic>> _builtinPuzzlesByMateIn(int mateIn) {
    final puzzles = _puzzleData?['puzzles'] as List<dynamic>? ?? <dynamic>[];
    return puzzles
        .where((puzzle) => puzzle is Map && puzzle['mateIn'] == mateIn)
        .map((puzzle) => Map<String, dynamic>.from(puzzle as Map))
        .toList();
  }

  _BuiltinProgressSummary _builtinProgressSummary() {
    final puzzles = _puzzleData?['puzzles'] as List<dynamic>? ?? <dynamic>[];
    final builtinIds = puzzles
        .whereType<Map>()
        .map((puzzle) => puzzle['id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final entries = builtinIds.map(_progress.entryFor).toList();
    final solvedCount = entries.where((entry) => entry.isSolved).length;
    final totalAttempts =
        entries.fold<int>(0, (sum, entry) => sum + entry.attempts);
    final totalSolvedAttempts =
        entries.fold<int>(0, (sum, entry) => sum + entry.solvedCount);
    final successRate =
        totalAttempts == 0 ? 0.0 : (totalSolvedAttempts / totalAttempts) * 100;

    return _BuiltinProgressSummary(
      totalPuzzleCount: builtinIds.length,
      solvedCount: solvedCount,
      totalAttempts: totalAttempts,
      successRatePercent: successRate,
    );
  }

  Future<void> _openCustomCategory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomPuzzleLibraryScreen(),
      ),
    );
    _loadData();
  }

  Future<void> _startPuzzle(Map<String, dynamic> puzzle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzleGameScreen(
          game: _gameDataFromPuzzle(puzzle),
        ),
      ),
    );
    _loadData();
  }

  Future<void> _importSharedPuzzle() async {
    String raw = _importController.text.trim();
    if (raw.isEmpty) {
      final clipboard = await Clipboard.getData('text/plain');
      raw = clipboard?.text?.trim() ?? '';
    }

    try {
      final decoded = SharedPuzzleImportService.decodeShareCode(raw);
      final puzzle = SharedPuzzleImportService.buildImportedPuzzle(decoded);
      await CustomPuzzleService.addImportedPuzzle(puzzle);
      _importController.clear();
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가져온 문제 탭에 저장했습니다.')),
      );
    } on SharedPuzzleImportException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
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
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final mate1 = _builtinPuzzlesByMateIn(1);
    final mate2 = _builtinPuzzlesByMateIn(2);
    final mate3 = _builtinPuzzlesByMateIn(3);
    final summary = _builtinProgressSummary();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
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
                _buildHeader(context),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _puzzleData == null
                          ? _buildLoadErrorState()
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _buildProgressSummaryCard(summary),
                                  const SizedBox(height: 12),
                                  _buildCustomLibraryCard(),
                                  const SizedBox(height: 12),
                                  _buildTabBar(),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        _buildBuiltinTab(
                                          puzzles: mate1,
                                          accentColor: Colors.green,
                                        ),
                                        _buildBuiltinTab(
                                          puzzles: mate2,
                                          accentColor: Colors.orange,
                                        ),
                                        _buildBuiltinTab(
                                          puzzles: mate3,
                                          accentColor: Colors.red,
                                        ),
                                        _buildImportedTab(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
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
            '문제풀이',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '문제 데이터를 불러오지 못했습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadData,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummaryCard(_BuiltinProgressSummary summary) {
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
                    label: '푼 문제',
                    value:
                        '${summary.solvedCount} / ${summary.totalPuzzleCount}',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    label: '총 시도',
                    value: '${summary.totalAttempts}',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    label: '성공률',
                    value: '${summary.successRatePercent.toStringAsFixed(0)}%',
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
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildCustomLibraryCard() {
    final solvedCount = _createdPuzzles
        .where((puzzle) => _progress.entryFor(_puzzleIdOf(puzzle)).isSolved)
        .length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            color: Colors.indigo,
            size: 28,
          ),
        ),
        title: const Text(
          '내가 만든 문제',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '직접 만든 문제를 관리하고 다시 플레이할 수 있습니다. $solvedCount/${_createdPuzzles.length}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openCustomCategory,
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        labelColor: Colors.brown.shade900,
        unselectedLabelColor: Colors.grey.shade700,
        indicatorColor: Colors.brown.shade700,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(child: _CompactTabLabel('1수')),
          Tab(child: _CompactTabLabel('2수')),
          Tab(child: _CompactTabLabel('3수')),
          Tab(child: _CompactTabLabel('가져온 문제')),
        ],
      ),
    );
  }

  Widget _buildBuiltinTab({
    required List<Map<String, dynamic>> puzzles,
    required Color accentColor,
  }) {
    if (puzzles.isEmpty) {
      return _buildEmptyCard(
        title: '등록된 문제가 없습니다.',
        subtitle: '다른 탭을 먼저 둘러보거나 잠시 후 다시 확인해 주세요.',
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: puzzles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final puzzle = puzzles[index];
          final progress = _progress.entryFor(_puzzleIdOf(puzzle));

          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: accentColor.withValues(alpha: 0.18),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: _PuzzleTitleWithBadge(
                title: puzzle['title'] as String? ?? '문제 ${index + 1}',
                puzzle: puzzle,
              ),
              subtitle: Text(
                _progressSubtitle(puzzle: puzzle, progress: progress),
              ),
              trailing: Icon(
                progress.isSolved ? Icons.check_circle : Icons.play_arrow,
                color: progress.isSolved ? Colors.green : accentColor,
              ),
              onTap: () => _startPuzzle(puzzle),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImportedTab() {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              margin: EdgeInsets.zero,
              color: Colors.brown.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '공유 코드 가져오기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _importController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'JM_PUZZLE_V1:...',
                        labelText: '공유 코드',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _importSharedPuzzle,
                        icon: const Icon(Icons.file_download),
                        label: const Text('가져온 문제에 저장'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '정답 수순이 포함된 공유 코드만 저장됩니다. 입력이 비어 있으면 클립보드에서 바로 읽습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_importedPuzzles.isEmpty)
              _buildEmptyCard(
                title: '아직 가져온 문제가 없습니다.',
                subtitle: '공유 코드를 붙여넣으면 이 탭에 바로 저장됩니다.',
              )
            else
              ..._importedPuzzles.map(_buildImportedPuzzleCard),
          ],
        ),
      ),
    );
  }

  Widget _buildImportedPuzzleCard(Map<String, dynamic> puzzle) {
    final progress = _progress.entryFor(_puzzleIdOf(puzzle));
    final createdAt = (puzzle['createdAt'] as String? ?? '').trim();
    final createdLabel = createdAt.isEmpty
        ? '가져온 시각 정보 없음'
        : '가져옴 ${createdAt.replaceFirst('T', ' ').substring(0, 16)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.brown.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.download_rounded, color: Colors.brown),
        ),
        title: _PuzzleTitleWithBadge(
          title: puzzle['title'] as String? ?? '가져온 문제',
          puzzle: puzzle,
        ),
        subtitle: Text(
          '$createdLabel\n${_progressSubtitle(puzzle: puzzle, progress: progress)}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress.isSolved)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle, color: Colors.green),
              ),
            IconButton(
              icon: const Icon(Icons.content_copy),
              tooltip: '공유 코드 복사',
              onPressed: () => _copyShareCode(puzzle),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              tooltip: '삭제',
              onPressed: () => _deletePuzzle(puzzle),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: '플레이',
              onPressed: () => _startPuzzle(puzzle),
            ),
          ],
        ),
        onTap: () => _startPuzzle(puzzle),
      ),
    );
  }

  Widget _buildEmptyCard({
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  String _progressSubtitle({
    required Map<String, dynamic> puzzle,
    required PuzzleProgressEntry progress,
  }) {
    final mateIn = (puzzle['mateIn'] as num?)?.toInt() ?? 1;
    final toMove = puzzle['toMove'] == 'red' ? '한 차례' : '초 차례';
    final objectiveType = PuzzleObjective.typeOf(puzzle);
    final objectiveLabel = PuzzleObjective.displayLabelForPuzzle(puzzle);

    if (progress.attempts == 0) {
      return objectiveType == PuzzleObjective.materialGain
          ? '$objectiveLabel · $toMove · 아직 도전 전'
          : '$mateIn수 문제 · $toMove · 아직 도전 전';
    }

    final prefix = objectiveType == PuzzleObjective.materialGain
        ? objectiveLabel
        : '$mateIn수 문제';
    return '$prefix · $toMove · 해결 ${progress.solvedCount}회 / 시도 ${progress.attempts}회';
  }

  String _puzzleIdOf(Map<String, dynamic> puzzle) {
    return puzzle['id'] as String? ?? '';
  }
}

Map<String, dynamic> _gameDataFromPuzzle(Map<String, dynamic> puzzle) {
  return <String, dynamic>{
    'id': puzzle['id'],
    'title': puzzle['title'],
    'fen': puzzle['fen'],
    'solution': List<String>.from(puzzle['solution'] ?? const <String>[]),
    'mateIn': (puzzle['mateIn'] as num?)?.toInt() ?? 1,
    'toMove': puzzle['toMove'] ?? 'blue',
    'objectiveType': PuzzleObjective.typeOf(puzzle),
    'objective': PuzzleObjective.objectiveOf(puzzle),
    'source': puzzle['source'] ?? 'custom',
    'moves': <String>[],
    'startMove': 0,
    'totalMoves': (puzzle['mateIn'] as num?)?.toInt() ?? 1,
  };
}

class _CompactTabLabel extends StatelessWidget {
  const _CompactTabLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}

class _PuzzleTitleWithBadge extends StatelessWidget {
  const _PuzzleTitleWithBadge({
    required this.title,
    required this.puzzle,
  });

  final String title;
  final Map<String, dynamic> puzzle;

  @override
  Widget build(BuildContext context) {
    final label = PuzzleObjective.displayLabelForPuzzle(puzzle);
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(title),
        Chip(
          label: Text(label),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class _BuiltinProgressSummary {
  const _BuiltinProgressSummary({
    required this.totalPuzzleCount,
    required this.solvedCount,
    required this.totalAttempts,
    required this.successRatePercent,
  });

  final int totalPuzzleCount;
  final int solvedCount;
  final int totalAttempts;
  final double successRatePercent;
}
