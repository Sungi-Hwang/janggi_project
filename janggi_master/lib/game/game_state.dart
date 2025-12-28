import 'package:flutter/foundation.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';
import '../models/move.dart';
import '../stockfish_ffi.dart';
import '../utils/stockfish_converter.dart';
import '../screens/game_screen.dart' show GameMode;

/// Manages the game state and logic
class GameState extends ChangeNotifier {
  final Board _board = Board();
  PieceColor _currentPlayer = PieceColor.blue;  // Blue (초) starts first
  Position? _selectedPosition;
  List<Position> _validMoves = [];
  List<Move> _moveHistory = [];

  // Game mode
  final GameMode _gameMode;

  // AI settings
  int _aiDepth = 5; // Default: 중수 (Medium)
  PieceColor _aiColor = PieceColor.red; // AI plays as Red (한) by default
  bool _isEngineThinking = false;
  String _statusMessage = 'Blue to move (초 선공)';
  bool _isGameOver = false;

  // For repetition detection - track board positions (FEN strings)
  final Map<String, int> _positionHistory = {};
  int _halfMoveClock = 0; // For 50-move rule (counts half-moves since last capture/pawn move)

  // Piece setup configurations
  PieceSetup _blueSetup = PieceSetup.horseElephantHorseElephant;  // Default: 마상마상
  PieceSetup _redSetup = PieceSetup.horseElephantHorseElephant;   // Default: 마상마상

  // Game over details
  String? _gameOverReason;

  // Animation state
  Move? _animatingMove; // The move currently being animated
  bool _isAnimating = false;
  Piece? _animatingPiece; // The piece being animated

  // Getters
  Board get board => _board;
  PieceColor get currentPlayer => _currentPlayer;
  Position? get selectedPosition => _selectedPosition;
  List<Position> get validMoves => _validMoves;
  List<Move> get moveHistory => _moveHistory;
  bool get isEngineThinking => _isEngineThinking;
  String get statusMessage => _statusMessage;
  bool get isGameOver => _isGameOver;
  String? get gameOverReason => _gameOverReason;
  int get aiDepth => _aiDepth;
  PieceColor get aiColor => _aiColor;
  Move? get animatingMove => _animatingMove;
  bool get isAnimating => _isAnimating;
  Piece? get animatingPiece => _animatingPiece;

  /// Set AI difficulty level (depth)
  void setAIDifficulty(int depth) {
    _aiDepth = depth.clamp(1, 15);
    debugPrint('AI difficulty set to depth: $_aiDepth');
    notifyListeners();
  }

  /// Set AI color (which side AI plays)
  void setAIColor(PieceColor color) {
    _aiColor = color;
    debugPrint('AI color set to: ${color == PieceColor.blue ? "초 (Blue)" : "한 (Red)"}');
    notifyListeners();
  }

  GameState({
    GameMode gameMode = GameMode.vsAI,
    int aiDifficulty = 10,
    PieceColor aiColor = PieceColor.red,
  }) : _gameMode = gameMode,
       _aiDepth = aiDifficulty,
       _aiColor = aiColor {
    _initializeGame();
  }

  /// Getter for game mode
  GameMode get gameMode => _gameMode;

  void _initializeGame() {
    _board.setupInitialPosition(
      blueSetup: _blueSetup,
      redSetup: _redSetup,
    );
    _currentPlayer = PieceColor.blue;  // Blue (초) starts first
    _selectedPosition = null;
    _validMoves = [];
    _moveHistory = [];
    _isGameOver = false;
    _gameOverReason = null;
    _positionHistory.clear();
    _halfMoveClock = 0;

    // Record initial position
    final initialFen = StockfishConverter.boardToFEN(_board, _currentPlayer);
    _positionHistory[initialFen] = 1;

    _updateStatusMessage();
    notifyListeners();

    // If AI is Blue (초), AI should move first
    if (_gameMode == GameMode.vsAI && _aiColor == PieceColor.blue) {
      Future.microtask(() => _getAIMove());
    }
  }

  /// Set piece setup configurations and restart game
  void setPieceSetup({
    required PieceSetup blueSetup,
    required PieceSetup redSetup,
  }) {
    _blueSetup = blueSetup;
    _redSetup = redSetup;
    _initializeGame();
  }

  // Getters for piece setup
  PieceSetup get blueSetup => _blueSetup;
  PieceSetup get redSetup => _redSetup;

  /// Update status message with current player and check indication
  void _updateStatusMessage() {
    if (_isGameOver) return; // Don't update if game is over

    final baseMessage = _currentPlayer == PieceColor.blue
        ? 'Blue to move (초)'
        : 'Red to move (한)';

    // Check for draw conditions first
    if (_isThreefoldRepetition()) {
      _statusMessage = 'Draw by threefold repetition!';
      _isGameOver = true;
      _gameOverReason = 'threefold_repetition';
      debugPrint('_updateStatusMessage: DRAW - Threefold repetition');
      return;
    }

    if (_isFiftyMoveRule()) {
      _statusMessage = 'Draw by 50-move rule!';
      _isGameOver = true;
      _gameOverReason = 'fifty_move_rule';
      debugPrint('_updateStatusMessage: DRAW - 50-move rule');
      return;
    }

    // Check for checkmate
    if (_isCheckmate(_currentPlayer)) {
      final winner = _currentPlayer == PieceColor.blue
          ? 'Red (한)'
          : 'Blue (초)';
      _statusMessage = 'Checkmate! $winner wins!';
      _isGameOver = true;
      _gameOverReason = _currentPlayer == PieceColor.blue ? 'red_wins_checkmate' : 'blue_wins_checkmate';
      debugPrint('_updateStatusMessage: CHECKMATE - ${_currentPlayer.name} has no legal moves and is in check');
      return;
    }

    // 장기에는 스테일메이트 없음 - 체크메이트, 왕 포획, 3수 동형, 50수만 게임 종료

    // Check if current player is in check
    if (_isKingInCheck(_currentPlayer)) {
      _statusMessage = '$baseMessage - CHECK!';
      debugPrint('_updateStatusMessage: ${_currentPlayer.name} is in CHECK');
    } else {
      _statusMessage = baseMessage;
    }
  }

  /// Start a new game
  void newGame() {
    _initializeGame();
  }

  /// Handle square tap
  Future<void> onSquareTapped(Position position) async {
    debugPrint('onSquareTapped: position=$position');

    // Don't allow moves if game is over
    if (_isGameOver) {
      debugPrint('onSquareTapped: Game is over, ignoring tap');
      return;
    }

    // Don't allow input during animation
    if (_isAnimating) {
      debugPrint('onSquareTapped: Animation in progress, ignoring input');
      return;
    }

    if (_isEngineThinking) {
      debugPrint('onSquareTapped: engine is thinking, ignoring');
      return;
    }

    // In AI mode, don't allow player to move during AI's turn
    if (_gameMode == GameMode.vsAI && _currentPlayer == _aiColor) {
      debugPrint('onSquareTapped: AI turn, ignoring player input');
      return;
    }

    final piece = _board.getPiece(position);
    debugPrint('onSquareTapped: piece at position=$piece');

    // If no piece selected yet
    if (_selectedPosition == null) {
      // Can only select current player's pieces
      if (piece != null && piece.color == _currentPlayer) {
        debugPrint('onSquareTapped: selecting piece at $position');
        _selectedPosition = position;
        _validMoves = _getValidMovesForPosition(position);
        debugPrint('onSquareTapped: found ${_validMoves.length} valid moves');
        notifyListeners();
      }
      return;
    }

    // If same square clicked, deselect
    if (_selectedPosition == position) {
      debugPrint('onSquareTapped: deselecting piece');
      _selectedPosition = null;
      _validMoves = [];
      notifyListeners();
      return;
    }

    // If clicked on another piece of same color, select that instead
    if (piece != null && piece.color == _currentPlayer) {
      debugPrint('onSquareTapped: selecting different piece at $position');
      _selectedPosition = position;
      _validMoves = _getValidMovesForPosition(position);
      debugPrint('onSquareTapped: found ${_validMoves.length} valid moves for new piece');
      notifyListeners();
      return;
    }

    // If clicked on a valid move position, make the move
    debugPrint('onSquareTapped: checking if $position is in valid moves: ${_validMoves.contains(position)}');
    if (_validMoves.contains(position)) {
      debugPrint('onSquareTapped: making move from $_selectedPosition to $position');
      await _makeMove(_selectedPosition!, position, isPlayerMove: true);
      _selectedPosition = null;
      _validMoves = [];
      notifyListeners();
    } else {
      debugPrint('onSquareTapped: position $position is NOT a valid move. Valid moves are: $_validMoves');
    }
  }

  /// Make a move on the board with animation
  Future<void> _makeMove(Position from, Position to, {bool isPlayerMove = false}) async {
    final piece = _board.getPiece(from);
    if (piece == null) return;

    debugPrint('_makeMove: Moving $piece from $from to $to (isPlayerMove: $isPlayerMove)');

    // Start animation - save piece info and move, but DON'T update board yet
    _isAnimating = true;
    _animatingPiece = piece; // Save the moving piece
    final captured = _board.getPiece(to); // Save captured piece before move
    _animatingMove = Move(from: from, to: to, capturedPiece: captured);

    // Immediately show animation start
    notifyListeners();

    // Wait for animation to complete (both player and AI)
    await Future.delayed(const Duration(milliseconds: 300));

    // NOW make the move on the board (after animation)
    _board.movePiece(from, to);
    debugPrint('_makeMove: Move completed. Captured: $captured');

    // Record the move
    final move = Move(from: from, to: to, capturedPiece: captured);
    _moveHistory.add(move);

    // Update 50-move rule counter
    if (captured != null || piece.type == PieceType.soldier) {
      _halfMoveClock = 0;
      _positionHistory.clear();
      debugPrint('_makeMove: Reset halfMoveClock and position history (capture or pawn move)');
    } else {
      _halfMoveClock++;
      debugPrint('_makeMove: Incremented halfMoveClock to $_halfMoveClock');
    }

    // Check if King (General) was captured - game ends
    if (captured != null && captured.type == PieceType.general) {
      final winner = piece.color == PieceColor.blue ? 'Blue (초)' : 'Red (한)';
      _statusMessage = 'Game Over! $winner wins by capturing the King!';
      _isGameOver = true;
      _gameOverReason = piece.color == PieceColor.blue ? 'blue_wins_capture' : 'red_wins_capture';
      debugPrint('_makeMove: GAME OVER - King captured by ${piece.color}');
      _isAnimating = false;
      _animatingMove = null;
      _animatingPiece = null;
      notifyListeners();
      return;
    }

    // Convert to UCI and log
    final uciMove = StockfishConverter.moveToUCI(from, to);
    debugPrint('_makeMove: UCI notation: $uciMove');
    debugPrint('_makeMove: Full move history UCI: ${_moveHistory.map((m) => m.toUCI()).toList()}');

    // Switch player
    _currentPlayer = _currentPlayer == PieceColor.blue
        ? PieceColor.red
        : PieceColor.blue;

    // Record position for repetition detection
    _recordPosition();

    // Update status message
    _updateStatusMessage();

    // End animation
    _isAnimating = false;
    _animatingMove = null;
    _animatingPiece = null;

    debugPrint('_makeMove: Calling notifyListeners');
    notifyListeners();

    // If it's AI mode and it's now AI's turn, get AI move
    if (_gameMode == GameMode.vsAI && _currentPlayer == _aiColor) {
      if (isPlayerMove) {
        // Give UI a frame to update before starting AI animation
        await Future.delayed(const Duration(milliseconds: 50));
        _getAIMove();
      } else {
        await _getAIMove();
      }
    }
  }

  /// Get AI move from Stockfish
  Future<void> _getAIMove() async {
    _isEngineThinking = true;
    _statusMessage = 'AI thinking...';
    notifyListeners();

    try {
      debugPrint('_getAIMove: Starting AI move calculation');

      // Generate FEN from current board state
      // This avoids "invalid move" errors from move history
      final fen = StockfishConverter.boardToFEN(_board, _currentPlayer);
      debugPrint('_getAIMove: Current FEN: $fen');
      debugPrint('_getAIMove: Current player: $_currentPlayer');

      // Set position using FEN (no move history needed)
      debugPrint('_getAIMove: Setting position...');
      StockfishFFI.setPosition(fen: fen);

      // Get best move with timeout
      debugPrint('_getAIMove: Requesting best move with depth $_aiDepth...');
      final bestMoveUCI = await Future.delayed(
        Duration.zero,
        () => StockfishFFI.getBestMove(depth: _aiDepth),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('_getAIMove: Timeout waiting for Stockfish');
          return null;
        },
      );

      debugPrint('_getAIMove: Received best move: $bestMoveUCI');

      if (bestMoveUCI != null && bestMoveUCI.length >= 4) {
        // Parse UCI move using StockfishConverter
        // UCI format: [file][rank][file][rank], where rank can be 1-10 (1 or 2 digits)
        // Examples: "e4e5", "b10c8", "a1i10"

        // Find where the second file letter starts (after first rank number)
        int secondPartStart = 1;
        while (secondPartStart < bestMoveUCI.length &&
               bestMoveUCI[secondPartStart].codeUnitAt(0) >= '0'.codeUnitAt(0) &&
               bestMoveUCI[secondPartStart].codeUnitAt(0) <= '9'.codeUnitAt(0)) {
          secondPartStart++;
        }

        final fromUCI = bestMoveUCI.substring(0, secondPartStart);
        final toUCI = bestMoveUCI.substring(secondPartStart);

        debugPrint('_getAIMove: Parsing UCI: $fromUCI -> $toUCI');
        final from = StockfishConverter.fromUCI(fromUCI);
        final to = StockfishConverter.fromUCI(toUCI);

        debugPrint('_getAIMove: Converted to Flutter coords: from=$from(file=${from.file},rank=${from.rank}) to=$to(file=${to.file},rank=${to.rank})');

        // Check if there's a piece at the from position
        final piece = _board.getPiece(from);
        debugPrint('_getAIMove: Piece at $from: $piece');

        if (piece == null) {
          debugPrint('_getAIMove: ERROR - No piece at $from! Cannot make move.');
          _statusMessage = 'AI move failed - no piece at source';
          return;
        }

        // Validate the AI move before applying it
        if (!_isValidMove(piece, from, to)) {
          debugPrint('_getAIMove: ERROR - Invalid move from $from to $to for piece $piece!');
          debugPrint('_getAIMove: This indicates a problem with Stockfish coordination or FEN conversion.');
          _statusMessage = 'AI attempted illegal move - please check logs';
          _currentPlayer = PieceColor.blue; // Give turn back to player
          return;
        }

        // Start AI move animation - save piece info, but DON'T update board yet
        _isAnimating = true;
        _animatingPiece = piece; // Save the moving piece
        final captured = _board.getPiece(to); // Save captured piece before move
        _animatingMove = Move(from: from, to: to, capturedPiece: captured);
        notifyListeners();

        // Wait for animation
        await Future.delayed(const Duration(milliseconds: 300));

        // NOW make the AI move (after animation)
        _board.movePiece(from, to);
        debugPrint('_getAIMove: Move result - captured: $captured');

        final move = Move(from: from, to: to, capturedPiece: captured);
        _moveHistory.add(move);

        // Update 50-move rule counter for AI move
        if (captured != null || piece.type == PieceType.soldier) {
          _halfMoveClock = 0;
          _positionHistory.clear();
          debugPrint('_getAIMove: Reset halfMoveClock and position history (capture or pawn move)');
        } else {
          _halfMoveClock++;
          debugPrint('_getAIMove: Incremented halfMoveClock to $_halfMoveClock');
        }

        // Check if King (General) was captured - game ends
        if (captured != null && captured.type == PieceType.general) {
          final winnerColor = _aiColor == PieceColor.blue ? 'Blue (초)' : 'Red (한)';
          _statusMessage = 'Game Over! $winnerColor wins by capturing the King!';
          _isGameOver = true;
          _gameOverReason = _aiColor == PieceColor.blue ? 'blue_wins_capture' : 'red_wins_capture';
          debugPrint('_getAIMove: GAME OVER - King captured by AI');
          _isAnimating = false;
          _animatingMove = null;
          _animatingPiece = null;
          return; // End game - no further moves
        }

        // Switch to player's color (opposite of AI)
        _currentPlayer = _currentPlayer == PieceColor.blue ? PieceColor.red : PieceColor.blue;

        // Record position for repetition detection
        _recordPosition();

        _updateStatusMessage();

        // End animation
        _isAnimating = false;
        _animatingMove = null;
        _animatingPiece = null;
      } else {
        debugPrint('_getAIMove: No valid move received from Stockfish');
        _statusMessage = 'AI failed to move';
        // Switch to player's color (opposite of AI)
        _currentPlayer = _aiColor == PieceColor.blue ? PieceColor.red : PieceColor.blue;
      }
    } catch (e, stackTrace) {
      _statusMessage = 'AI error: $e';
      debugPrint('AI move error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Switch to player's color (opposite of AI)
      _currentPlayer = _aiColor == PieceColor.blue ? PieceColor.red : PieceColor.blue;
    } finally {
      _isEngineThinking = false;
      debugPrint('_getAIMove: Calling final notifyListeners');
      notifyListeners();
    }
  }

  /// Get valid moves for a position based on Janggi rules
  /// This includes check validation - moves that would leave the king in check are filtered out
  List<Position> _getValidMovesForPosition(Position from) {
    final piece = _board.getPiece(from);
    if (piece == null) return [];

    final moves = <Position>[];

    // Check all possible destination squares
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final to = Position(file: file, rank: rank);
        if (to == from) continue;

        final targetPiece = _board.getPiece(to);

        // Can't capture own piece
        if (targetPiece != null && targetPiece.color == piece.color) {
          continue;
        }

        // Check if this move is valid according to piece-specific rules
        if (_isValidMove(piece, from, to)) {
          // Additionally check if this move would leave our king in check
          // Filter out illegal moves that would expose the king
          if (!_wouldMoveCauseCheck(from, to)) {
            moves.add(to);
          }
        }
      }
    }

    return moves;
  }

  /// Check if a move is valid based on piece type and Janggi rules
  bool _isValidMove(Piece piece, Position from, Position to) {
    switch (piece.type) {
      case PieceType.general:
        // General can move one step orthogonally or diagonally within palace
        // Must stay in palace and can move along palace diagonals
        if (!from.isInPalace(isRedPalace: piece.color == PieceColor.red) ||
            !to.isInPalace(isRedPalace: piece.color == PieceColor.red)) {
          return false;
        }
        return _isOneStepMove(from, to);

      case PieceType.guard:
        // Guard moves like general
        if (!from.isInPalace(isRedPalace: piece.color == PieceColor.red) ||
            !to.isInPalace(isRedPalace: piece.color == PieceColor.red)) {
          return false;
        }
        return _isOneStepMove(from, to);

      case PieceType.horse:
        // Horse moves in L shape (1 orthogonal + 1 diagonal)
        // Must check if path is blocked
        return _isValidHorseMove(from, to);

      case PieceType.elephant:
        // Elephant moves in extended L shape (1 orthogonal + 2 diagonal)
        // Must check if path is blocked
        return _isValidElephantMove(from, to);

      case PieceType.chariot:
        // Chariot moves orthogonally any distance with clear path
        // Also can move along palace diagonals
        if (_isOrthogonalMove(from, to)) {
          return _isPathClear(from, to);
        }

        // Check palace diagonal movement
        if (from.isInPalace(isRedPalace: piece.color == PieceColor.red) &&
            to.isInPalace(isRedPalace: piece.color == PieceColor.red)) {
          if (_isPalaceDiagonal(from, to, piece.color == PieceColor.red)) {
            return _isPalaceDiagonalPathClear(from, to, piece.color == PieceColor.red);
          }
        }

        return false;

      case PieceType.cannon:
        // Cannon moves orthogonally, must jump over exactly one piece
        // Also can move along palace diagonals
        // Cannot capture another cannon
        final targetPiece = _board.getPiece(to);
        if (targetPiece != null && targetPiece.type == PieceType.cannon) {
          return false;
        }

        // Check orthogonal movement
        if (_isOrthogonalMove(from, to)) {
          return _isValidCannonMove(from, to);
        }

        // Check palace diagonal movement
        if (from.isInPalace(isRedPalace: piece.color == PieceColor.red) &&
            to.isInPalace(isRedPalace: piece.color == PieceColor.red)) {
          // For cannon, we don't use _isPalaceDiagonal because it doesn't support corner-to-corner
          // Instead, _isValidCannonDiagonalMove handles all diagonal cases
          return _isValidCannonDiagonalMove(from, to, piece.color == PieceColor.red);
        }

        return false;

      case PieceType.soldier:
        // Soldier moves one step forward or sideways (not backward)
        return _isValidSoldierMove(piece, from, to);
    }
  }

  /// Check if horse move is valid (L-shape with blocking check)
  bool _isValidHorseMove(Position from, Position to) {
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;

    // Check L-shape pattern
    if (fileDiff.abs() == 2 && rankDiff.abs() == 1) {
      // Moving horizontally first
      final blockPos = Position(
        file: from.file + (fileDiff > 0 ? 1 : -1),
        rank: from.rank,
      );
      return _board.getPiece(blockPos) == null;
    } else if (fileDiff.abs() == 1 && rankDiff.abs() == 2) {
      // Moving vertically first
      final blockPos = Position(
        file: from.file,
        rank: from.rank + (rankDiff > 0 ? 1 : -1),
      );
      return _board.getPiece(blockPos) == null;
    }
    return false;
  }

  /// Check if elephant move is valid (extended L-shape with blocking check)
  bool _isValidElephantMove(Position from, Position to) {
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;

    // Check extended L-shape pattern
    if (fileDiff.abs() == 3 && rankDiff.abs() == 2) {
      // Moving horizontally first (1 horizontal, then 2 diagonal)
      final block1 = Position(
        file: from.file + (fileDiff > 0 ? 1 : -1),
        rank: from.rank,
      );
      final block2 = Position(
        file: from.file + (fileDiff > 0 ? 2 : -2),
        rank: from.rank + (rankDiff > 0 ? 1 : -1),
      );
      return _board.getPiece(block1) == null && _board.getPiece(block2) == null;
    } else if (fileDiff.abs() == 2 && rankDiff.abs() == 3) {
      // Moving vertically first (1 vertical, then 2 diagonal)
      final block1 = Position(
        file: from.file,
        rank: from.rank + (rankDiff > 0 ? 1 : -1),
      );
      final block2 = Position(
        file: from.file + (fileDiff > 0 ? 1 : -1),
        rank: from.rank + (rankDiff > 0 ? 2 : -2),
      );
      return _board.getPiece(block1) == null && _board.getPiece(block2) == null;
    }
    return false;
  }

  /// Check if cannon move is valid (must jump exactly one piece)
  bool _isValidCannonMove(Position from, Position to) {
    if (!_isOrthogonalMove(from, to)) return false;

    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;

    final fileStep = fileDiff == 0 ? 0 : (fileDiff > 0 ? 1 : -1);
    final rankStep = rankDiff == 0 ? 0 : (rankDiff > 0 ? 1 : -1);

    var current = Position(
      file: from.file + fileStep,
      rank: from.rank + rankStep,
    );

    int piecesJumped = 0;

    // Count pieces between from and to
    while (current != to) {
      final piece = _board.getPiece(current);
      if (piece != null) {
        piecesJumped++;
        // Cannon cannot jump over another cannon
        if (piece.type == PieceType.cannon) {
          return false;
        }
      }
      current = Position(
        file: current.file + fileStep,
        rank: current.rank + rankStep,
      );
    }

    // Must jump exactly one piece
    return piecesJumped == 1;
  }

  /// Check if cannon diagonal move in palace is valid (must jump exactly one piece)
  bool _isValidCannonDiagonalMove(Position from, Position to, bool isRedPalace) {
    final centerFile = 4;
    final centerRank = isRedPalace ? 8 : 1;
    final center = Position(file: centerFile, rank: centerRank);

    // Cannon MUST jump over exactly one piece on diagonal - NEVER moves without jumping!
    // Palace diagonal paths (STRAIGHT diagonals):
    // Blue: (d0)-(e1)-(f2) and (f0)-(e1)-(d2)
    // Red: (d7)-(e8)-(f9) and (f7)-(e8)-(d9)

    // Case 1: Corner to corner (jumping through center)
    if (from != center && to != center) {
      // Check if from and to are on the same diagonal line
      // Valid corner pairs: (d0, f2) and (f0, d2) for blue palace
      // Valid corner pairs: (d7, f9) and (f7, d9) for red palace
      final fileDiff = (to.file - from.file).abs();
      final rankDiff = (to.rank - from.rank).abs();

      // Corner to corner must be 2 steps diagonally
      if (fileDiff != 2 || rankDiff != 2) {
        return false;
      }

      final centerPiece = _board.getPiece(center);
      // Must have exactly one piece at center to jump over
      if (centerPiece != null && centerPiece.type != PieceType.cannon) {
        return true;
      }
      return false;
    }

    // Case 2: Center to corner or corner to center (ONE step diagonal)
    // For cannon, this is NOT allowed because there's no piece to jump over!
    // Cannon cannot move one step diagonally - it must jump over a piece
    // Example: e1(center) → d0(corner) is INVALID for cannon (no piece to jump)
    // Only valid if jumping: e1 → (jump over piece at intermediate) → corner

    if (from == center || to == center) {
      final cornerPos = from == center ? to : from;
      final centerPos = center;

      final fileDiff = (cornerPos.file - centerPos.file).abs();
      final rankDiff = (cornerPos.rank - centerPos.rank).abs();

      // One-step diagonal move (center to/from adjacent corner)
      if (fileDiff == 1 && rankDiff == 1) {
        // For cannon, one-step diagonal is NEVER allowed (no piece to jump over)
        // The diagonal line is direct: d0-e1 or e1-f2, etc.
        return false;
      }

      // Shouldn't reach here for valid palace positions
      return false;
    }

    return false;
  }

  /// Check if soldier move is valid
  bool _isValidSoldierMove(Piece piece, Position from, Position to) {
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;

    // Soldiers can move forward or sideways, never backward
    // Blue (楚) is at bottom (ranks 0-3), moves UP (increasing rank)
    // Red (漢) is at top (ranks 6-9), moves DOWN (decreasing rank)
    if (piece.color == PieceColor.blue) {
      // Blue moves up (increasing rank)
      // Forward: one step up
      if (rankDiff == 1 && fileDiff == 0) return true;
      // Sideways: one step left or right (same rank)
      if (rankDiff == 0 && fileDiff.abs() == 1) return true;
      // In palace, can move along valid palace diagonal lines (forward only)
      if (from.isInPalace(isRedPalace: false) &&
          to.isInPalace(isRedPalace: false) &&
          rankDiff == 1 && fileDiff.abs() == 1) {
        // Must be on a valid palace diagonal line
        return _isPalaceDiagonal(from, to, false);
      }
    } else {
      // Red moves down (decreasing rank)
      // Forward: one step down
      if (rankDiff == -1 && fileDiff == 0) return true;
      // Sideways: one step left or right (same rank)
      if (rankDiff == 0 && fileDiff.abs() == 1) return true;
      // In palace, can move along valid palace diagonal lines (forward only)
      if (from.isInPalace(isRedPalace: true) &&
          to.isInPalace(isRedPalace: true) &&
          rankDiff == -1 && fileDiff.abs() == 1) {
        // Must be on a valid palace diagonal line
        return _isPalaceDiagonal(from, to, true);
      }
    }

    return false;
  }

  /// Check if a move is along a palace diagonal line
  /// Palace diagonals only exist at specific positions:
  /// Blue palace (ranks 0-2, files 3-5):
  ///   (3,0)↔(4,1), (5,0)↔(4,1), (3,2)↔(4,1), (5,2)↔(4,1)
  /// Red palace (ranks 7-9, files 3-5):
  ///   (3,7)↔(4,8), (5,7)↔(4,8), (3,9)↔(4,8), (5,9)↔(4,8)
  bool _isPalaceDiagonal(Position from, Position to, bool isRedPalace) {
    final centerFile = 4; // e file
    final centerRank = isRedPalace ? 8 : 1; // Middle of palace

    // Valid diagonal connections to/from palace center
    final validDiagonals = [
      // Center to corners
      [Position(file: centerFile, rank: centerRank), Position(file: 3, rank: isRedPalace ? 7 : 0)],
      [Position(file: centerFile, rank: centerRank), Position(file: 5, rank: isRedPalace ? 7 : 0)],
      [Position(file: centerFile, rank: centerRank), Position(file: 3, rank: isRedPalace ? 9 : 2)],
      [Position(file: centerFile, rank: centerRank), Position(file: 5, rank: isRedPalace ? 9 : 2)],
    ];

    // Check if move matches any diagonal (in either direction)
    for (final diagonal in validDiagonals) {
      if ((from == diagonal[0] && to == diagonal[1]) ||
          (from == diagonal[1] && to == diagonal[0])) {
        return true;
      }
    }

    return false;
  }

  /// Check if one-step move is valid within palace (orthogonal or valid diagonal)
  bool _isOneStepMove(Position from, Position to) {
    final fileDiff = (to.file - from.file).abs();
    final rankDiff = (to.rank - from.rank).abs();

    // Must be exactly one step
    if (fileDiff > 1 || rankDiff > 1) return false;
    if (fileDiff == 0 && rankDiff == 0) return false;

    // Orthogonal moves (horizontal/vertical) are always valid
    if (fileDiff == 0 || rankDiff == 0) return true;

    // Diagonal moves only valid along palace diagonal lines
    if (fileDiff == 1 && rankDiff == 1) {
      final isRedPalace = from.isInPalace(isRedPalace: true);
      return _isPalaceDiagonal(from, to, isRedPalace);
    }

    return false;
  }

  bool _isOrthogonalMove(Position from, Position to) {
    return from.file == to.file || from.rank == to.rank;
  }

  bool _isPathClear(Position from, Position to) {
    if (!_isOrthogonalMove(from, to)) return false;

    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;

    final fileStep = fileDiff == 0 ? 0 : (fileDiff > 0 ? 1 : -1);
    final rankStep = rankDiff == 0 ? 0 : (rankDiff > 0 ? 1 : -1);

    var current = Position(
      file: from.file + fileStep,
      rank: from.rank + rankStep,
    );

    while (current != to) {
      if (_board.getPiece(current) != null) {
        return false;
      }
      current = Position(
        file: current.file + fileStep,
        rank: current.rank + rankStep,
      );
    }

    return true;
  }

  /// Check if path is clear for palace diagonal move
  bool _isPalaceDiagonalPathClear(Position from, Position to, bool isRedPalace) {
    // For one-step diagonal, path is always clear
    if ((to.file - from.file).abs() == 1 && (to.rank - from.rank).abs() == 1) {
      return true;
    }

    // For multi-step diagonal (chariot/cannon in palace)
    final centerFile = 4;
    final centerRank = isRedPalace ? 8 : 1;
    final center = Position(file: centerFile, rank: centerRank);

    // Check if path goes through center
    // Path: corner → center or center → corner
    if (from == center || to == center) {
      // Direct diagonal, no pieces in between for 1-step
      return true;
    }

    // If both positions are corners, must go through center
    // Check if center is occupied
    return _board.getPiece(center) == null;
  }

  /// Check if a king of the given color is in check on a specific board
  /// Returns true if any opponent piece can attack the king
  bool _isKingInCheck(PieceColor kingColor, [Board? testBoard]) {
    final board = testBoard ?? _board;

    // Find the king position
    Position? kingPosition;
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final pos = Position(file: file, rank: rank);
        final piece = board.getPiece(pos);
        if (piece != null &&
            piece.type == PieceType.general &&
            piece.color == kingColor) {
          kingPosition = pos;
          break;
        }
      }
      if (kingPosition != null) break;
    }

    // If no king found, not in check (shouldn't happen in normal game)
    if (kingPosition == null) return false;

    // Check if any opponent piece can attack the king
    final opponentColor = kingColor == PieceColor.blue
        ? PieceColor.red
        : PieceColor.blue;

    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final pos = Position(file: file, rank: rank);
        final piece = board.getPiece(pos);

        if (piece != null && piece.color == opponentColor) {
          // Check if this opponent piece can attack the king
          // We need to use a temporary board state for validation
          if (_isValidMoveOnBoard(piece, pos, kingPosition, board)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Check if the current player is in checkmate
  /// Checkmate = king is in check AND no legal moves available
  bool _isCheckmate(PieceColor playerColor) {
    // First, check if the king is in check
    if (!_isKingInCheck(playerColor)) {
      return false; // Not in check, so can't be checkmate
    }

    // Check if there are any legal moves available
    // If any piece has at least one legal move, it's not checkmate
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final pos = Position(file: file, rank: rank);
        final piece = _board.getPiece(pos);

        if (piece != null && piece.color == playerColor) {
          // Get valid moves for this piece (already filters out moves that leave king in check)
          final validMoves = _getValidMovesForPosition(pos);
          if (validMoves.isNotEmpty) {
            // Found at least one legal move, not checkmate
            return false;
          }
        }
      }
    }

    // King is in check and no legal moves available = checkmate
    return true;
  }


  /// Check for threefold repetition
  /// If the same position occurs 3 times, it's a draw
  bool _isThreefoldRepetition() {
    final currentFen = StockfishConverter.boardToFEN(_board, _currentPlayer);
    final count = _positionHistory[currentFen] ?? 0;
    return count >= 3;
  }

  /// Check for 50-move rule
  /// If 50 moves (100 half-moves) pass without a capture or pawn move, it's a draw
  bool _isFiftyMoveRule() {
    return _halfMoveClock >= 100;
  }

  /// Record the current position in history after a move
  void _recordPosition() {
    final currentFen = StockfishConverter.boardToFEN(_board, _currentPlayer);
    _positionHistory[currentFen] = (_positionHistory[currentFen] ?? 0) + 1;
    debugPrint('_recordPosition: Position count for this FEN: ${_positionHistory[currentFen]}');
  }

  /// Check if a move would leave the player's own king in check
  /// Returns true if the move would cause or leave the king in check (illegal move)
  bool _wouldMoveCauseCheck(Position from, Position to) {
    final piece = _board.getPiece(from);
    if (piece == null) return true; // Invalid move

    // Create a copy of the board to simulate the move
    final testBoard = _board.copy();
    testBoard.movePiece(from, to);

    // Check if this move would leave our own king in check
    return _isKingInCheck(piece.color, testBoard);
  }

  /// Validate move on a specific board (used for check detection)
  /// This is a version of _isValidMove that works on a test board
  bool _isValidMoveOnBoard(Piece piece, Position from, Position to, Board board) {
    switch (piece.type) {
      case PieceType.general:
      case PieceType.guard:
        // Must stay in palace and be one step move
        if (!from.isInPalace(isRedPalace: piece.color == PieceColor.red) ||
            !to.isInPalace(isRedPalace: piece.color == PieceColor.red)) {
          return false;
        }
        return _isOneStepMoveSimple(from, to);

      case PieceType.horse:
        return _isValidHorseMoveSimple(from, to, board);

      case PieceType.elephant:
        return _isValidElephantMoveSimple(from, to, board);

      case PieceType.chariot:
        if (_isOrthogonalMove(from, to)) {
          return _isPathClearOnBoard(from, to, board);
        }
        if (from.isInPalace(isRedPalace: piece.color == PieceColor.red) &&
            to.isInPalace(isRedPalace: piece.color == PieceColor.red)) {
          if (_isPalaceDiagonal(from, to, piece.color == PieceColor.red)) {
            return _isPalaceDiagonalPathClearOnBoard(from, to, piece.color == PieceColor.red, board);
          }
        }
        return false;

      case PieceType.cannon:
        final targetPiece = board.getPiece(to);
        if (targetPiece != null && targetPiece.type == PieceType.cannon) {
          return false;
        }
        if (_isOrthogonalMove(from, to)) {
          return _isValidCannonMoveOnBoard(from, to, board);
        }
        if (from.isInPalace(isRedPalace: piece.color == PieceColor.red) &&
            to.isInPalace(isRedPalace: piece.color == PieceColor.red)) {
          if (_isPalaceDiagonal(from, to, piece.color == PieceColor.red)) {
            return _isValidCannonDiagonalMoveOnBoard(from, to, piece.color == PieceColor.red, board);
          }
        }
        return false;

      case PieceType.soldier:
        return _isValidSoldierMoveSimple(piece, from, to);
    }
  }

  // Helper methods for board-specific validation
  bool _isOneStepMoveSimple(Position from, Position to) {
    final fileDiff = (to.file - from.file).abs();
    final rankDiff = (to.rank - from.rank).abs();
    if (fileDiff > 1 || rankDiff > 1) return false;
    if (fileDiff == 0 && rankDiff == 0) return false;
    if (fileDiff == 0 || rankDiff == 0) return true;
    if (fileDiff == 1 && rankDiff == 1) {
      final isRedPalace = from.isInPalace(isRedPalace: true);
      return _isPalaceDiagonal(from, to, isRedPalace);
    }
    return false;
  }

  bool _isValidHorseMoveSimple(Position from, Position to, Board board) {
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;
    if (fileDiff.abs() == 2 && rankDiff.abs() == 1) {
      final blockPos = Position(file: from.file + (fileDiff > 0 ? 1 : -1), rank: from.rank);
      return board.getPiece(blockPos) == null;
    } else if (fileDiff.abs() == 1 && rankDiff.abs() == 2) {
      final blockPos = Position(file: from.file, rank: from.rank + (rankDiff > 0 ? 1 : -1));
      return board.getPiece(blockPos) == null;
    }
    return false;
  }

  bool _isValidElephantMoveSimple(Position from, Position to, Board board) {
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;
    if (fileDiff.abs() == 3 && rankDiff.abs() == 2) {
      final block1 = Position(file: from.file + (fileDiff > 0 ? 1 : -1), rank: from.rank);
      final block2 = Position(file: from.file + (fileDiff > 0 ? 2 : -2), rank: from.rank + (rankDiff > 0 ? 1 : -1));
      return board.getPiece(block1) == null && board.getPiece(block2) == null;
    } else if (fileDiff.abs() == 2 && rankDiff.abs() == 3) {
      final block1 = Position(file: from.file, rank: from.rank + (rankDiff > 0 ? 1 : -1));
      final block2 = Position(file: from.file + (fileDiff > 0 ? 1 : -1), rank: from.rank + (rankDiff > 0 ? 2 : -2));
      return board.getPiece(block1) == null && board.getPiece(block2) == null;
    }
    return false;
  }

  bool _isPathClearOnBoard(Position from, Position to, Board board) {
    if (!_isOrthogonalMove(from, to)) return false;
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;
    final fileStep = fileDiff == 0 ? 0 : (fileDiff > 0 ? 1 : -1);
    final rankStep = rankDiff == 0 ? 0 : (rankDiff > 0 ? 1 : -1);
    var current = Position(file: from.file + fileStep, rank: from.rank + rankStep);
    while (current != to) {
      if (board.getPiece(current) != null) return false;
      current = Position(file: current.file + fileStep, rank: current.rank + rankStep);
    }
    return true;
  }

  bool _isPalaceDiagonalPathClearOnBoard(Position from, Position to, bool isRedPalace, Board board) {
    if ((to.file - from.file).abs() == 1 && (to.rank - from.rank).abs() == 1) {
      return true;
    }
    final center = Position(file: 4, rank: isRedPalace ? 8 : 1);
    if (from == center || to == center) {
      return true;
    }
    return board.getPiece(center) == null;
  }

  bool _isValidCannonMoveOnBoard(Position from, Position to, Board board) {
    if (!_isOrthogonalMove(from, to)) return false;
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;
    final fileStep = fileDiff == 0 ? 0 : (fileDiff > 0 ? 1 : -1);
    final rankStep = rankDiff == 0 ? 0 : (rankDiff > 0 ? 1 : -1);
    var current = Position(file: from.file + fileStep, rank: from.rank + rankStep);
    int piecesJumped = 0;
    while (current != to) {
      final piece = board.getPiece(current);
      if (piece != null) {
        piecesJumped++;
        if (piece.type == PieceType.cannon) return false;
      }
      current = Position(file: current.file + fileStep, rank: current.rank + rankStep);
    }
    return piecesJumped == 1;
  }

  bool _isValidCannonDiagonalMoveOnBoard(Position from, Position to, bool isRedPalace, Board board) {
    final center = Position(file: 4, rank: isRedPalace ? 8 : 1);

    // Case 1: Corner to corner (jumping through center)
    if (from != center && to != center) {
      final fileDiff = (to.file - from.file).abs();
      final rankDiff = (to.rank - from.rank).abs();

      // Corner to corner must be 2 steps diagonally
      if (fileDiff != 2 || rankDiff != 2) {
        return false;
      }

      final centerPiece = board.getPiece(center);
      if (centerPiece != null && centerPiece.type != PieceType.cannon) {
        return true;
      }
      return false;
    }

    // Case 2: Center to corner or corner to center (ONE step diagonal)
    // For cannon, one-step diagonal is NOT allowed (no piece to jump over)
    if (from == center || to == center) {
      final cornerPos = from == center ? to : from;
      final centerPos = center;

      final fileDiff = (cornerPos.file - centerPos.file).abs();
      final rankDiff = (cornerPos.rank - centerPos.rank).abs();

      // One-step diagonal move - NOT allowed for cannon
      if (fileDiff == 1 && rankDiff == 1) {
        return false;
      }

      return false;
    }

    return false;
  }

  bool _isValidSoldierMoveSimple(Piece piece, Position from, Position to) {
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;
    if (piece.color == PieceColor.blue) {
      if (rankDiff == 1 && fileDiff == 0) return true;
      if (rankDiff == 0 && fileDiff.abs() == 1) return true;
      if (from.isInPalace(isRedPalace: false) &&
          to.isInPalace(isRedPalace: false) &&
          rankDiff == 1 && fileDiff.abs() == 1) {
        return _isPalaceDiagonal(from, to, false);
      }
    } else {
      if (rankDiff == -1 && fileDiff == 0) return true;
      if (rankDiff == 0 && fileDiff.abs() == 1) return true;
      if (from.isInPalace(isRedPalace: true) &&
          to.isInPalace(isRedPalace: true) &&
          rankDiff == -1 && fileDiff.abs() == 1) {
        return _isPalaceDiagonal(from, to, true);
      }
    }
    return false;
  }

  /// Undo last move (or last 2 moves in AI mode to undo both player and AI moves)
  void undoMove() {
    if (_moveHistory.isEmpty) return;

    // In AI mode, undo 2 moves (player + AI) to return to player's turn
    // In 2-player mode, undo 1 move
    final movesToUndo = (_gameMode == GameMode.vsAI) ? 2 : 1;

    for (int i = 0; i < movesToUndo && _moveHistory.isNotEmpty; i++) {
      final lastMove = _moveHistory.removeLast();

      // Move piece back to original position
      final piece = _board.getPiece(lastMove.to);
      if (piece != null) {
        _board.setPiece(lastMove.to, null); // Remove from destination
        _board.setPiece(lastMove.from, piece); // Put back to origin
      }

      // Restore captured piece if any
      if (lastMove.capturedPiece != null) {
        _board.setPiece(lastMove.to, lastMove.capturedPiece!);
      }

      // Switch back to previous player
      _currentPlayer = _currentPlayer == PieceColor.blue ? PieceColor.red : PieceColor.blue;

      // Update position history (remove last position)
      final lastFen = StockfishConverter.boardToFEN(_board, _currentPlayer);
      if (_positionHistory.containsKey(lastFen)) {
        final count = _positionHistory[lastFen]!;
        if (count <= 1) {
          _positionHistory.remove(lastFen);
        } else {
          _positionHistory[lastFen] = count - 1;
        }
      }
    }

    // Clear selection and valid moves
    _selectedPosition = null;
    _validMoves = [];
    _isGameOver = false;
    _gameOverReason = null;

    _updateStatusMessage();
    notifyListeners();
  }

  /// DEBUG: Test game over dialog
  void testGameOver(String reason) {
    _isGameOver = true;
    _gameOverReason = reason;

    switch (reason) {
      case 'blue_wins_checkmate':
        _statusMessage = 'Checkmate! Blue (초) wins!';
        break;
      case 'blue_wins_capture':
        _statusMessage = 'Game Over! Blue (초) wins by capturing the King!';
        break;
      case 'red_wins_checkmate':
        _statusMessage = 'Checkmate! Red (한) wins!';
        break;
      case 'red_wins_capture':
        _statusMessage = 'Game Over! Red (한) wins by capturing the King!';
        break;
      case 'threefold_repetition':
        _statusMessage = 'Draw by threefold repetition!';
        break;
      case 'fifty_move_rule':
        _statusMessage = 'Draw by 50-move rule!';
        break;
    }

    notifyListeners();
  }
}
