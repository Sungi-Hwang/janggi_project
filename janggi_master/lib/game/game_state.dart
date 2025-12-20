import 'package:flutter/foundation.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';
import '../models/move.dart';
import '../stockfish_ffi.dart';
import '../utils/stockfish_converter.dart';

/// Manages the game state and logic
class GameState extends ChangeNotifier {
  final Board _board = Board();
  PieceColor _currentPlayer = PieceColor.blue;  // Blue (초) starts first
  Position? _selectedPosition;
  List<Position> _validMoves = [];
  List<Move> _moveHistory = [];
  bool _isEngineThinking = false;
  String _statusMessage = 'Blue to move (초 선공)';
  
  // Getters
  Board get board => _board;
  PieceColor get currentPlayer => _currentPlayer;
  Position? get selectedPosition => _selectedPosition;
  List<Position> get validMoves => _validMoves;
  List<Move> get moveHistory => _moveHistory;
  bool get isEngineThinking => _isEngineThinking;
  String get statusMessage => _statusMessage;

  GameState() {
    _initializeGame();
  }

  void _initializeGame() {
    _board.setupInitialPosition();
    _currentPlayer = PieceColor.blue;  // Blue (초) starts first
    _selectedPosition = null;
    _validMoves = [];
    _moveHistory = [];
    _statusMessage = 'Blue to move (초 선공)';
    notifyListeners();
  }

  /// Start a new game
  void newGame() {
    _initializeGame();
  }

  /// Handle square tap
  Future<void> onSquareTapped(Position position) async {
    debugPrint('onSquareTapped: position=$position');
    if (_isEngineThinking) {
      debugPrint('onSquareTapped: engine is thinking, ignoring');
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
      await _makeMove(_selectedPosition!, position);
      _selectedPosition = null;
      _validMoves = [];
      notifyListeners();
    } else {
      debugPrint('onSquareTapped: position $position is NOT a valid move. Valid moves are: $_validMoves');
    }
  }

  /// Make a move on the board
  Future<void> _makeMove(Position from, Position to) async {
    final piece = _board.getPiece(from);
    if (piece == null) return;

    debugPrint('_makeMove: Moving $piece from $from to $to');

    // Make the move
    final captured = _board.movePiece(from, to);
    debugPrint('_makeMove: Move completed. Captured: $captured');

    // Record the move
    final move = Move(from: from, to: to, capturedPiece: captured);
    _moveHistory.add(move);

    // Convert to UCI and log
    final uciMove = StockfishConverter.moveToUCI(from, to);
    debugPrint('_makeMove: UCI notation: $uciMove');
    debugPrint('_makeMove: Full move history UCI: ${_moveHistory.map((m) => m.toUCI()).toList()}');

    // Switch player
    _currentPlayer = _currentPlayer == PieceColor.blue
        ? PieceColor.red
        : PieceColor.blue;

    _statusMessage = _currentPlayer == PieceColor.blue
        ? 'Blue to move (초)'
        : 'Red to move (한)';

    debugPrint('_makeMove: Calling notifyListeners');
    notifyListeners();

    // AI enabled - Stockfish is now working!
    // If it's now AI's turn (Red/한), get AI move
    if (_currentPlayer == PieceColor.red) {
      await _getAIMove();
    }
  }

  /// Get AI move from Stockfish
  Future<void> _getAIMove() async {
    _isEngineThinking = true;
    _statusMessage = 'AI thinking...';
    notifyListeners();

    try {
      debugPrint('_getAIMove: Starting AI move calculation');

      // Build moves list for position command
      final moves = _moveHistory.map((m) => m.toUCI()).toList();
      debugPrint('_getAIMove: Move history: $moves');

      // Set position
      debugPrint('_getAIMove: Setting position...');
      StockfishFFI.setPosition(moves: moves);

      // Get best move with timeout
      debugPrint('_getAIMove: Requesting best move...');
      final bestMoveUCI = await Future.delayed(
        Duration.zero,
        () => StockfishFFI.getBestMove(depth: 5), // Reduced depth for faster response
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

        final from = StockfishConverter.fromUCI(fromUCI);
        final to = StockfishConverter.fromUCI(toUCI);

        debugPrint('_getAIMove: AI moving from $from to $to');

        // Check if there's a piece at the from position
        final piece = _board.getPiece(from);
        debugPrint('_getAIMove: Piece at $from: $piece');

        if (piece == null) {
          debugPrint('_getAIMove: ERROR - No piece at $from! Cannot make move.');
          _statusMessage = 'AI move failed - no piece at source';
          return;
        }

        // Make the AI move
        final captured = _board.movePiece(from, to);
        debugPrint('_getAIMove: Move result - captured: $captured');

        final move = Move(from: from, to: to, capturedPiece: captured);
        _moveHistory.add(move);

        // Switch back to player (Blue)
        _currentPlayer = PieceColor.blue;
        _statusMessage = 'Blue to move (초)';
      } else {
        debugPrint('_getAIMove: No valid move received from Stockfish');
        _statusMessage = 'AI failed to move';
        _currentPlayer = PieceColor.blue; // Give turn back to player
      }
    } catch (e, stackTrace) {
      _statusMessage = 'AI error: $e';
      debugPrint('AI move error: $e');
      debugPrint('Stack trace: $stackTrace');
      _currentPlayer = PieceColor.blue; // Give turn back to player on error
    } finally {
      _isEngineThinking = false;
      debugPrint('_getAIMove: Calling final notifyListeners');
      notifyListeners();
    }
  }

  /// Get valid moves for a position based on Janggi rules
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
          moves.add(to);
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
        if (!_isOrthogonalMove(from, to)) return false;
        return _isPathClear(from, to);

      case PieceType.cannon:
        // Cannon moves orthogonally, must jump over exactly one piece
        // Cannot capture another cannon
        if (!_isOrthogonalMove(from, to)) return false;
        final targetPiece = _board.getPiece(to);
        if (targetPiece != null && targetPiece.type == PieceType.cannon) {
          return false;
        }
        return _isValidCannonMove(from, to);

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
      // In palace, can move along diagonals forward
      if (from.isInPalace(isRedPalace: false) &&
          to.isInPalace(isRedPalace: false) &&
          rankDiff == 1 && fileDiff.abs() == 1) {
        return true;
      }
    } else {
      // Red moves down (decreasing rank)
      // Forward: one step down
      if (rankDiff == -1 && fileDiff == 0) return true;
      // Sideways: one step left or right (same rank)
      if (rankDiff == 0 && fileDiff.abs() == 1) return true;
      // In palace, can move along diagonals forward
      if (from.isInPalace(isRedPalace: true) &&
          to.isInPalace(isRedPalace: true) &&
          rankDiff == -1 && fileDiff.abs() == 1) {
        return true;
      }
    }

    return false;
  }

  bool _isOneStepMove(Position from, Position to) {
    return (to.file - from.file).abs() <= 1 &&
        (to.rank - from.rank).abs() <= 1;
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

  /// Undo last move
  void undoMove() {
    if (_moveHistory.isEmpty) return;

    // TODO: Implement proper undo with captured pieces
    _statusMessage = 'Undo not yet implemented';
    notifyListeners();
  }
}
