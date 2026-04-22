import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../monetization/monetization_config.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/rule_mode.dart';
import '../providers/monetization_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/settings_screen.dart';
import '../stockfish_ffi.dart';
import '../widgets/ad_banner_slot.dart';
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
  final RuleMode ruleMode;
  final Board? initialBoard;
  final PieceColor? initialStartingPlayer;
  final bool showInGameSetup;

  const GameScreen({
    super.key,
    this.gameMode = GameMode.vsAI,
    this.aiDifficulty = 5,
    this.aiThinkingTimeSec = 5,
    this.aiColor = PieceColor.red,
    this.blueSetup = PieceSetup.horseElephantHorseElephant,
    this.redSetup = PieceSetup.horseElephantHorseElephant,
    this.ruleMode = RuleMode.casualDefault,
    this.initialBoard,
    this.initialStartingPlayer,
    this.showInGameSetup = false,
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
    _setupCompleted = _hasCustomStart || !widget.showInGameSetup;

    if (widget.gameMode == GameMode.vsAI) {
      _initEngine();
    } else {
      _engineInitialized = true;
    }
  }

  Future<void> _initEngine() async {
    try {
      await StockfishFFI.warmupIsolated(
        variant: widget.ruleMode.engineVariantName,
      );
      if (!mounted) return;
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
        ruleMode: widget.ruleMode,
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
              final monetization = context.watch<MonetizationProvider>();

              if (gameState.isGameOver && !_gameOverDialogShown) {
                _gameOverDialogShown = true;
                unawaited(context
                    .read<MonetizationProvider>()
                    .registerGameCompleted());
              }

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
                      if (MonetizationConfig.enableInGameTopBanner)
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 4),
                          child: Center(child: AdBannerSlot()),
                        ),
                      setupMode
                          ? _buildSetupInfoBar(gameState, monetization)
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
                        pieceSkin: settings.pieceSkin,
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
                                  vertical: 18,
                                  horizontal: 2,
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
                        pieceSkin: settings.pieceSkin,
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
                                icon: Icons.skip_next,
                                label: '\uD55C\uC218\uC26C',
                                color: Colors.tealAccent,
                                onPressed: !setupMode &&
                                        !gameState.isGameOver &&
                                        !gameState.isEngineThinking &&
                                        gameState.currentPlayer !=
                                            gameState.aiColor &&
                                        gameState.canPass
                                    ? () async {
                                        await gameState.passTurn();
                                      }
                                    : null,
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
                      onMainMenu: () {
                        unawaited(_runGameOverAction(() {
                          Navigator.of(context).pop();
                        }));
                      },
                      onRestart: () {
                        unawaited(_runGameOverAction(() {
                          _restartGame(gameState);
                        }));
                      },
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
    final pieceSkin = context.read<SettingsProvider>().pieceSkin;
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
            pieceSkin: pieceSkin,
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

  Widget _buildSetupInfoBar(
    GameState gameState,
    MonetizationProvider monetization,
  ) {
    const difficultyValues = [1, 3, 5, 7, 9, 11, 13, 15];
    final effectiveDepth =
        monetization.enforceDifficultyLimit(gameState.aiDepth);

    if (effectiveDepth != gameState.aiDepth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        gameState.setAIDifficulty(effectiveDepth);
      });
    }

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
              value: effectiveDepth,
              dropdownColor: const Color(0xFF1F1F1F),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              iconEnabledColor: Colors.white,
              iconDisabledColor: Colors.white54,
              items: difficultyValues.map((value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(
                    '$value',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
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

  Future<void> _runGameOverAction(VoidCallback action) async {
    final monetization = context.read<MonetizationProvider>();
    await monetization.maybeShowEndGameInterstitial();
    if (!mounted) return;
    action();
  }

  Widget _buildBoardSetupOverlay(GameState gameState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const margin = 35.0;
        final innerWidth = constraints.maxWidth - (margin * 2);
        final gridSpacing = innerWidth / 8;
        final boardLeft = margin;
        final boardTop = margin;
        final topSide = _effectiveAiColor;
        final bottomSide =
            topSide == PieceColor.blue ? PieceColor.red : PieceColor.blue;

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
                  color: Colors.black.withValues(alpha: 0.06),
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
                label: '진형변경',
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
                label: '시작',
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
    final isTextButton = label != null;

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
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: isTextButton
                    ? const Color(0xFFC59B63)
                    : const Color(0xFF7B5A37).withValues(alpha: 0.9),
                border: Border.all(
                  color: isTextButton
                      ? const Color(0xFFF3E1BF)
                      : const Color(0xFFE8D5B5).withValues(alpha: 0.8),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: _buildSetupButtonContent(
                  icon: icon,
                  label: label,
                  isTextButton: isTextButton,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupButtonContent({
    required IconData? icon,
    required String? label,
    required bool isTextButton,
  }) {
    if (label != null && icon == null) {
      return Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: isTextButton ? const Color(0xFF2E1D11) : Colors.white,
          letterSpacing: 0.05,
        ),
      );
    }

    if (icon != null && label == null) {
      return Icon(
        icon,
        size: 16,
        color: Colors.white,
      );
    }

    if (icon != null && label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isTextButton ? const Color(0xFF2E1D11) : Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isTextButton ? const Color(0xFF2E1D11) : Colors.white,
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
}
