import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../providers/settings_provider.dart';
import '../screens/settings_screen.dart';
import '../stockfish_ffi.dart';
import '../widgets/captured_pieces_panel.dart';
import '../widgets/evaluation_bar.dart';
import '../widgets/game_notification_overlay.dart';
import '../widgets/janggi_board_widget.dart';
import '../widgets/player_info_bar.dart';

/// Game modes
enum GameMode {
  vsAI,
  twoPlayer,
}

class GameScreen extends StatefulWidget {
  final GameMode gameMode;
  final int aiDifficulty;
  final int aiThinkingTimeSec;
  final PieceColor aiColor;
  final PieceSetup blueSetup;
  final PieceSetup redSetup;
  final Board? initialBoard;
  final PieceColor? initialStartingPlayer;

  const GameScreen({
    super.key,
    this.gameMode = GameMode.vsAI,
    this.aiDifficulty = 5,
    this.aiThinkingTimeSec = 5,
    this.aiColor = PieceColor.red,
    this.blueSetup = PieceSetup.horseElephantHorseElephant,
    this.redSetup = PieceSetup.horseElephantHorseElephant,
    this.initialBoard,
    this.initialStartingPlayer,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _engineInitialized = false;
  bool _gameOverDialogShown = false;
  bool _autoSmokeTriggered = false;
  late PieceSetup _pendingBlueSetup;
  late PieceSetup _pendingRedSetup;
  late PieceColor _pendingPlayerColor;
  late PieceColor _effectiveAiColor;
  late bool _setupCompleted;
  Board? _customInitialBoard;
  PieceColor? _customStartingPlayer;

  bool get _hasCustomStart =>
      _customInitialBoard != null && _customStartingPlayer != null;

  @override
  void initState() {
    super.initState();
    _pendingBlueSetup = widget.blueSetup;
    _pendingRedSetup = widget.redSetup;
    _effectiveAiColor = widget.aiColor;
    _pendingPlayerColor =
        _effectiveAiColor == PieceColor.red ? PieceColor.blue : PieceColor.red;
    _customInitialBoard = widget.initialBoard?.copy();
    _customStartingPlayer = widget.initialStartingPlayer;
    _setupCompleted = widget.gameMode != GameMode.vsAI || _hasCustomStart;

    if (widget.gameMode == GameMode.vsAI) {
      _initEngine();
    } else {
      _engineInitialized = true;
    }
  }

  Future<void> _initEngine() async {
    try {
      StockfishFFI.init();
      setState(() {
        _engineInitialized = true;
      });
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
        aiThinkingTimeSec: widget.aiThinkingTimeSec,
        aiColor: _effectiveAiColor,
        blueSetup: _pendingBlueSetup,
        redSetup: _pendingRedSetup,
      )..applyCustomStartPosition(
          customBoard: _customInitialBoard,
          startingPlayer: _customStartingPlayer,
        ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5E6D3),
        body: SafeArea(
          child: Consumer<GameState>(
            builder: (context, gameState, child) {
              final settings = context.watch<SettingsProvider>();

              if (!gameState.isGameOver && _gameOverDialogShown) {
                _gameOverDialogShown = false;
              }

              const autoEngineSmoke = bool.fromEnvironment('AUTO_ENGINE_SMOKE',
                  defaultValue: false);
              if (autoEngineSmoke &&
                  widget.gameMode == GameMode.vsAI &&
                  _setupCompleted &&
                  _engineInitialized &&
                  !_autoSmokeTriggered) {
                _autoSmokeTriggered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await gameState.getHint();
                });
              }

              final aiIsRed = _effectiveAiColor == PieceColor.red;
              final aiName = 'AI (${gameState.aiDepth})';
              const playerName = '나 (Player)';
              final setupMode =
                  widget.gameMode == GameMode.vsAI && !_setupCompleted;

              final aiCaptured =
                  aiIsRed ? gameState.capturedByRed : gameState.capturedByBlue;
              final playerCaptured =
                  aiIsRed ? gameState.capturedByBlue : gameState.capturedByRed;

              return Stack(
                children: [
                  Column(
                    children: [
                      setupMode
                          ? _buildSetupInfoBar(gameState)
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 16,
                              ),
                              color: Colors.white70,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    gameState.statusMessage,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (gameState.isEngineThinking)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                ],
                              ),
                            ),
                      PlayerInfoBar(
                        name: aiName,
                        isTop: true,
                        capturedPieces: aiCaptured,
                        pieceColor: aiIsRed ? PieceColor.blue : PieceColor.red,
                        onTap: () => _showCapturedPiecesOverlay(
                          context,
                          aiCaptured,
                          '상대가 잡은 기물',
                        ),
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
                                        child: Stack(
                                          children: [
                                            JanggiBoardWidget(
                                              board: gameState.board,
                                              selectedPosition:
                                                  gameState.selectedPosition,
                                              validMoves: gameState.validMoves,
                                              onSquareTapped:
                                                  _engineInitialized &&
                                                          (widget.gameMode !=
                                                                  GameMode
                                                                      .vsAI ||
                                                              _setupCompleted)
                                                      ? gameState.onSquareTapped
                                                      : null,
                                              flipBoard: widget.gameMode ==
                                                      GameMode.vsAI &&
                                                  _effectiveAiColor ==
                                                      PieceColor.blue,
                                              animatingMove:
                                                  gameState.animatingMove,
                                              isAnimating:
                                                  gameState.isAnimating,
                                              animatingPiece:
                                                  gameState.animatingPiece,
                                              hintMove: !setupMode &&
                                                      gameState.showHint
                                                  ? gameState.hintMove
                                                  : null,
                                              boardSkin: settings.boardSkin,
                                              pieceSkin: settings.pieceSkin,
                                              showCoordinates:
                                                  settings.showCoordinates,
                                            ),
                                            if (setupMode)
                                              _buildBoardSetupOverlay(
                                                  gameState),
                                          ],
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
                        name: playerName,
                        isTop: false,
                        capturedPieces: playerCaptured,
                        pieceColor: aiIsRed ? PieceColor.red : PieceColor.blue,
                        onTap: () => _showCapturedPiecesOverlay(
                          context,
                          playerCaptured,
                          '내가 잡은 기물',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E2723),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildGameButton(
                                icon: Icons.home,
                                label: '메인',
                                color: Colors.white70,
                                onPressed: () {
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst);
                                },
                              ),
                              _buildGameButton(
                                icon: Icons.flag,
                                label: '기권',
                                color: Colors.redAccent,
                                onPressed: setupMode
                                    ? null
                                    : () => _showSurrenderDialog(
                                        context, gameState),
                              ),
                              _buildGameButton(
                                icon: Icons.lightbulb,
                                label: '힌트',
                                color: Colors.amber,
                                onPressed: !setupMode &&
                                        !gameState.isGameOver &&
                                        !gameState.isEngineThinking &&
                                        gameState.currentPlayer !=
                                            gameState.aiColor
                                    ? () async {
                                        if (gameState.showHint) {
                                          gameState.hideHint();
                                        } else {
                                          await gameState.getHint();
                                        }
                                      }
                                    : null,
                              ),
                              _buildGameButton(
                                icon: Icons.settings,
                                label: '설정',
                                color: Colors.white70,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SettingsScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildGameButton(
                                icon: Icons.undo,
                                label: '무르기',
                                color: Colors.blueAccent,
                                onPressed: !setupMode &&
                                        gameState.moveHistory.isNotEmpty
                                    ? () => gameState.undoMove()
                                    : null,
                              ),
                            ],
                          ),
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
                  if (gameState.isGameOver)
                    GameNotificationOverlay(
                      type: _getGameOverNotificationType(
                          gameState.gameOverReason),
                      onMainMenu: () => Navigator.of(context).pop(),
                      onRestart: () => _restartGame(gameState),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCapturedPiecesOverlay(
    BuildContext context,
    List<Piece> pieces,
    String title,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5E6D3),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: CapturedPiecesPanel(
            capturedPieces: pieces,
            backgroundImage: '',
            boardWidth: 300,
            isOverlay: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  NotificationType? _getGameOverNotificationType(String? reason) {
    if (reason == null) return null;

    final playerColor = widget.gameMode == GameMode.vsAI
        ? (_effectiveAiColor == PieceColor.red
            ? PieceColor.blue
            : PieceColor.red)
        : null;

    if (widget.gameMode == GameMode.vsAI) {
      if (reason.contains('blue_wins') && playerColor == PieceColor.blue) {
        return NotificationType.win;
      }
      if (reason.contains('red_wins') && playerColor == PieceColor.red) {
        return NotificationType.win;
      }
      if (reason.contains('wins')) {
        return NotificationType.lose;
      }
    } else {
      if (reason.contains('blue_wins') || reason.contains('red_wins')) {
        return NotificationType.win;
      }
    }

    return null;
  }

  Widget _buildSetupInfoBar(GameState gameState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: Colors.black.withValues(alpha: 0.68),
      child: Row(
        children: [
          const Text(
            'AI 난이도',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: gameState.aiDepth,
              dropdownColor: Colors.white,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1')),
                DropdownMenuItem(value: 3, child: Text('3')),
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 7, child: Text('7')),
                DropdownMenuItem(value: 9, child: Text('9')),
                DropdownMenuItem(value: 11, child: Text('11')),
                DropdownMenuItem(value: 13, child: Text('13')),
                DropdownMenuItem(value: 15, child: Text('15')),
              ],
              onChanged: _engineInitialized
                  ? (value) {
                      if (value == null) return;
                      gameState.setAIDifficulty(value);
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _pendingPlayerColor == PieceColor.blue ? '내 진영: 초' : '내 진영: 한',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardSetupOverlay(GameState gameState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const margin = 35.0;
        final innerWidth = constraints.maxWidth - (margin * 2);
        final gridSpacing = innerWidth / 8;
        final boardWidth = gridSpacing * 8;
        final boardHeight = gridSpacing * 9;
        final startX = margin;
        final startY = margin;
        final flipBoard = _effectiveAiColor == PieceColor.blue;
        final topSide = flipBoard ? PieceColor.blue : PieceColor.red;
        final bottomSide = flipBoard ? PieceColor.red : PieceColor.blue;

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
            _buildSetupControlButton(
              top: startY + gridSpacing * 0.2,
              left: startX + gridSpacing * 1.5 - 18,
              icon: Icons.swap_horiz,
              tooltip: '좌측 마/상 교환',
              onPressed: () => _toggleFlank(
                gameState: gameState,
                side: topSide,
                isLeft: true,
              ),
            ),
            _buildSetupControlButton(
              top: startY + gridSpacing * 0.2,
              left: startX + gridSpacing * 6.5 - 18,
              icon: Icons.swap_horiz,
              tooltip: '우측 마/상 교환',
              onPressed: () => _toggleFlank(
                gameState: gameState,
                side: topSide,
                isLeft: false,
              ),
            ),
            _buildSetupControlButton(
              top: startY + boardHeight - gridSpacing * 0.5,
              left: startX + gridSpacing * 1.5 - 18,
              icon: Icons.swap_horiz,
              tooltip: '좌측 마/상 교환',
              onPressed: () => _toggleFlank(
                gameState: gameState,
                side: bottomSide,
                isLeft: true,
              ),
            ),
            _buildSetupControlButton(
              top: startY + boardHeight - gridSpacing * 0.5,
              left: startX + gridSpacing * 6.5 - 18,
              icon: Icons.swap_horiz,
              tooltip: '우측 마/상 교환',
              onPressed: () => _toggleFlank(
                gameState: gameState,
                side: bottomSide,
                isLeft: false,
              ),
            ),
            _buildSetupControlButton(
              top: startY + boardHeight / 2 - 20,
              left: startX + boardWidth * 0.28 - 20,
              icon: Icons.swap_vert,
              tooltip: '내 진영 전환',
              onPressed: () => _togglePlayerSide(),
            ),
            Positioned(
              top: startY + boardHeight / 2 - 20,
              left: startX + boardWidth * 0.72 - 34,
              child: ElevatedButton.icon(
                onPressed: _engineInitialized
                    ? () => _applySetupAndStart(gameState)
                    : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4D1A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  minimumSize: const Size(68, 40),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSetupControlButton({
    required double top,
    required double left,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 20),
          tooltip: tooltip,
        ),
      ),
    );
  }

  void _toggleFlank({
    required GameState gameState,
    required PieceColor side,
    required bool isLeft,
  }) {
    if (side == PieceColor.blue) {
      final leftHorse = _isLeftHorseFirst(_pendingBlueSetup);
      final rightHorse = _isRightHorseFirst(_pendingBlueSetup);
      setState(() {
        _pendingBlueSetup = _setupFromFlags(
          isLeft ? !leftHorse : leftHorse,
          isLeft ? rightHorse : !rightHorse,
        );
      });
    } else {
      final leftHorse = _isLeftHorseFirst(_pendingRedSetup);
      final rightHorse = _isRightHorseFirst(_pendingRedSetup);
      setState(() {
        _pendingRedSetup = _setupFromFlags(
          isLeft ? !leftHorse : leftHorse,
          isLeft ? rightHorse : !rightHorse,
        );
      });
    }

    gameState.setPieceSetup(
      blueSetup: _pendingBlueSetup,
      redSetup: _pendingRedSetup,
    );
  }

  void _togglePlayerSide() {
    setState(() {
      _pendingPlayerColor = _pendingPlayerColor == PieceColor.blue
          ? PieceColor.red
          : PieceColor.blue;
      _effectiveAiColor = _pendingPlayerColor == PieceColor.blue
          ? PieceColor.red
          : PieceColor.blue;
    });
  }

  bool _isLeftHorseFirst(PieceSetup setup) {
    return setup == PieceSetup.horseElephantElephantHorse ||
        setup == PieceSetup.horseElephantHorseElephant;
  }

  bool _isRightHorseFirst(PieceSetup setup) {
    return setup == PieceSetup.elephantHorseHorseElephant ||
        setup == PieceSetup.horseElephantHorseElephant;
  }

  PieceSetup _setupFromFlags(bool leftHorseFirst, bool rightHorseFirst) {
    if (!leftHorseFirst && rightHorseFirst) {
      return PieceSetup.elephantHorseHorseElephant;
    }
    if (!leftHorseFirst && !rightHorseFirst) {
      return PieceSetup.elephantHorseElephantHorse;
    }
    if (leftHorseFirst && !rightHorseFirst) {
      return PieceSetup.horseElephantElephantHorse;
    }
    return PieceSetup.horseElephantHorseElephant;
  }

  void _applySetupAndStart(GameState gameState) {
    final aiColor = _pendingPlayerColor == PieceColor.blue
        ? PieceColor.red
        : PieceColor.blue;

    _effectiveAiColor = aiColor;
    gameState.setAIColor(aiColor);
    gameState.setPieceSetup(
      blueSetup: _pendingBlueSetup,
      redSetup: _pendingRedSetup,
    );

    setState(() {
      _setupCompleted = true;
    });
  }

  void _restartGame(GameState gameState) {
    if (_hasCustomStart) {
      gameState.setPuzzlePosition(
        _customInitialBoard!.copy(),
        _customStartingPlayer!,
      );
      return;
    }
    gameState.newGame();
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
            '기권하면 상대 승리로 처리됩니다.\n정말 기권하시겠습니까?',
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
                final winningColor =
                    gameState.currentPlayer == PieceColor.blue ? 'red' : 'blue';
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
