import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/position.dart';
import '../providers/settings_provider.dart';
import '../screens/game_screen.dart' show GameMode;
import '../stockfish_ffi.dart';
import '../utils/gib_parser.dart';
import '../widgets/evaluation_bar.dart';
import '../widgets/game_notification_overlay.dart';
import '../widgets/janggi_board_widget.dart';
import '../widgets/player_info_bar.dart';

/// Puzzle play screen.
/// Player controls only the side to move in puzzle data.
/// Opponent moves are auto-played from the solution line.
class PuzzleGameScreen extends StatefulWidget {
  final Map<String, dynamic> game;

  const PuzzleGameScreen({
    super.key,
    required this.game,
  });

  @override
  State<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends State<PuzzleGameScreen> {
  late final GameState _gameState;

  bool _isInitialized = false;
  bool _isAutoPlaying = false;
  bool _isResolvingWrongMove = false;
  bool _completionDialogShown = false;

  List<String> _solutionMoves = <String>[];
  int _solutionStartIndex = 0;
  int _solutionIndex = 0; // next expected move index in _solutionMoves
  int _lastValidatedMoveCount = 0;

  PieceColor _playerColor = PieceColor.blue;
  String? _wrongMoveMessage;

  @override
  void initState() {
    super.initState();
    StockfishFFI.init();
    _gameState = GameState(gameMode: GameMode.twoPlayer);
    _gameState.addListener(_onGameStateChanged);
    _initializePuzzle();
  }

  @override
  void dispose() {
    _gameState.removeListener(_onGameStateChanged);
    _gameState.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (!_isInitialized) return;

    final historyLength = _gameState.moveHistory.length;

    // Keep local progress in sync when user undoes moves.
    if (historyLength < _lastValidatedMoveCount) {
      _lastValidatedMoveCount = historyLength;
      final replayed = (_solutionStartIndex + historyLength)
          .clamp(_solutionStartIndex, _solutionMoves.length);
      _solutionIndex = replayed;
      _completionDialogShown = false;
      setState(() {
        _wrongMoveMessage = null;
      });
      return;
    }

    if (_isResolvingWrongMove) return;
    if (historyLength == _lastValidatedMoveCount) return;
    if (_solutionIndex >= _solutionMoves.length) return;
    if (historyLength == 0) return;

    final expectedMove = _parseSolutionMove(_solutionMoves[_solutionIndex]);
    final actualMove = _gameState.moveHistory.last;

    final isCorrect = expectedMove != null &&
        actualMove.from == expectedMove.from &&
        actualMove.to == expectedMove.to;

    if (!isCorrect) {
      _handleWrongMove();
      return;
    }

    _lastValidatedMoveCount = historyLength;
    _solutionIndex++;

    setState(() {
      _wrongMoveMessage = null;
    });

    if (_solutionIndex >= _solutionMoves.length) {
      _showPuzzleCompleteDialogOnce();
      return;
    }

    _playOpponentMoveIfNeeded();
  }

  Future<void> _initializePuzzle() async {
    try {
      _isInitialized = false;
      _isAutoPlaying = false;
      _isResolvingWrongMove = false;
      _completionDialogShown = false;
      _wrongMoveMessage = null;
      _lastValidatedMoveCount = 0;

      final fen = widget.game['fen'] as String?;
      final solution = widget.game['solution'] as List<dynamic>?;

      if (fen != null && solution != null && solution.isNotEmpty) {
        _solutionMoves = List<String>.from(solution);
        _solutionStartIndex = 0;
        _solutionIndex = 0;

        final toMove = widget.game['toMove'] as String? ?? 'blue';
        _playerColor = toMove == 'red' ? PieceColor.red : PieceColor.blue;

        _gameState.setPositionFromFen(fen, _playerColor);

        setState(() {
          _isInitialized = true;
        });

        _playOpponentMoveIfNeeded();
        return;
      }

      // Legacy path: full game move list, start from discovered puzzle point.
      final moves = List<String>.from(widget.game['moves'] ?? []);
      if (moves.isEmpty) return;

      _solutionMoves = moves;
      _solutionStartIndex = await GibParser.findPuzzleStartPosition(moves);
      _solutionIndex = _solutionStartIndex;

      final board =
          GibParser.replayMovesToPosition(moves, upToMove: _solutionStartIndex);
      if (board == null) return;

      final nextMoveNumber = _solutionStartIndex + 1;
      _playerColor =
          (nextMoveNumber % 2 == 1) ? PieceColor.red : PieceColor.blue;

      _gameState.setPuzzlePosition(board, _playerColor);

      setState(() {
        _isInitialized = true;
      });

      _playOpponentMoveIfNeeded();
    } catch (e) {
      debugPrint('Error initializing puzzle: $e');
    }
  }

  Future<void> _playOpponentMoveIfNeeded() async {
    if (!_isInitialized || !mounted) return;
    if (_isAutoPlaying || _isResolvingWrongMove) return;
    if (_solutionIndex >= _solutionMoves.length) return;
    if (_gameState.currentPlayer == _playerColor) return;

    final expectedMove = _parseSolutionMove(_solutionMoves[_solutionIndex]);
    if (expectedMove == null) {
      debugPrint(
          'Cannot parse solution move: ${_solutionMoves[_solutionIndex]}');
      return;
    }

    final piece = _gameState.board.getPiece(expectedMove.from);
    if (piece == null || piece.color != _gameState.currentPlayer) {
      debugPrint('Auto move mismatch at index $_solutionIndex');
      return;
    }

    _isAutoPlaying = true;
    if (mounted) setState(() {});

    try {
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted || !_isInitialized) return;

      await _gameState.onSquareTapped(expectedMove.from);
      await _gameState.onSquareTapped(expectedMove.to);
    } finally {
      _isAutoPlaying = false;
      if (mounted) setState(() {});
    }
  }

  void _handleWrongMove() {
    if (_isResolvingWrongMove) return;
    _isResolvingWrongMove = true;

    setState(() {
      _wrongMoveMessage = '오답입니다. 다시 시도하세요.';
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _wrongMoveMessage = null;
      });
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      if (_gameState.moveHistory.length > _lastValidatedMoveCount) {
        _gameState.undoMove();
      }

      _isResolvingWrongMove = false;
    });
  }

  void _resetPuzzle() {
    setState(() {
      _isInitialized = false;
      _solutionMoves = <String>[];
      _solutionStartIndex = 0;
      _solutionIndex = 0;
      _lastValidatedMoveCount = 0;
      _wrongMoveMessage = null;
      _completionDialogShown = false;
    });
    _initializePuzzle();
  }

  void _undoPuzzleTurn() {
    if (_isAutoPlaying || _isResolvingWrongMove) return;
    if (_gameState.moveHistory.isEmpty) return;

    // If it's currently player's turn, opponent likely just moved.
    if (_gameState.currentPlayer == _playerColor &&
        _gameState.moveHistory.isNotEmpty) {
      _gameState.undoMove();
    }

    if (_gameState.moveHistory.isNotEmpty) {
      _gameState.undoMove();
    }
  }

  Future<void> _handleBoardTap(Position position) async {
    if (!_canPlayerMove()) return;
    await _gameState.onSquareTapped(position);
  }

  bool _canPlayerMove() {
    return _isInitialized &&
        !_isAutoPlaying &&
        !_isResolvingWrongMove &&
        _gameState.currentPlayer == _playerColor;
  }

  int _playerSolvedMoveCount() {
    final completedMoves = (_solutionIndex - _solutionStartIndex).clamp(
      0,
      (_solutionMoves.length - _solutionStartIndex)
          .clamp(0, _solutionMoves.length),
    );
    return (completedMoves + 1) ~/ 2;
  }

  int _playerTotalMoveCount() {
    final totalMoves = (_solutionMoves.length - _solutionStartIndex).clamp(
      0,
      _solutionMoves.length,
    );
    return (totalMoves + 1) ~/ 2;
  }

  PieceColor _oppositeColor(PieceColor color) {
    return color == PieceColor.blue ? PieceColor.red : PieceColor.blue;
  }

  String _sideLabel(PieceColor color) {
    return color == PieceColor.blue ? '초' : '한';
  }

  void _showPuzzleCompleteDialogOnce() {
    if (_completionDialogShown) return;
    _completionDialogShown = true;

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _showPuzzleCompleteDialog();
    });
  }

  void _showPuzzleCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('퍼즐 완료'),
        content: const Text('정답 수순을 모두 맞혔습니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('목록으로'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetPuzzle();
            },
            child: const Text('다시 하기'),
          ),
        ],
      ),
    );
  }

  Move? _parseSolutionMove(String rawMove) {
    final move = rawMove.trim();

    final uciMatch = RegExp(
      r'^([a-i])(10|[1-9])([a-i])(10|[1-9])$',
      caseSensitive: false,
    ).firstMatch(move);

    if (uciMatch != null) {
      final from = _parseUciSquare('${uciMatch.group(1)}${uciMatch.group(2)}');
      final to = _parseUciSquare('${uciMatch.group(3)}${uciMatch.group(4)}');
      if (from != null && to != null) {
        return Move(from: from, to: to);
      }
    }

    final gib = GibParser.parseGibMove(move);
    if (gib != null) {
      return Move(from: gib['from']!, to: gib['to']!);
    }

    return null;
  }

  Position? _parseUciSquare(String square) {
    if (square.length < 2) return null;

    final fileCode = square[0].toLowerCase().codeUnitAt(0);
    final minFile = 'a'.codeUnitAt(0);
    final maxFile = 'i'.codeUnitAt(0);
    if (fileCode < minFile || fileCode > maxFile) return null;

    final rank = int.tryParse(square.substring(1));
    if (rank == null || rank < 1 || rank > 10) return null;

    return Position(
      file: fileCode - minFile,
      rank: rank - 1,
    );
  }

  void _toggleHint() {
    if (_gameState.showHint) {
      _gameState.hideHint();
      return;
    }

    if (!_canPlayerMove()) return;
    if (_solutionIndex >= _solutionMoves.length) return;

    final move = _parseSolutionMove(_solutionMoves[_solutionIndex]);
    if (move != null) {
      _gameState.setManualHint(move.from, move.to);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameState>.value(
      value: _gameState,
      child: Scaffold(
        backgroundColor: const Color(0xFFf5e6d3),
        body: SafeArea(
          child: !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Consumer<GameState>(
                  builder: (context, gameState, child) {
                    final settings = context.watch<SettingsProvider>();
                    final playerColor = _playerColor;
                    final opponentColor = _oppositeColor(playerColor);
                    final flipBoard = playerColor == PieceColor.red;

                    final topColor = opponentColor;
                    final bottomColor = playerColor;
                    final topCaptured = topColor == PieceColor.red
                        ? gameState.capturedByRed
                        : gameState.capturedByBlue;
                    final bottomCaptured = bottomColor == PieceColor.red
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
                                    icon: const Icon(Icons.arrow_back,
                                        color: Colors.white),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.game['title'] ?? '퍼즐',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '진행: ${_playerSolvedMoveCount()} / ${_playerTotalMoveCount()}',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PlayerInfoBar(
                              name: '${_sideLabel(topColor)} (AI)',
                              isTop: true,
                              capturedPieces: topCaptured,
                              pieceColor: _oppositeColor(topColor),
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
                                                validMoves:
                                                    gameState.validMoves,
                                                onSquareTapped: _canPlayerMove()
                                                    ? _handleBoardTap
                                                    : null,
                                                flipBoard: flipBoard,
                                                animatingMove:
                                                    gameState.animatingMove,
                                                isAnimating:
                                                    gameState.isAnimating,
                                                animatingPiece:
                                                    gameState.animatingPiece,
                                                hintMove: gameState.showHint
                                                    ? gameState.hintMove
                                                    : null,
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
                              name: '${_sideLabel(bottomColor)} (Player)',
                              isTop: false,
                              capturedPieces: bottomCaptured,
                              pieceColor: _oppositeColor(bottomColor),
                              onTap: () {},
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 16),
                              decoration: const BoxDecoration(
                                color: Color(0xFF3e2723),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildGameButton(
                                    icon: Icons.refresh,
                                    label: '다시 시작',
                                    color: Colors.white,
                                    onPressed: _resetPuzzle,
                                  ),
                                  _buildGameButton(
                                    icon: Icons.lightbulb,
                                    label: '힌트',
                                    color: Colors.amber,
                                    onPressed:
                                        _canPlayerMove() ? _toggleHint : null,
                                  ),
                                  _buildGameButton(
                                    icon: Icons.undo,
                                    label: '무르기',
                                    color: Colors.blueAccent,
                                    onPressed: gameState.moveHistory.isNotEmpty
                                        ? _undoPuzzleTurn
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (gameState.showCheckNotification)
                          const GameNotificationOverlay(
                            type: NotificationType.check,
                          ),
                        if (gameState.showEscapeCheckNotification)
                          const GameNotificationOverlay(
                            type: NotificationType.escapeCheck,
                          ),
                        if (_wrongMoveMessage != null)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _wrongMoveMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
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

  Widget _buildGameButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          color: onPressed != null ? color : Colors.grey,
          iconSize: 32,
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onPressed != null ? color : Colors.grey,
          ),
        ),
      ],
    );
  }
}
