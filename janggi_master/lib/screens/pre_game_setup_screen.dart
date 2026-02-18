import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';
import '../providers/settings_provider.dart';
import '../widgets/janggi_board_widget.dart' show BoardLinesPainter;
import '../widgets/traditional_piece_widget.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

class PreGameSetupScreen extends StatefulWidget {
  final GameMode gameMode;

  const PreGameSetupScreen({super.key, required this.gameMode});

  @override
  State<PreGameSetupScreen> createState() => _PreGameSetupScreenState();
}

class _PreGameSetupScreenState extends State<PreGameSetupScreen> {
  PieceSetup _blueSetup = PieceSetup.horseElephantHorseElephant;
  PieceSetup _redSetup = PieceSetup.horseElephantHorseElephant;
  PieceColor _playerColor = PieceColor.blue;

  Board _previewBoard() {
    final board = Board();
    board.setupInitialPosition(blueSetup: _blueSetup, redSetup: _redSetup);
    return board;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
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
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black.withValues(alpha: 0.72),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.gameMode == GameMode.vsAI
                            ? '\u0041\u0049 \uB300\uAD6D \uC2DC\uC791 \uC124\uC815'
                            : '\uC624\uD504\uB77C\uC778 \uB300\uAD6D \uC2DC\uC791 \uC124\uC815',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      tooltip: '설정',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (widget.gameMode == GameMode.vsAI)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI 설정(설정 화면에서 변경)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('AI 난이도: depth ${settings.aiDifficulty}'),
                      Text('AI 생각시간: 최대 ${settings.aiThinkingTime}초'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('내 진영: '),
                          const SizedBox(width: 8),
                          SegmentedButton<PieceColor>(
                            segments: const [
                              ButtonSegment(
                                value: PieceColor.blue,
                                label: Text('초'),
                              ),
                              ButtonSegment(
                                value: PieceColor.red,
                                label: Text('한'),
                              ),
                            ],
                            selected: <PieceColor>{_playerColor},
                            onSelectionChanged: (selection) {
                              setState(() {
                                _playerColor = selection.first;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '장기판 위에서 바로 배치 설정',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 9 / 10,
                          child: _buildBoardSetupArea(settings),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '말/상 위치는 각 화살표(<->)로 변경하고, 가운데 ↑↓ 버튼으로 초/한 배치를 통째로 교환합니다.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
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

  Widget _buildBoardSetupArea(SettingsProvider settings) {
    final board = _previewBoard();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6C8A0),
        border: Border.all(color: Colors.brown.shade700, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const margin = 34.0;
          final innerWidth = constraints.maxWidth - margin * 2;
          final innerHeight = constraints.maxHeight - margin * 2;
          final gridSpacing = (innerWidth / 8 < innerHeight / 9
                  ? innerWidth / 8
                  : innerHeight / 9)
              .toDouble();
          final boardWidth = gridSpacing * 8;
          final boardHeight = gridSpacing * 9;
          final startX = (constraints.maxWidth - boardWidth) / 2;
          final startY = (constraints.maxHeight - boardHeight) / 2;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Image.asset(
                    'assets/images/janggi_pan.png',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.78),
                  ),
                ),
              ),
              Positioned(
                left: startX,
                top: startY,
                child: CustomPaint(
                  size: Size(boardWidth, boardHeight),
                  painter: BoardLinesPainter(
                    gridSpacing: gridSpacing,
                    flipBoard: false,
                    lineColor: Colors.black87,
                  ),
                ),
              ),
              ..._buildPreviewPieces(board, startX, startY, gridSpacing),
              _buildFlankButton(
                top: startY - gridSpacing * 0.55,
                left: startX + gridSpacing * 1.5 - 18,
                onPressed: () => _toggleFlank(PieceColor.red, true),
              ),
              _buildFlankButton(
                top: startY - gridSpacing * 0.55,
                left: startX + gridSpacing * 6.5 - 18,
                onPressed: () => _toggleFlank(PieceColor.red, false),
              ),
              _buildFlankButton(
                top: startY + gridSpacing * 9 + gridSpacing * 0.15,
                left: startX + gridSpacing * 1.5 - 18,
                onPressed: () => _toggleFlank(PieceColor.blue, true),
              ),
              _buildFlankButton(
                top: startY + gridSpacing * 9 + gridSpacing * 0.15,
                left: startX + gridSpacing * 6.5 - 18,
                onPressed: () => _toggleFlank(PieceColor.blue, false),
              ),
              Positioned(
                left: startX + boardWidth / 2 - 54,
                top: startY + boardHeight / 2 - 18,
                child: Row(
                  children: [
                    Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: _swapSides,
                        icon: const Icon(Icons.swap_vert, color: Colors.white),
                        tooltip: '초/한 배치 교환',
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _startGame(settings),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('시작'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A4D1A),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPreviewPieces(
    Board board,
    double startX,
    double startY,
    double gridSpacing,
  ) {
    final widgets = <Widget>[];

    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = board.getPiece(Position(file: file, rank: rank));
        if (piece == null) continue;
        final displayRank = 9 - rank;
        final x = startX + file * gridSpacing;
        final y = startY + displayRank * gridSpacing;
        final size = gridSpacing * 0.82;

        widgets.add(
          Positioned(
            left: x - size / 2,
            top: y - size / 2,
            width: size,
            height: size,
            child: IgnorePointer(
              child: TraditionalPieceWidget(piece: piece, size: size),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildFlankButton({
    required double top,
    required double left,
    required VoidCallback onPressed,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
          tooltip: '마/상 위치 교환',
        ),
      ),
    );
  }

  void _toggleFlank(PieceColor side, bool isLeft) {
    if (side == PieceColor.blue) {
      final leftHorse = _isLeftHorseFirst(_blueSetup);
      final rightHorse = _isRightHorseFirst(_blueSetup);
      setState(() {
        _blueSetup = _setupFromFlags(
          isLeft ? !leftHorse : leftHorse,
          isLeft ? rightHorse : !rightHorse,
        );
      });
      return;
    }

    final leftHorse = _isLeftHorseFirst(_redSetup);
    final rightHorse = _isRightHorseFirst(_redSetup);
    setState(() {
      _redSetup = _setupFromFlags(
        isLeft ? !leftHorse : leftHorse,
        isLeft ? rightHorse : !rightHorse,
      );
    });
  }

  void _swapSides() {
    setState(() {
      final tmp = _blueSetup;
      _blueSetup = _redSetup;
      _redSetup = tmp;
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

  void _startGame(SettingsProvider settings) {
    final aiColor =
        _playerColor == PieceColor.blue ? PieceColor.red : PieceColor.blue;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          gameMode: widget.gameMode,
          aiDifficulty: settings.aiDifficulty,
          aiThinkingTimeSec: settings.aiThinkingTime,
          aiColor: widget.gameMode == GameMode.vsAI ? aiColor : PieceColor.red,
          blueSetup: _blueSetup,
          redSetup: _redSetup,
        ),
      ),
    );
  }
}
