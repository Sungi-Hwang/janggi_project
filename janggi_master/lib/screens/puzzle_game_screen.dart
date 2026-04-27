import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/position.dart';
import '../models/puzzle_objective.dart';
import '../providers/settings_provider.dart';
import '../screens/game_screen.dart' show GameMode;
import '../services/puzzle_progress_service.dart';
import '../utils/gib_parser.dart';
import '../utils/gib_puzzle_locator.dart';
import '../widgets/evaluation_bar.dart';
import '../widgets/game_notification_overlay.dart';
import '../widgets/janggi_board_widget.dart';
import '../widgets/player_info_bar.dart';

/// Puzzle play screen.
/// Player controls the side to move in the puzzle.
/// If the player deviates from the stored line, the puzzle still succeeds
/// as long as the opponent has no legal reply within the allowed player moves.
class PuzzleGameScreen extends StatefulWidget {
  const PuzzleGameScreen({
    super.key,
    required this.game,
  });

  final Map<String, dynamic> game;

  @override
  State<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends State<PuzzleGameScreen> {
  late final GameState _gameState;

  bool _isInitialized = false;
  bool _isAutoPlaying = false;
  bool _isResolvingWrongMove = false;
  bool _completionDialogShown = false;
  bool _attemptResultRecorded = false;

  List<String> _solutionMoves = <String>[];
  int _solutionStartIndex = 0;
  int _solutionIndex = 0;
  int _lastValidatedMoveCount = 0;
  int _targetPlayerMoveCount = 0;
  bool _isFollowingSolutionLine = true;

  PieceColor _playerColor = PieceColor.blue;
  String _objectiveType = PuzzleObjective.mate;
  Map<String, dynamic> _objective = <String, dynamic>{};
  MaterialGainRuntimeResult? _materialGainResult;
  String? _wrongMoveMessage;

  @override
  void initState() {
    super.initState();
    _gameState = GameState(
      gameMode: GameMode.twoPlayer,
      ruleMode: context.read<SettingsProvider>().ruleMode,
    );
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

    if (historyLength < _lastValidatedMoveCount) {
      _recomputeProgressFromHistory();
      _completionDialogShown = false;
      if (mounted) {
        setState(() {
          _wrongMoveMessage = null;
        });
      }
      return;
    }

    if (_isResolvingWrongMove || historyLength == _lastValidatedMoveCount) {
      return;
    }
    if (historyLength == 0) {
      return;
    }

    _recomputeProgressFromHistory();

    if (_handleMaterialGainProgress()) {
      return;
    }

    if (_isPuzzleSolvedByNoEscape()) {
      if (mounted) {
        setState(() {
          _wrongMoveMessage = null;
        });
      }
      _showPuzzleCompleteDialogOnce();
      return;
    }

    if (_gameState.currentPlayerHasNoEscape) {
      _handlePuzzleFailure();
      return;
    }

    if (_gameState.isGameOver &&
        _winnerFromReason(_gameState.gameOverReason) == _playerColor) {
      if (mounted) {
        setState(() {
          _wrongMoveMessage = null;
        });
      }
      _showPuzzleCompleteDialogOnce();
      return;
    }

    if (_gameState.isGameOver) {
      _handlePuzzleFailure();
      return;
    }

    if (mounted) {
      setState(() {
        _wrongMoveMessage = null;
      });
    }

    if (_gameState.currentPlayer != _playerColor) {
      if (_playerSolvedMoveCount() >= _playerTotalMoveCount()) {
        _handlePuzzleFailure();
        return;
      }
      _playOpponentMoveIfNeeded();
    }
  }

  bool _isPuzzleSolvedByNoEscape() {
    if (_gameState.currentPlayer == _playerColor) {
      return false;
    }
    if (!_gameState.currentPlayerHasNoEscape) {
      return false;
    }
    return _playerSolvedMoveCount() <= _playerTotalMoveCount();
  }

  Future<void> _initializePuzzle() async {
    try {
      _isInitialized = false;
      _isAutoPlaying = false;
      _isResolvingWrongMove = false;
      _completionDialogShown = false;
      _attemptResultRecorded = false;
      _wrongMoveMessage = null;
      _lastValidatedMoveCount = 0;
      _targetPlayerMoveCount = 0;
      _isFollowingSolutionLine = true;
      _materialGainResult = null;

      final fen = widget.game['fen'] as String?;
      final solution = widget.game['solution'] as List<dynamic>?;
      final normalizedObjective = PuzzleObjective.normalizePuzzleMap(
        widget.game,
      );
      _objectiveType =
          normalizedObjective[PuzzleObjective.keyObjectiveType] as String;
      _objective = Map<String, dynamic>.from(
        normalizedObjective[PuzzleObjective.keyObjective] as Map,
      );

      if (fen != null && solution != null && solution.isNotEmpty) {
        _solutionMoves = List<String>.from(solution);
        _solutionStartIndex = 0;
        _solutionIndex = 0;
        _targetPlayerMoveCount =
            PuzzleObjective.playerMoveCount(normalizedObjective);

        final toMove = widget.game['toMove'] as String? ?? 'blue';
        _playerColor = toMove == 'red' ? PieceColor.red : PieceColor.blue;

        _gameState.setPositionFromFen(fen, _playerColor);

        setState(() {
          _isInitialized = true;
        });

        _playOpponentMoveIfNeeded();
        return;
      }

      final moves = List<String>.from(widget.game['moves'] ?? const <String>[]);
      if (moves.isEmpty) {
        return;
      }

      _solutionMoves = moves;
      _solutionStartIndex =
          await GibPuzzleLocator.findPuzzleStartPosition(moves);
      _solutionIndex = _solutionStartIndex;
      _targetPlayerMoveCount =
          PuzzleObjective.playerMoveCount(normalizedObjective);

      final board =
          GibParser.replayMovesToPosition(moves, upToMove: _solutionStartIndex);
      if (board == null) {
        return;
      }

      final nextMoveNumber = _solutionStartIndex + 1;
      _playerColor =
          (nextMoveNumber % 2 == 1) ? PieceColor.red : PieceColor.blue;

      _gameState.setPuzzlePosition(board, _playerColor);

      setState(() {
        _isInitialized = true;
      });

      _playOpponentMoveIfNeeded();
    } catch (error) {
      debugPrint('Error initializing puzzle: $error');
    }
  }

  Future<void> _playOpponentMoveIfNeeded() async {
    if (!_isInitialized || !mounted) return;
    if (_isAutoPlaying || _isResolvingWrongMove) return;
    if (_gameState.currentPlayer == _playerColor) return;

    Move? autoMove = _expectedSolutionMoveForCurrentTurn();
    if (autoMove == null && _isMaterialGainPuzzle) {
      _handlePuzzleFailure(message: '검증된 응수 수순을 찾지 못했습니다.');
      return;
    }
    if (autoMove == null) {
      await _gameState.getHint();
      autoMove = _gameState.hintMove;
      if (_gameState.showHint) {
        _gameState.hideHint();
      }
    }

    if (autoMove == null) {
      debugPrint('No opponent response available for current puzzle state.');
      return;
    }

    final piece = _gameState.board.getPiece(autoMove.from);
    if (piece == null || piece.color != _gameState.currentPlayer) {
      debugPrint('Auto move mismatch for ${autoMove.toUCI()}');
      return;
    }

    _isAutoPlaying = true;
    if (mounted) {
      setState(() {});
    }

    try {
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted || !_isInitialized) return;

      await _gameState.onSquareTapped(autoMove.from);
      await _gameState.onSquareTapped(autoMove.to);
    } finally {
      _isAutoPlaying = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _handlePuzzleFailure({
    String message = '주어진 수 안에 상대의 탈출수를 막지 못했습니다.',
  }) {
    if (_isResolvingWrongMove) return;
    _isResolvingWrongMove = true;
    _recordAttemptResult(solved: false);

    setState(() {
      _wrongMoveMessage = message;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _isResolvingWrongMove = false;
      _resetPuzzle();
    });
  }

  void _resetPuzzle() {
    setState(() {
      _isInitialized = false;
      _solutionMoves = <String>[];
      _solutionStartIndex = 0;
      _solutionIndex = 0;
      _lastValidatedMoveCount = 0;
      _targetPlayerMoveCount = 0;
      _isFollowingSolutionLine = true;
      _materialGainResult = null;
      _wrongMoveMessage = null;
      _completionDialogShown = false;
      _attemptResultRecorded = false;
    });
    _initializePuzzle();
  }

  void _undoPuzzleTurn() {
    if (_isAutoPlaying || _isResolvingWrongMove) return;
    if (_gameState.moveHistory.isEmpty) return;

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
    return (_gameState.moveHistory.length + 1) ~/ 2;
  }

  int _playerTotalMoveCount() {
    if (_targetPlayerMoveCount > 0) {
      return _targetPlayerMoveCount;
    }

    final totalMoves = (_solutionMoves.length - _solutionStartIndex).clamp(
      0,
      _solutionMoves.length,
    );
    return (totalMoves + 1) ~/ 2;
  }

  void _recomputeProgressFromHistory() {
    final history = _gameState.moveHistory;
    var matchedMoves = 0;

    while (_solutionStartIndex + matchedMoves < _solutionMoves.length &&
        matchedMoves < history.length) {
      final expectedMove = _parseSolutionMove(
          _solutionMoves[_solutionStartIndex + matchedMoves]);
      final actualMove = history[matchedMoves];
      if (expectedMove == null || expectedMove != actualMove) {
        break;
      }
      matchedMoves++;
    }

    _solutionIndex = _solutionStartIndex + matchedMoves;
    _isFollowingSolutionLine = matchedMoves == history.length;
    _lastValidatedMoveCount = history.length;

    if (_gameState.showHint) {
      _gameState.hideHint();
    }
  }

  bool get _isMaterialGainPuzzle =>
      _objectiveType == PuzzleObjective.materialGain;

  bool _handleMaterialGainProgress() {
    if (!_isMaterialGainPuzzle) {
      return false;
    }

    if (!_isFollowingSolutionLine) {
      _handlePuzzleFailure(message: '정답 수순에서 벗어났습니다.');
      return true;
    }

    if (_solutionIndex >= _solutionMoves.length) {
      final result = PuzzleObjective.evaluateMaterialGain(
        objective: _objective,
        playerColor: _playerColor,
        capturedByBlue: _gameState.capturedByBlue,
        capturedByRed: _gameState.capturedByRed,
      );
      _materialGainResult = result;
      if (result.success) {
        if (mounted) {
          setState(() {
            _wrongMoveMessage = null;
          });
        }
        _showPuzzleCompleteDialogOnce();
      } else {
        _handlePuzzleFailure(message: result.message);
      }
      return true;
    }

    if (_gameState.isGameOver || _gameState.currentPlayerHasNoEscape) {
      _handlePuzzleFailure(message: '목표 기물을 얻기 전에 대국이 종료되었습니다.');
      return true;
    }

    if (_gameState.currentPlayer != _playerColor) {
      _playOpponentMoveIfNeeded();
    }
    return true;
  }

  Move? _expectedSolutionMoveForCurrentTurn() {
    if (!_isFollowingSolutionLine) return null;
    if (_solutionIndex < _solutionStartIndex ||
        _solutionIndex >= _solutionMoves.length) {
      return null;
    }

    final move = _parseSolutionMove(_solutionMoves[_solutionIndex]);
    if (move == null) return null;

    final piece = _gameState.board.getPiece(move.from);
    if (piece == null || piece.color != _gameState.currentPlayer) {
      return null;
    }

    return move;
  }

  PieceColor _oppositeColor(PieceColor color) {
    return color == PieceColor.blue ? PieceColor.red : PieceColor.blue;
  }

  PieceColor? _winnerFromReason(String? reason) {
    switch (reason) {
      case 'blue_wins_checkmate':
      case 'blue_wins_capture':
      case 'blue_wins_points':
        return PieceColor.blue;
      case 'red_wins_checkmate':
      case 'red_wins_capture':
      case 'red_wins_points':
        return PieceColor.red;
      default:
        return null;
    }
  }

  String _sideLabel(PieceColor color) {
    return color == PieceColor.blue ? '초' : '한';
  }

  String get _objectiveInstruction {
    return PuzzleObjective.instructionForPuzzle(<String, dynamic>{
      'objectiveType': _objectiveType,
      'objective': _objective,
      'mateIn': widget.game['mateIn'],
      'solution': _solutionMoves,
    });
  }

  String get _completionMessage {
    if (_isMaterialGainPuzzle) {
      return _materialGainResult?.message ?? '목표 기물을 얻고 유리한 형세를 만들었습니다.';
    }
    return '주어진 수 안에 상대의 탈출수를 모두 막았습니다.';
  }

  void _showPuzzleCompleteDialogOnce() {
    if (_completionDialogShown) return;
    _completionDialogShown = true;
    _recordAttemptResult(solved: true);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _showPuzzleCompleteDialog();
    });
  }

  void _recordAttemptResult({required bool solved}) {
    if (_attemptResultRecorded) {
      return;
    }

    final puzzleId = widget.game['id'] as String?;
    if (puzzleId == null || puzzleId.isEmpty) {
      return;
    }

    _attemptResultRecorded = true;
    final completedAt = DateTime.now();
    if (solved) {
      unawaited(
        PuzzleProgressService.recordSolvedAttempt(
          puzzleId,
          completedAt: completedAt,
        ),
      );
    } else {
      unawaited(
        PuzzleProgressService.recordFailedAttempt(
          puzzleId,
          completedAt: completedAt,
        ),
      );
    }
  }

  void _showPuzzleCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('퍼즐 완료'),
        content: Text(_completionMessage),
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
            child: const Text('다시 풀기'),
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

  Future<void> _toggleHint() async {
    if (_gameState.showHint) {
      _gameState.hideHint();
      return;
    }
    if (!_canPlayerMove()) return;

    final move = _expectedSolutionMoveForCurrentTurn();
    if (move != null) {
      _gameState.setManualHint(move.from, move.to);
      return;
    }

    await _gameState.getHint();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameState>.value(
      value: _gameState,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5E6D3),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.arrow_back,
                                          color: Colors.white,
                                        ),
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
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 56,
                                      right: 8,
                                    ),
                                    child: Text(
                                      _objectiveInstruction,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.82,
                                        ),
                                        fontSize: 12,
                                      ),
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
                              pieceSkin: settings.pieceSkin,
                              onTap: () {},
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
                              pieceSkin: settings.pieceSkin,
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
                                horizontal: 24,
                                vertical: 12,
                              ),
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
