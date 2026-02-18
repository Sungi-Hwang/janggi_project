import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../providers/settings_provider.dart';
import '../screens/game_screen.dart' show GameMode;
import '../services/custom_puzzle_service.dart';
import '../utils/stockfish_converter.dart';
import '../widgets/evaluation_bar.dart';
import '../widgets/game_notification_overlay.dart';
import '../widgets/janggi_board_widget.dart';
import '../widgets/player_info_bar.dart';

class CustomPuzzleRecordScreen extends StatefulWidget {
  final Board initialBoard;
  final PieceColor bottomColor;
  final String suggestedTitle;

  const CustomPuzzleRecordScreen({
    super.key,
    required this.initialBoard,
    required this.bottomColor,
    required this.suggestedTitle,
  });

  @override
  State<CustomPuzzleRecordScreen> createState() =>
      _CustomPuzzleRecordScreenState();
}

class _CustomPuzzleRecordScreenState extends State<CustomPuzzleRecordScreen> {
  late final GameState _gameState;
  late final Board _initialBoard;
  late final PieceColor _bottomColor;
  late final String _initialFen;
  bool _isSaving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _initialBoard = widget.initialBoard.copy();
    _bottomColor = widget.bottomColor;
    _initialFen = StockfishConverter.boardToFEN(_initialBoard, _bottomColor);

    _gameState = GameState(gameMode: GameMode.twoPlayer);
    _gameState.addListener(_onGameStateChanged);
    _gameState.setPuzzlePosition(_initialBoard.copy(), _bottomColor);
  }

  @override
  void dispose() {
    _gameState.removeListener(_onGameStateChanged);
    _gameState.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (_saved || _isSaving) return;
    if (!_gameState.isGameOver) return;

    final reason = _gameState.gameOverReason ?? '';
    if (reason.contains('checkmate')) {
      _savePuzzle(autoByCheckmate: true);
    }
  }

  Future<void> _savePuzzle({required bool autoByCheckmate}) async {
    if (_saved || _isSaving) return;

    final solution = _gameState.moveHistory.map((m) => m.toUCI()).toList();
    if (solution.isEmpty) {
      if (!autoByCheckmate) {
        _showSnack('최소 1수 이상 진행 후 저장할 수 있습니다.');
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();
      final title = widget.suggestedTitle.trim().isNotEmpty
          ? widget.suggestedTitle.trim()
          : '나만의 묘수 ${now.toIso8601String().substring(5, 16)}';
      final toMove = _bottomColor == PieceColor.blue ? 'blue' : 'red';
      final playerMoves = (solution.length + 1) ~/ 2;

      final puzzle = <String, dynamic>{
        'id': CustomPuzzleService.nextId(),
        'title': title,
        'fen': _initialFen,
        'solution': solution,
        'mateIn': playerMoves < 1 ? 1 : playerMoves,
        'toMove': toMove,
        'source': 'custom',
        'createdAt': now.toIso8601String(),
      };

      await CustomPuzzleService.addPuzzle(puzzle);
      _saved = true;

      if (!mounted) return;
      if (autoByCheckmate) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('자동 저장 완료'),
            content: const Text('체크메이트가 발생하여 퍼즐이 자동 저장되었습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } else {
        _showSnack('퍼즐을 저장했습니다.');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _restart() {
    _gameState.setPuzzlePosition(_initialBoard.copy(), _bottomColor);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _sideLabel(PieceColor color) {
    return color == PieceColor.blue ? '초' : '한';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameState>.value(
      value: _gameState,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5E6D3),
        body: SafeArea(
          child: Consumer<GameState>(
            builder: (context, gameState, child) {
              final settings = context.watch<SettingsProvider>();
              final topColor = _bottomColor == PieceColor.blue
                  ? PieceColor.red
                  : PieceColor.blue;
              final flipBoard = _bottomColor == PieceColor.red;

              final topCaptured = topColor == PieceColor.red
                  ? gameState.capturedByRed
                  : gameState.capturedByBlue;
              final bottomCaptured = _bottomColor == PieceColor.red
                  ? gameState.capturedByRed
                  : gameState.capturedByBlue;

              return Stack(
                children: [
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        color: Colors.black.withValues(alpha: 0.8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '수순 기록',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              '기록 수: ${gameState.moveHistory.length}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PlayerInfoBar(
                        name: '${_sideLabel(topColor)} (상단)',
                        isTop: true,
                        capturedPieces: topCaptured,
                        pieceColor: topColor == PieceColor.red
                            ? PieceColor.blue
                            : PieceColor.red,
                        onTap: () {},
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.black12,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 4,
                                ),
                                child: EvaluationBar(
                                  score: gameState.evaluationScore,
                                  type: gameState.evaluationType,
                                  isBlueTurn: gameState.currentPlayer ==
                                      PieceColor.blue,
                                  visible: gameState.showEvaluation,
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: AspectRatio(
                                      aspectRatio: 9 / 10,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: JanggiBoardWidget(
                                          board: gameState.board,
                                          selectedPosition:
                                              gameState.selectedPosition,
                                          validMoves: gameState.validMoves,
                                          onSquareTapped: gameState.isGameOver
                                              ? null
                                              : gameState.onSquareTapped,
                                          flipBoard: flipBoard,
                                          animatingMove:
                                              gameState.animatingMove,
                                          isAnimating: gameState.isAnimating,
                                          animatingPiece:
                                              gameState.animatingPiece,
                                          hintMove: null,
                                          boardSkin: settings.boardSkin,
                                          pieceSkin: settings.pieceSkin,
                                          showCoordinates:
                                              settings.showCoordinates,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                      PlayerInfoBar(
                        name: '${_sideLabel(_bottomColor)} (하단 시작)',
                        isTop: false,
                        capturedPieces: bottomCaptured,
                        pieceColor: _bottomColor == PieceColor.red
                            ? PieceColor.blue
                            : PieceColor.red,
                        onTap: () {},
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3E2723),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildGameButton(
                              icon: Icons.refresh,
                              label: '다시 시작',
                              color: Colors.white,
                              onPressed: _restart,
                            ),
                            _buildGameButton(
                              icon: Icons.save_alt,
                              label: '중단/저장',
                              color: Colors.greenAccent.shade200,
                              onPressed: _isSaving
                                  ? null
                                  : () => _savePuzzle(autoByCheckmate: false),
                            ),
                            _buildGameButton(
                              icon: Icons.undo,
                              label: '무르기',
                              color: Colors.blueAccent,
                              onPressed: gameState.moveHistory.isNotEmpty
                                  ? gameState.undoMove
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (gameState.showCheckNotification)
                    const GameNotificationOverlay(type: NotificationType.check),
                  if (gameState.showEscapeCheckNotification)
                    const GameNotificationOverlay(
                      type: NotificationType.escapeCheck,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGameButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: onPressed != null ? color : Colors.grey[400],
          iconSize: 28,
          padding: const EdgeInsets.all(4),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: onPressed != null ? color : Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
