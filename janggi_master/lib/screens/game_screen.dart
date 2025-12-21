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
