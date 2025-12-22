import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/game_state.dart';
import '../widgets/janggi_board_widget.dart';
import '../stockfish_ffi.dart';
import '../models/piece.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _engineInitialized = false;
  bool _gameOverDialogShown = false;

  @override
  void initState() {
    super.initState();
    _initEngine();
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
      create: (_) => GameState(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('장기 마스터 (Janggi Master)'),
          actions: [
            if (!_engineInitialized)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        body: Consumer<GameState>(
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
                // Status bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          gameState.statusMessage,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (gameState.isEngineThinking)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),

                // Board
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: JanggiBoardWidget(
                        board: gameState.board,
                        selectedPosition: gameState.selectedPosition,
                        validMoves: gameState.validMoves,
                        onSquareTapped: _engineInitialized
                            ? gameState.onSquareTapped
                            : null,
                        flipBoard: false,
                      ),
                    ),
                  ),
                ),

                // Controls
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          gameState.newGame();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('New Game'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showSetupDialog(context, gameState);
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Setup'),
                      ),
                      ElevatedButton.icon(
                        onPressed: gameState.moveHistory.isNotEmpty
                            ? () {
                                gameState.undoMove();
                              }
                            : null,
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo'),
                      ),
                    ],
                  ),
                ),

                // DEBUG: Test buttons for game over dialogs
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      const Text('디버그:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ElevatedButton(
                        onPressed: () {
                          gameState.testGameOver('blue_wins_checkmate');
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text('Blue 승리', style: TextStyle(fontSize: 12)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          gameState.testGameOver('red_wins_capture');
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Red 승리', style: TextStyle(fontSize: 12)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          gameState.testGameOver('threefold_repetition');
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                        child: const Text('무승부(3수)', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Move history
                Container(
                  height: 100,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      itemCount: gameState.moveHistory.length,
                      itemBuilder: (context, index) {
                        final move = gameState.moveHistory[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Chip(
                            label: Text(
                              '${index + 1}. ${move.toUCI()}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('기물 배치 선택 (Piece Setup)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
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

  @override
  void dispose() {
    StockfishFFI.cleanup();
    super.dispose();
  }
}
