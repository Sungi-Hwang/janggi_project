import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/community_puzzle.dart';
import '../providers/community_auth_provider.dart';
import '../services/community_puzzle_service.dart';
import '../services/custom_puzzle_service.dart';
import '../widgets/puzzle_board_preview.dart';
import 'puzzle_game_screen.dart';

class CommunityPuzzleDetailScreen extends StatefulWidget {
  const CommunityPuzzleDetailScreen({
    super.key,
    required this.initialPuzzle,
  });

  final CommunityPuzzle initialPuzzle;

  @override
  State<CommunityPuzzleDetailScreen> createState() =>
      _CommunityPuzzleDetailScreenState();
}

class _CommunityPuzzleDetailScreenState
    extends State<CommunityPuzzleDetailScreen> {
  final CommunityPuzzleService _service = CommunityPuzzleService();

  late CommunityPuzzle _puzzle = widget.initialPuzzle;
  bool _isLoading = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final puzzle = await _service.fetchPuzzle(widget.initialPuzzle.id);
      if (!mounted) return;
      setState(() {
        _puzzle = puzzle;
      });
    } catch (_) {
      // Keep the initial row so the detail page still opens offline-ish.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    final auth = context.read<CommunityAuthProvider>();
    final signedIn = await auth.ensureSignedIn();
    if (!signedIn) {
      _showSnack(auth.lastError ?? '좋아요를 누르려면 Google 로그인이 필요합니다.');
      return;
    }

    await _runBusy(() async {
      final liked = await _service.toggleLike(_puzzle.id);
      setState(() {
        _puzzle = _puzzle.copyWith(
          hasLiked: liked,
          likeCount: _puzzle.likeCount + (liked ? 1 : -1),
        );
      });
    }, failureMessage: '좋아요 처리에 실패했습니다.');
  }

  Future<void> _importPuzzle() async {
    final shouldMarkServerImport =
        context.read<CommunityAuthProvider>().isSignedIn;

    await _runBusy(() async {
      final localPuzzle = <String, dynamic>{
        ..._puzzle.toLocalPuzzle(),
        'id': CustomPuzzleService.nextImportedId(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      await CustomPuzzleService.addImportedPuzzle(
        localPuzzle,
        importSource: CustomPuzzleService.importSourceCommunityPost,
      );

      if (shouldMarkServerImport) {
        await _service.markImported(_puzzle.id);
        setState(() {
          _puzzle = _puzzle.copyWith(importCount: _puzzle.importCount + 1);
        });
      }

      _showSnack('가져온 문제 탭에 저장했습니다.');
    }, failureMessage: '가져오기에 실패했습니다.');
  }

  Future<void> _reportPuzzle() async {
    final auth = context.read<CommunityAuthProvider>();
    final signedIn = await auth.ensureSignedIn();
    if (!signedIn) {
      _showSnack(auth.lastError ?? '신고하려면 Google 로그인이 필요합니다.');
      return;
    }

    await _runBusy(() async {
      await _service.reportPuzzle(_puzzle.id);
      setState(() {
        _puzzle = _puzzle.copyWith(reportCount: _puzzle.reportCount + 1);
      });
      _showSnack('신고를 접수했습니다.');
    }, failureMessage: '신고에 실패했습니다.');
  }

  Future<void> _playPuzzle() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzleGameScreen(
          game: <String, dynamic>{
            'id': 'community_${_puzzle.id}',
            'title': _puzzle.title,
            'fen': _puzzle.fen,
            'solution': _puzzle.solution,
            'mateIn': _puzzle.mateIn,
            'toMove': _puzzle.toMove,
            'source': 'community',
            'moves': <String>[],
            'startMove': 0,
            'totalMoves': _puzzle.mateIn,
          },
        ),
      ),
    );
  }

  Future<void> _runBusy(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });
    try {
      await action();
    } on CommunityPuzzleException catch (error) {
      _showSnack(error.message);
    } catch (error) {
      _showSnack('$failureMessage: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDate(_puzzle.createdAt);
    final side = _puzzle.toMove == 'red' ? '한 차례' : '초 차례';

    return Scaffold(
      appBar: AppBar(
        title: const Text('공유 문제'),
        backgroundColor: const Color(0xFF3E2723),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PuzzleBoardPreview(fen: _puzzle.fen),
                    const SizedBox(height: 16),
                    Text(
                      _puzzle.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(_puzzle.description),
                    const SizedBox(height: 10),
                    Text(
                      '${_puzzle.mateIn}수 문제 · $side · ${_puzzle.authorName} · $createdAt',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatChip(
                          icon: Icons.favorite,
                          label: '${_puzzle.likeCount}',
                        ),
                        _StatChip(
                          icon: Icons.download,
                          label: '${_puzzle.importCount}',
                        ),
                        _StatChip(
                          icon: Icons.flag,
                          label: '${_puzzle.reportCount}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isBusy ? null : _playPuzzle,
              icon: const Icon(Icons.play_arrow),
              label: const Text('바로 풀기'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _isBusy ? null : _importPuzzle,
              icon: const Icon(Icons.file_download),
              label: const Text('가져온 문제에 저장'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _toggleLike,
              icon: Icon(
                _puzzle.hasLiked ? Icons.favorite : Icons.favorite_border,
              ),
              label: Text(_puzzle.hasLiked ? '좋아요 취소' : '좋아요'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _reportPuzzle,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('신고'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    if (value.millisecondsSinceEpoch == 0) {
      return '날짜 없음';
    }
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month.$day';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
