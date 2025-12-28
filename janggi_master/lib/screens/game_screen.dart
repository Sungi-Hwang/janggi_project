import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/game_state.dart';
import '../widgets/janggi_board_widget.dart';
import '../stockfish_ffi.dart';
import '../models/piece.dart';

/// Game modes
enum GameMode {
  vsAI,      // Play against AI
  twoPlayer, // Local 2-player mode
}

class GameScreen extends StatefulWidget {
  final GameMode gameMode;
  final int aiDifficulty;
  final PieceColor aiColor;

  const GameScreen({
    super.key,
    this.gameMode = GameMode.vsAI,
    this.aiDifficulty = 10,
    this.aiColor = PieceColor.red,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _engineInitialized = false;
  bool _gameOverDialogShown = false;

  @override
  void initState() {
    super.initState();
    // Only initialize engine for AI mode
    if (widget.gameMode == GameMode.vsAI) {
      _initEngine();
    } else {
      // For 2-player mode, mark as ready immediately
      _engineInitialized = true;
    }
  }

  Future<void> _initEngine() async {
    try {
      debugPrint('Starting engine initialization...');
      StockfishFFI.init();
      debugPrint('Engine init() completed');

      // Don't call isReady() here - it triggers lazy init which blocks UI
      // Just mark as ready immediately - lazy init will happen on first move
      setState(() {
        _engineInitialized = true;
      });
      debugPrint('Engine marked as ready (lazy init on first command)');
    } catch (e) {
      debugPrint('Engine init error: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState(
        gameMode: widget.gameMode,
        aiDifficulty: widget.aiDifficulty,
        aiColor: widget.aiColor,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5E6D3), // Beige background
        body: SafeArea(
          child: Consumer<GameState>(
            builder: (context, gameState, child) {
            // Show game over dialog when game ends (only once)
            if (gameState.isGameOver && gameState.gameOverReason != null && !_gameOverDialogShown) {
              _gameOverDialogShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showGameOverDialog(context, gameState);
              });
            }

            // Reset dialog flag when game restarts
            if (!gameState.isGameOver && _gameOverDialogShown) {
              _gameOverDialogShown = false;
            }

            return Column(
              children: [
                // Thin status bar at top
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          gameState.statusMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (gameState.isEngineThinking)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),

                // Board and controls - centered together
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate board width to fit in the available space
                        final maxWidth = constraints.maxWidth;
                        final maxHeight = constraints.maxHeight;

                        // Button area height (icon + label + padding)
                        const buttonAreaHeight = 80.0;

                        // Available height for board
                        final availableHeightForBoard = maxHeight - buttonAreaHeight;

                        // Board aspect ratio is 9:10 (width:height)
                        // Calculate board dimensions
                        final boardHeightFromWidth = maxWidth * (10 / 9);
                        final boardWidthFromHeight = availableHeightForBoard * (9 / 10);

                        // Use the smaller dimension to ensure everything fits
                        final boardWidth = boardHeightFromWidth <= availableHeightForBoard
                            ? maxWidth
                            : boardWidthFromHeight;
                        final boardHeight = boardWidth * (10 / 9);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Board widget
                            SizedBox(
                              width: boardWidth,
                              height: boardHeight,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: JanggiBoardWidget(
                                  board: gameState.board,
                                  selectedPosition: gameState.selectedPosition,
                                  validMoves: gameState.validMoves,
                                  onSquareTapped: _engineInitialized
                                      ? gameState.onSquareTapped
                                      : null,
                                  flipBoard: widget.gameMode == GameMode.vsAI && gameState.aiColor == PieceColor.blue, // Flip if AI is Blue (player is Red)
                                  animatingMove: gameState.animatingMove,
                                  isAnimating: gameState.isAnimating,
                                  animatingPiece: gameState.animatingPiece,
                                ),
                              ),
                            ),

                            // Bottom controls - constrained to board width
                            Container(
                              width: boardWidth,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildGameButton(
                                    icon: Icons.flag,
                                    label: '기권',
                                    color: Colors.red,
                                    onPressed: () => _showSurrenderDialog(context, gameState),
                                  ),
                                  _buildGameButton(
                                    icon: Icons.settings,
                                    label: '설정',
                                    color: Colors.grey[700]!,
                                    onPressed: () => _showSetupDialog(context, gameState),
                                  ),
                                  _buildGameButton(
                                    icon: Icons.undo,
                                    label: '한수 무름',
                                    color: Colors.blue,
                                    onPressed: gameState.moveHistory.isNotEmpty
                                        ? () => gameState.undoMove()
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
            },
          ),
        ),
      ),
    );
  }

  void _showGameOverDialog(BuildContext context, GameState gameState) {
    final reason = gameState.gameOverReason;
    if (reason == null) return;

    String title;
    String message;
    IconData icon;
    Color iconColor;

    if (reason == 'blue_wins_checkmate' || reason == 'blue_wins_capture') {
      title = '초(Blue) 승리!';
      message = reason == 'blue_wins_checkmate'
          ? '체크메이트로 승리했습니다!'
          : '왕을 잡아서 승리했습니다!';
      icon = Icons.emoji_events;
      iconColor = Colors.blue;
    } else if (reason == 'red_wins_checkmate' || reason == 'red_wins_capture') {
      title = '한(Red) 승리!';
      message = reason == 'red_wins_checkmate'
          ? '체크메이트로 승리했습니다!'
          : '왕을 잡아서 승리했습니다!';
      icon = Icons.emoji_events;
      iconColor = Colors.red;
    } else {
      // Draw conditions (장기: 3수 동형, 50수 규칙만 해당)
      title = '무승부!';
      icon = Icons.handshake;
      iconColor = Colors.grey;

      if (reason == 'threefold_repetition') {
        message = '3수 동형 - 같은 국면이 3번 반복되었습니다.';
      } else if (reason == 'fifty_move_rule') {
        message = '50수 규칙 - 50수 동안 잡거나 졸이 움직이지 않았습니다.';
      } else {
        message = '게임이 무승부로 끝났습니다.';
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: iconColor, size: 32),
              const SizedBox(width: 12),
              Text(title),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                gameState.newGame();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('새 게임'),
            ),
          ],
        );
      },
    );
  }

  void _showSetupDialog(BuildContext context, GameState gameState) {
    PieceSetup selectedBlueSetup = gameState.blueSetup;
    PieceSetup selectedRedSetup = gameState.redSetup;
    int selectedAIDifficulty = gameState.aiDepth;
    PieceColor selectedAIColor = gameState.aiColor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('게임 설정 (Game Setup)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // AI Color (which side AI plays)
                    if (widget.gameMode == GameMode.vsAI) ...[
                      const Text('AI 진영:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButton<PieceColor>(
                        value: selectedAIColor,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: PieceColor.red,
                            child: Text('한 (Red) - AI가 한나라'),
                          ),
                          DropdownMenuItem(
                            value: PieceColor.blue,
                            child: Text('초 (Blue) - AI가 초나라'),
                          ),
                        ],
                        onChanged: (PieceColor? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedAIColor = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    // AI Difficulty
                    if (widget.gameMode == GameMode.vsAI) ...[
                      const Text('AI 난이도:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        value: selectedAIDifficulty,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Level 1 - 입문자 (매우 쉬움)')),
                          DropdownMenuItem(value: 3, child: Text('Level 2 - 초보 (쉬움)')),
                          DropdownMenuItem(value: 5, child: Text('Level 3 - 초급 (보통) ⭐')),
                          DropdownMenuItem(value: 7, child: Text('Level 4 - 중급 (어려움)')),
                          DropdownMenuItem(value: 9, child: Text('Level 5 - 중상급 (강함)')),
                          DropdownMenuItem(value: 11, child: Text('Level 6 - 고급 (매우 강함)')),
                          DropdownMenuItem(value: 13, child: Text('Level 7 - 고수 (극강)')),
                          DropdownMenuItem(value: 15, child: Text('Level 8 - 프로 (최강) 🔥')),
                        ],
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedAIDifficulty = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Blue setup
                    const Text('초 (Blue) 배치:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<PieceSetup>(
                      value: selectedBlueSetup,
                      isExpanded: true,
                      items: PieceSetup.values.map((setup) {
                        return DropdownMenuItem(
                          value: setup,
                          child: Text('${setup.displayName} - ${setup.description}'),
                        );
                      }).toList(),
                      onChanged: (PieceSetup? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedBlueSetup = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Red setup
                    const Text('한 (Red) 배치:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<PieceSetup>(
                      value: selectedRedSetup,
                      isExpanded: true,
                      items: PieceSetup.values.map((setup) {
                        return DropdownMenuItem(
                          value: setup,
                          child: Text('${setup.displayName} - ${setup.description}'),
                        );
                      }).toList(),
                      onChanged: (PieceSetup? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedRedSetup = newValue;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    gameState.setAIDifficulty(selectedAIDifficulty);
                    gameState.setAIColor(selectedAIColor);
                    gameState.setPieceSetup(
                      blueSetup: selectedBlueSetup,
                      redSetup: selectedRedSetup,
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('시작'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Build a game control button
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
          iconSize: 32,
          padding: const EdgeInsets.all(8),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onPressed != null ? color : Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Show surrender confirmation dialog
  void _showSurrenderDialog(BuildContext context, GameState gameState) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.flag, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('기권하시겠습니까?'),
            ],
          ),
          content: const Text(
            '기권하면 패배로 처리됩니다.\n정말 기권하시겠습니까?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Trigger game over as defeat
                final winningColor = gameState.currentPlayer == PieceColor.blue
                    ? 'red'
                    : 'blue';
                gameState.testGameOver('${winningColor}_wins_capture');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('기권', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    StockfishFFI.cleanup();
    super.dispose();
  }
}
