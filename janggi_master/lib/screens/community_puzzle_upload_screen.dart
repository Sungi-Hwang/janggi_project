import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/community_auth_provider.dart';
import '../services/community_puzzle_service.dart';
import '../services/custom_puzzle_service.dart';
import '../widgets/puzzle_board_preview.dart';

class CommunityPuzzleUploadScreen extends StatefulWidget {
  const CommunityPuzzleUploadScreen({super.key});

  @override
  State<CommunityPuzzleUploadScreen> createState() =>
      _CommunityPuzzleUploadScreenState();
}

class _CommunityPuzzleUploadScreenState
    extends State<CommunityPuzzleUploadScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final CommunityPuzzleService _service = CommunityPuzzleService();

  List<Map<String, dynamic>> _createdPuzzles = <Map<String, dynamic>>[];
  Map<String, dynamic>? _selectedPuzzle;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCreatedPuzzles();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCreatedPuzzles() async {
    final puzzles = await CustomPuzzleService.loadCreatedPuzzles();
    if (!mounted) return;
    setState(() {
      _createdPuzzles = puzzles;
      _selectedPuzzle = puzzles.isEmpty ? null : puzzles.first;
      _isLoading = false;
    });
  }

  Future<void> _upload() async {
    final auth = context.read<CommunityAuthProvider>();
    final signedIn = await auth.ensureSignedIn();
    if (!signedIn) {
      _showSnack(auth.lastError ?? 'Google 로그인이 필요합니다.');
      return;
    }

    final puzzle = _selectedPuzzle;
    if (puzzle == null) {
      _showSnack('올릴 문제가 없습니다.');
      return;
    }

    setState(() {
      _isUploading = true;
    });
    try {
      await _service.uploadPuzzle(
        puzzle: puzzle,
        description: _descriptionController.text,
      );
      if (!mounted) return;
      _showSnack('문제 공유소에 올렸습니다.');
      Navigator.pop(context, true);
    } on CommunityPuzzleException catch (error) {
      _showSnack(error.message);
    } catch (error) {
      _showSnack('업로드에 실패했습니다: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
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
    final auth = context.watch<CommunityAuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('문제 올리기'),
        backgroundColor: const Color(0xFF3E2723),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.isSignedIn
                                  ? '${auth.displayName} 계정으로 올립니다.'
                                  : '업로드하려면 Google 로그인이 필요합니다.',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!auth.isSignedIn) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: auth.isBusy
                                    ? null
                                    : () async {
                                        final ok =
                                            await auth.signInWithGoogle();
                                        if (!ok && mounted) {
                                          _showSnack(
                                            auth.lastError ?? '로그인하지 못했습니다.',
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.login),
                                label: const Text('Google 로그인'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_createdPuzzles.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '아직 직접 만든 문제가 없습니다.\n문제풀이의 내가 만든 문제에서 먼저 문제를 만들어 주세요.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else ...[
                      const Text(
                        '올릴 문제 선택',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._createdPuzzles.map(_buildPuzzleOption),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        maxLength: 140,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          labelText: '한줄 설명',
                          hintText: '예: 차를 희생해서 궁을 묶는 2수 문제',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _isUploading ? null : _upload,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: const Text('문제 공유소에 올리기'),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPuzzleOption(Map<String, dynamic> puzzle) {
    final selected = identical(_selectedPuzzle, puzzle) ||
        _selectedPuzzle?['id'] == puzzle['id'];
    return Card(
      color: selected ? Colors.amber.shade50 : Colors.white,
      child: ListTile(
        leading: SizedBox(
          width: 48,
          child: PuzzleBoardPreview(fen: puzzle['fen'] as String? ?? ''),
        ),
        title: Text(puzzle['title'] as String? ?? '내 문제'),
        subtitle: Text('${puzzle['mateIn'] ?? 1}수 문제'),
        trailing: selected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        onTap: () {
          setState(() {
            _selectedPuzzle = puzzle;
          });
        },
      ),
    );
  }
}
