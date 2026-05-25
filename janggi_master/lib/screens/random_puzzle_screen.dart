import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/puzzle_objective.dart';
import '../providers/monetization_provider.dart';
import '../services/random_puzzle_service.dart';
import '../widgets/puzzle_board_preview.dart';
import 'puzzle_game_screen.dart';

class RandomPuzzleScreen extends StatefulWidget {
  const RandomPuzzleScreen({super.key});

  @override
  State<RandomPuzzleScreen> createState() => _RandomPuzzleScreenState();
}

class _RandomPuzzleScreenState extends State<RandomPuzzleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loadingController;
  late Future<RandomPuzzleSelection> _selectionFuture;
  final Map<String, int> _feedbackByPuzzleId = <String, int>{};
  var _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _selectionFuture = _generateWithRetry();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _generatePuzzle() async {
    final future = _generateWithRetry();
    setState(() {
      _selectionFuture = future;
    });
    await future;
    RandomPuzzleService.warmUp();
  }

  Future<RandomPuzzleSelection> _generateWithRetry() async {
    while (mounted) {
      try {
        final selection = await RandomPuzzleService.generate();
        _retryCount = 0;
        return selection;
      } catch (_) {
        _retryCount++;
        if (mounted) setState(() {});
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    throw const RandomPuzzleException('묘수 생성 화면이 닫혔습니다.');
  }

  Future<void> _startPuzzle(RandomPuzzleSelection selection) async {
    final monetization = context.read<MonetizationProvider>();
    final shouldShowAd = await monetization.shouldShowDailyPuzzleStartAdNow();
    if (!mounted) return;
    if (shouldShowAd) {
      await monetization.maybeShowDailyPuzzleStartInterstitial();
      if (!mounted) return;
    }

    await monetization.registerDailyPuzzleStarted();
    if (!mounted) return;

    RandomPuzzleService.warmUp();
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzleGameScreen(
          game: _gameDataFromPuzzle(selection.puzzle),
        ),
      ),
    );
    if (!mounted) return;
    _generatePuzzle();
  }

  Future<void> _ratePuzzle(String puzzleId, int vote) async {
    setState(() {
      _feedbackByPuzzleId[puzzleId] = vote;
    });
    await RandomPuzzleService.recordFeedback(
      puzzleId: puzzleId,
      vote: vote,
    );
  }

  Future<void> _loadFeedback(String puzzleId) async {
    if (puzzleId.isEmpty || _feedbackByPuzzleId.containsKey(puzzleId)) return;
    final vote = await RandomPuzzleService.feedbackFor(puzzleId);
    if (!mounted || vote == null) return;
    setState(() {
      _feedbackByPuzzleId[puzzleId] = vote;
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
              _buildHeader(context),
              Expanded(
                child: FutureBuilder<RandomPuzzleSelection>(
                  future: _selectionFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done ||
                        snapshot.hasError ||
                        !snapshot.hasData) {
                      return _buildLoadingState();
                    }
                    return _buildRandomPuzzle(snapshot.data!);
                  },
                ),
              ),
            ],
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
          const Expanded(
            child: Text(
              '일일 묘수풀이',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final message = _retryCount == 0 ? '묘수를 짜는 중입니다' : '더 좋은 수를 찾는 중입니다';

    return Center(
      child: Card(
        color: Colors.white.withValues(alpha: 0.94),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 210,
                height: 150,
                child: AnimatedBuilder(
                  animation: _loadingController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _PuzzleLoadingPainter(
                        progress: _loadingController.value,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (index) => AnimatedBuilder(
                    animation: _loadingController,
                    builder: (context, _) {
                      final phase =
                          (_loadingController.value + index / 3) % 1.0;
                      return Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA44E3F).withValues(
                            alpha: 0.35 + 0.55 * math.sin(phase * math.pi),
                          ),
                          shape: BoxShape.circle,
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

  Widget _buildRandomPuzzle(RandomPuzzleSelection selection) {
    final monetization = context.watch<MonetizationProvider>();
    final puzzle = selection.puzzle;
    final puzzleId = puzzle['id']?.toString() ?? '';
    if (puzzleId.isNotEmpty && !_feedbackByPuzzleId.containsKey(puzzleId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadFeedback(puzzleId);
      });
    }
    final mateIn = (puzzle['mateIn'] as num?)?.toInt() ?? 1;
    final toMove = puzzle['toMove'] == 'red' ? '한 차례' : '초 차례';
    final objectiveType = PuzzleObjective.typeOf(puzzle);
    final objectiveLabel = PuzzleObjective.displayLabelForPuzzle(puzzle);
    final subtitle = objectiveType == PuzzleObjective.materialGain
        ? objectiveLabel
        : '$mateIn수 문제';

    return RefreshIndicator(
      onRefresh: _generatePuzzle,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white.withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.casino,
                          color: Colors.deepOrange,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '일일 묘수풀이',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: PuzzleBoardPreview(fen: puzzle['fen'] as String),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$subtitle · $toMove',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDailyLimitInfo(monetization),
                  const SizedBox(height: 16),
                  _buildFeedbackRow(puzzleId),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _generatePuzzle,
                          icon: const Icon(Icons.refresh),
                          label: const Text('다음 묘수'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _startPuzzle(selection),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('도전하기'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyLimitInfo(MonetizationProvider monetization) {
    if (monetization.hasUnlimitedDailyPuzzles) {
      return const Row(
        children: [
          Icon(Icons.workspace_premium, color: Color(0xFFA44E3F)),
          SizedBox(width: 8),
          Expanded(child: Text('무제한 이용 중 · 모든 광고 제거')),
        ],
      );
    }

    final remaining = monetization.freeDailyPuzzleRemaining;
    return Row(
      children: [
        const Icon(Icons.today, color: Color(0xFFA44E3F)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            remaining > 0
                ? '오늘 무료 도전 $remaining회 남음'
                : '무료 3회 사용 완료 · 광고 후 계속 도전',
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackRow(String puzzleId) {
    final vote = _feedbackByPuzzleId[puzzleId];
    return Row(
      children: [
        const Text(
          '문제 평가',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        IconButton.filledTonal(
          tooltip: '좋아요',
          onPressed: puzzleId.isEmpty ? null : () => _ratePuzzle(puzzleId, 1),
          icon: Icon(
            Icons.thumb_up,
            color: vote == 1 ? const Color(0xFFA44E3F) : null,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: '싫어요',
          onPressed: puzzleId.isEmpty ? null : () => _ratePuzzle(puzzleId, -1),
          icon: Icon(
            Icons.thumb_down,
            color: vote == -1 ? const Color(0xFFA44E3F) : null,
          ),
        ),
      ],
    );
  }
}

class _PuzzleLoadingPainter extends CustomPainter {
  const _PuzzleLoadingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.16,
      size.width * 0.84,
      size.height * 0.64,
    );
    final boardPaint = Paint()
      ..color = const Color(0xFFE8C47F)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF8C6239)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final gridPaint = Paint()
      ..color = const Color(0xFF8C6239).withValues(alpha: 0.42)
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(8)),
      boardPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(8)),
      borderPaint,
    );

    for (var i = 1; i < 5; i++) {
      final x = boardRect.left + boardRect.width * i / 5;
      canvas.drawLine(
        Offset(x, boardRect.top + 8),
        Offset(x, boardRect.bottom - 8),
        gridPaint,
      );
    }
    for (var i = 1; i < 4; i++) {
      final y = boardRect.top + boardRect.height * i / 4;
      canvas.drawLine(
        Offset(boardRect.left + 8, y),
        Offset(boardRect.right - 8, y),
        gridPaint,
      );
    }

    _drawPiece(
      canvas,
      center: Offset(boardRect.left + boardRect.width * 0.23,
          boardRect.top + boardRect.height * 0.72),
      radius: 20,
      label: '楚',
      color: const Color(0xFF1D5FB8),
      lift: math.sin((progress + 0.15) * math.pi * 2) * 3,
    );
    _drawPiece(
      canvas,
      center: Offset(boardRect.left + boardRect.width * 0.76,
          boardRect.top + boardRect.height * 0.30),
      radius: 20,
      label: '漢',
      color: const Color(0xFFC03A2B),
      lift: math.sin((progress + 0.55) * math.pi * 2) * 3,
    );

    final path = Path()
      ..moveTo(boardRect.left + boardRect.width * 0.28,
          boardRect.top + boardRect.height * 0.62)
      ..quadraticBezierTo(
        boardRect.left + boardRect.width * 0.50,
        boardRect.top + boardRect.height * 0.12,
        boardRect.left + boardRect.width * 0.72,
        boardRect.top + boardRect.height * 0.54,
      );
    final metric = path.computeMetrics().first;
    final tangent = metric.getTangentForOffset(metric.length * progress);
    final movingCenter =
        tangent?.position ?? Offset(boardRect.center.dx, boardRect.center.dy);
    final pulse = 1 + math.sin(progress * math.pi * 2) * 0.06;

    final tracePaint = Paint()
      ..color = const Color(0xFFFFF4C2).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, tracePaint);

    _drawPiece(
      canvas,
      center: movingCenter,
      radius: 18 * pulse,
      label: '車',
      color: const Color(0xFFA44E3F),
      lift: 0,
      shadowAlpha: 0.34,
    );
  }

  void _drawPiece(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required String label,
    required Color color,
    required double lift,
    double shadowAlpha = 0.22,
  }) {
    final shifted = Offset(center.dx, center.dy - lift);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: shadowAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 2, center.dy + radius * 0.72),
        width: radius * 1.65,
        height: radius * 0.42,
      ),
      shadowPaint,
    );

    final piecePaint = Paint()..color = const Color(0xFFFFF1D0);
    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(shifted, radius, piecePaint);
    canvas.drawCircle(shifted, radius - 2, ringPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: radius * 0.95,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      shifted - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PuzzleLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

Map<String, dynamic> _gameDataFromPuzzle(Map<String, dynamic> puzzle) {
  final solution = List<String>.from(puzzle['solution'] ?? const <String>[]);
  final playerMoveCount = (solution.length + 1) ~/ 2;
  return <String, dynamic>{
    'id': puzzle['id'],
    'title': '일일 묘수풀이',
    'fen': puzzle['fen'],
    'solution': solution,
    'mateIn': (puzzle['mateIn'] as num?)?.toInt() ?? 1,
    'toMove': puzzle['toMove'] ?? 'blue',
    'objectiveType': PuzzleObjective.typeOf(puzzle),
    'objective': PuzzleObjective.objectiveOf(puzzle),
    'source': puzzle['source'] ?? 'generated',
    'feedType': puzzle['feedType'] ?? 'generated',
    'moves': <String>[],
    'startMove': 0,
    'totalMoves': playerMoveCount,
  };
}
