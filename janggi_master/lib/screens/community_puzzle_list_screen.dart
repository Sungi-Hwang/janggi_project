import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/community_puzzle.dart';
import '../providers/community_auth_provider.dart';
import '../services/community_puzzle_service.dart';
import '../widgets/puzzle_board_preview.dart';
import 'community_puzzle_detail_screen.dart';
import 'community_puzzle_upload_screen.dart';

class CommunityPuzzleListScreen extends StatefulWidget {
  const CommunityPuzzleListScreen({super.key});

  @override
  State<CommunityPuzzleListScreen> createState() =>
      _CommunityPuzzleListScreenState();
}

class _CommunityPuzzleListScreenState extends State<CommunityPuzzleListScreen> {
  final CommunityPuzzleService _service = CommunityPuzzleService();

  CommunityPuzzleSort _sort = CommunityPuzzleSort.latest;
  List<CommunityPuzzle> _puzzles = <CommunityPuzzle>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPuzzles();
  }

  Future<void> _loadPuzzles() async {
    if (!_service.isConfigured) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Supabase 설정이 필요합니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final puzzles = await _service.fetchPuzzles(sort: _sort);
      if (!mounted) return;
      setState(() {
        _puzzles = puzzles;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      debugPrint('Failed to load community puzzles: $error');
      setState(() {
        _errorMessage = '문제 공유소를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openUpload() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CommunityPuzzleUploadScreen(),
      ),
    );
    if (created == true) {
      _loadPuzzles();
    }
  }

  Future<void> _openDetail(CommunityPuzzle puzzle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityPuzzleDetailScreen(
          initialPuzzle: puzzle,
        ),
      ),
    );
    _loadPuzzles();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<CommunityAuthProvider>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _service.isConfigured ? _openUpload : null,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('올리기'),
      ),
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
              _buildHeader(context, auth),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSortBar(),
                      const SizedBox(height: 12),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CommunityAuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black.withValues(alpha: 0.72),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '문제 공유소',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          if (auth.isSignedIn)
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle, color: Colors.white),
              tooltip: auth.displayName,
              onSelected: (value) {
                if (value == 'signout') {
                  auth.signOut();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'signout',
                  child: Text('로그아웃'),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: auth.isBusy
                  ? null
                  : () async {
                      final ok = await auth.signInWithGoogle();
                      if (!ok && mounted) {
                        _showSnack(auth.lastError ?? '로그인하지 못했습니다.');
                      }
                    },
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text(
                '로그인',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return SegmentedButton<CommunityPuzzleSort>(
      segments: const [
        ButtonSegment(
          value: CommunityPuzzleSort.latest,
          icon: Icon(Icons.schedule),
          label: Text('최신순'),
        ),
        ButtonSegment(
          value: CommunityPuzzleSort.likes,
          icon: Icon(Icons.favorite),
          label: Text('좋아요순'),
        ),
      ],
      selected: <CommunityPuzzleSort>{_sort},
      onSelectionChanged: (selected) {
        setState(() {
          _sort = selected.first;
        });
        _loadPuzzles();
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadPuzzles,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_puzzles.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '아직 공유된 문제가 없습니다.\n내가 만든 문제를 먼저 올려 보세요.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPuzzles,
      child: ListView.builder(
        itemCount: _puzzles.length,
        itemBuilder: (context, index) {
          return _CommunityPuzzleCard(
            puzzle: _puzzles[index],
            onTap: () => _openDetail(_puzzles[index]),
          );
        },
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _CommunityPuzzleCard extends StatelessWidget {
  const _CommunityPuzzleCard({
    required this.puzzle,
    required this.onTap,
  });

  final CommunityPuzzle puzzle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final side = puzzle.toMove == 'red' ? '한 차례' : '초 차례';
    final createdAt = _formatDate(puzzle.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: PuzzleBoardPreview(fen: puzzle.fen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      puzzle.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      puzzle.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${puzzle.mateIn}수 · $side · ${puzzle.authorName} · $createdAt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _MiniStat(
                          icon: puzzle.hasLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          value: puzzle.likeCount,
                        ),
                        _MiniStat(
                          icon: Icons.download,
                          value: puzzle.importCount,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade700),
        const SizedBox(width: 3),
        Text('$value', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
