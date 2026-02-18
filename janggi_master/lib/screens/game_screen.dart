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
    _setupCompleted = _hasCustomStart;

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
              final aiName = widget.gameMode == GameMode.twoPlayer
                  ? '\uC624\uD504\uB77C\uC778'
                  : 'AI (${gameState.aiDepth})';
              const playerName = '나 (Player)';
              final supportsSetup = widget.gameMode == GameMode.vsAI ||
                  widget.gameMode == GameMode.twoPlayer;
              final setupMode = supportsSetup && !_setupCompleted;

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
                                                          !setupMode
                                                      ? gameState.onSquareTapped
                                                      : null,
                                              flipBoard: _effectiveAiColor ==
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
                                label: '\uBA54\uC778',
                                color: Colors.white70,
                                onPressed: () {
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst);
                                },
                              ),
                              _buildGameButton(
                                icon: Icons.flag,
                                label: '\uAE30\uAD8C',
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
                                label: '\uBB34\uB974\uAE30',
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
            'AI \uB09C\uC774\uB3C4',
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
              dropdownColor: const Color(0xFF1F1F1F),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              iconEnabledColor: Colors.white,
              iconDisabledColor: Colors.white54,
              items: const [
                DropdownMenuItem(
                    value: 1,
                    child: Text('1', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: 3,
                    child: Text('3', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: 5,
                    child: Text('5', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: 7,
                    child: Text('7', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: 9,
                    child: Text('9', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: 11,
                    child: Text('11', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: 13,
                    child: Text('13', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: 15,
                    child: Text('15', style: TextStyle(color: Colors.white))),
              ],
              onChanged: widget.gameMode == GameMode.vsAI && _engineInitialized
                  ? (value) {
                      if (value == null) return;
                      gameState.setAIDifficulty(value);
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _pendingPlayerColor == PieceColor.blue
                ? '\uB0B4 \uC9C4\uC601: \uCD08'
                : '\uB0B4 \uC9C4\uC601: \uD55C',
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
        final boardLeft = margin;
        final boardTop = margin;
        final flipBoard = _effectiveAiColor == PieceColor.blue;
        final topSide = flipBoard ? PieceColor.blue : PieceColor.red;
        final bottomSide = flipBoard ? PieceColor.red : PieceColor.blue;

        const controlWidth = 78.0;
        const controlHeight = 34.0;

        final topSwapY = boardTop + (gridSpacing * 1) - (controlHeight / 2);
        final bottomSwapY = boardTop + (gridSpacing * 8) - (controlHeight / 2);
        final sideActionY =
            boardTop + (gridSpacing * 4.5) - (controlHeight / 2);

        final leftColumnCenterX = boardLeft + (gridSpacing * 1.5) + 2;
        final rightColumnCenterX = boardLeft + (gridSpacing * 6.5) + 2;
        final leftColumnX = leftColumnCenterX - (controlWidth / 2);
        final rightColumnX = rightColumnCenterX - (controlWidth / 2);

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              top: topSwapY,
              left: leftColumnX,
              child: _buildSetupActionButton(
                width: controlWidth,
                height: controlHeight,
                icon: Icons.swap_horiz_rounded,
                label: null,
                onPressed: () => _toggleFlank(
                  gameState: gameState,
                  side: topSide,
                  isLeft: true,
                ),
              ),
            ),
            Positioned(
              top: topSwapY,
              left: rightColumnX,
              child: _buildSetupActionButton(
                width: controlWidth,
                height: controlHeight,
                icon: Icons.swap_horiz_rounded,
                label: null,
                onPressed: () => _toggleFlank(
                  gameState: gameState,
                  side: topSide,
                  isLeft: false,
                ),
              ),
            ),
            Positioned(
              top: bottomSwapY,
              left: leftColumnX,
              child: _buildSetupActionButton(
                width: controlWidth,
                height: controlHeight,
                icon: Icons.swap_horiz_rounded,
                label: null,
                onPressed: () => _toggleFlank(
                  gameState: gameState,
                  side: bottomSide,
                  isLeft: true,
                ),
              ),
            ),
            Positioned(
              top: bottomSwapY,
              left: rightColumnX,
              child: _buildSetupActionButton(
                width: controlWidth,
                height: controlHeight,
                icon: Icons.swap_horiz_rounded,
                label: null,
                onPressed: () => _toggleFlank(
                  gameState: gameState,
                  side: bottomSide,
                  isLeft: false,
                ),
              ),
            ),
            Positioned(
              top: sideActionY,
              left: leftColumnX,
              child: _buildSetupActionButton(
                width: controlWidth,
                height: controlHeight,
                icon: null,
                label: '\uC9C4\uD615\uBCC0\uACBD',
                onPressed: _togglePlayerSide,
              ),
            ),
            Positioned(
              top: sideActionY,
              left: rightColumnX,
              child: _buildSetupActionButton(
                width: controlWidth,
                height: controlHeight,
                icon: null,
                label: '\uC2DC\uC791',
                onPressed: _engineInitialized
                    ? () => _applySetupAndStart(gameState)
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSetupActionButton({
    required double width,
    required double height,
    required IconData? icon,
    required String? label,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(height / 2);

    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFDFC096),
                          Color(0xFFB78956),
                          Color(0xFF7D5634),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFECD9B9).withValues(alpha: 0.95),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.44),
                          blurRadius: 8,
                          offset: const Offset(1.3, 2.3),
                        ),
                        BoxShadow(
                          color:
                              const Color(0xFFFFEFD2).withValues(alpha: 0.24),
                          blurRadius: 3,
                          offset: const Offset(-0.8, -0.8),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(1.6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular((height / 2) - 2),
                      border: Border.all(
                        color: const Color(0xFF5B3D26).withValues(alpha: 0.42),
                        width: 0.9,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: Center(
                    child: _buildSetupButtonContent(icon: icon, label: label),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupButtonContent({
    required IconData? icon,
    required String? label,
  }) {
    Widget buildIcon(IconData data) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, 0.8),
            child: Icon(
              data,
              size: 15,
              color: Colors.black.withValues(alpha: 0.52),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -0.5),
            child: Icon(
              data,
              size: 15,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          Icon(
            data,
            size: 14.5,
            color: const Color(0xFF2E1D11).withValues(alpha: 0.9),
          ),
        ],
      );
    }

    if (label != null && icon == null) {
      return Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.6,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF2E1D11).withValues(alpha: 0.92),
          letterSpacing: 0.05,
        ),
      );
    }

    if (icon != null && label == null) {
      return buildIcon(icon);
    }

    if (icon != null && label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildIcon(icon),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.2,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2E1D11).withValues(alpha: 0.92),
              letterSpacing: 0.1,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
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
            '\uAE30\uAD8C\uD558\uBA74 \uC0C1\uB300 \uC2B9\uB9AC\uB85C \uCC98\uB9AC\uB429\uB2C8\uB2E4.\n'
            '\uC815\uB9D0 \uAE30\uAD8C\uD558\uC2DC\uACA0\uC2B5\uB2C8\uAE4C?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('\uCDE8\uC18C'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final winningColor =
                    gameState.currentPlayer == PieceColor.blue ? 'red' : 'blue';
                gameState.testGameOver('${winningColor}_wins_capture');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                '\uAE30\uAD8C',
                style: TextStyle(color: Colors.white),
              ),
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
