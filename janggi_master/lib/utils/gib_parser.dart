import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';
import '../stockfish_ffi.dart';
import '../utils/stockfish_converter.dart';

/// Parser for GIB (Game Information Base) files
/// GIB is a format used for Korean Janggi game records
class GibParser {
  /// Parse a GIB file and return list of games
  /// Each GIB file can contain multiple games
  static List<Map<String, dynamic>> parseGibFile(String gibContent) {
    final games = <Map<String, dynamic>>[];
    final lines = gibContent.split('\n');

    Map<String, String>? currentMetadata;
    List<String> currentMoves = [];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Parse metadata in [Key "Value"] format
      if (line.startsWith('[') && line.endsWith(']')) {
        final match = RegExp(r'\[([^\]]+)\s+"([^"]+)"\]').firstMatch(line);
        if (match != null) {
          final key = match.group(1)?.trim() ?? '';
          final value = match.group(2)?.trim() ?? '';

          // Start new game if we see metadata after having moves
          if (currentMetadata != null &&
              currentMoves.isNotEmpty &&
              key.isNotEmpty) {
            games.add(_createGameRecord(currentMetadata, currentMoves));
            currentMetadata = {};
            currentMoves = [];
          }

          currentMetadata ??= {};
          currentMetadata[key] = value;
        }
      }
      // Parse moves (format: 1. move1 2. move2 ...)
      else if (RegExp(r'^\d+\.').hasMatch(line)) {
        // Extract moves from numbered format
        final moveMatches = RegExp(r'\d+\.\s*([^\s]+)').allMatches(line);
        for (var match in moveMatches) {
          final move = match.group(1);
          if (move != null && move.isNotEmpty) {
            currentMoves.add(move);
          }
        }
      }
    }

    // Add last game
    if (currentMetadata != null && currentMoves.isNotEmpty) {
      games.add(_createGameRecord(currentMetadata, currentMoves));
    }

    return games;
  }

  /// Create a game record from metadata and moves
  static Map<String, dynamic> _createGameRecord(
    Map<String, String> metadata,
    List<String> moves,
  ) {
    // Extract FEN from "판" field
    String? fenPosition;
    if (metadata.containsKey('판')) {
      final fenParts = metadata['판']!.split(' ');
      if (fenParts.isNotEmpty) {
        fenPosition = fenParts[0]; // Just the board position part
      }
    }

    return {
      'metadata': metadata,
      'moves': List<String>.from(moves),
      'fen': fenPosition,
      'title': metadata['초나라명'] ?? metadata['대회명칭'] ?? '묘수풀이',
      'description': metadata['비고'] ?? '',
      'bluePlayer': metadata['초나라명'] ?? '초',
      'redPlayer': metadata['한나라명'] ?? '한',
      'result': metadata['결과'] ?? '',
    };
  }

  /// Parse a single GIB game entry
  static Map<String, dynamic> parseGib(String gibContent) {
    final games = parseGibFile(gibContent);
    return games.isNotEmpty
        ? games.first
        : {
            'metadata': <String, String>{},
            'moves': <String>[],
            'fen': null,
            'title': '묘수풀이',
            'description': '',
          };
  }

  /// Parse FEN string to Board (if GIB contains FEN position)
  static Board? fenToBoard(String fen) {
    try {
      final parts = fen.split(' ');
      if (parts.isEmpty) return null;

      final board = Board();
      board.clear(); // Clear default setup

      final rows = parts[0].split('/');
      if (rows.length != 10) return null;

      for (int rank = 0; rank < 10; rank++) {
        int file = 0;
        final row = rows[rank];

        for (int i = 0; i < row.length; i++) {
          final char = row[i];

          // Handle empty squares (numbers)
          if (char.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
              char.codeUnitAt(0) <= '9'.codeUnitAt(0)) {
            file += int.parse(char);
            continue;
          }

          // Parse piece
          final piece = _charToPiece(char);
          if (piece != null && file < 9) {
            board.setPiece(Position(file: file, rank: 9 - rank), piece);
          }
          file++;
        }
      }

      return board;
    } catch (e) {
      return null;
    }
  }

  /// Convert FEN character to Piece
  static Piece? _charToPiece(String char) {
    // Uppercase = Blue (초), Lowercase = Red (한)
    final isBlue = char == char.toUpperCase();
    final color = isBlue ? PieceColor.blue : PieceColor.red;
    final c = char.toLowerCase();

    PieceType? type;
    switch (c) {
      case 'k':
        type = PieceType.general;
        break;
      case 'a':
        type = PieceType.guard;
        break;
      case 'n':
        type = PieceType.horse;
        break;
      case 'b':
        type = PieceType.elephant;
        break;
      case 'r':
        type = PieceType.chariot;
        break;
      case 'c':
        type = PieceType.cannon;
        break;
      case 'p':
        type = PieceType.soldier;
        break;
      default:
        return null;
    }

    return Piece(type: type, color: color);
  }

  /// Convert Board to FEN string
  static String boardToFen(Board board, PieceColor currentPlayer) {
    final buffer = StringBuffer();

    // Board position (rank 9 to 0, top to bottom)
    for (int rank = 9; rank >= 0; rank--) {
      int emptyCount = 0;

      for (int file = 0; file < 9; file++) {
        final piece = board.getPiece(Position(file: file, rank: rank));

        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            buffer.write(emptyCount);
            emptyCount = 0;
          }

          final char = _pieceToChar(piece);
          buffer.write(char);
        }
      }

      if (emptyCount > 0) {
        buffer.write(emptyCount);
      }

      if (rank > 0) {
        buffer.write('/');
      }
    }

    // Current player (w=Blue, b=Red)
    buffer.write(' ');
    buffer.write(currentPlayer == PieceColor.blue ? 'w' : 'b');

    // Additional fields (castling, en passant, etc. - not used in Janggi)
    buffer.write(' - - 0 1');

    return buffer.toString();
  }

  /// Convert Piece to FEN character
  static String _pieceToChar(Piece piece) {
    String char;
    switch (piece.type) {
      case PieceType.general:
        char = 'k';
        break;
      case PieceType.guard:
        char = 'a';
        break;
      case PieceType.horse:
        char = 'n';
        break;
      case PieceType.elephant:
        char = 'b';
        break;
      case PieceType.chariot:
        char = 'r';
        break;
      case PieceType.cannon:
        char = 'c';
        break;
      case PieceType.soldier:
        char = 'p';
        break;
    }

    // Blue = uppercase, Red = lowercase
    return piece.color == PieceColor.blue ? char.toUpperCase() : char;
  }

  /// Parse GIB move notation to from/to positions
  /// GIB format: "41漢兵42" means rank 4, file 1 → rank 4, file 2
  ///
  /// GIB coordinate system:
  /// - YX format (rank, file) - first digit is rank, second is file
  /// - 1-based indexing (files 1-9, ranks 1-10)
  /// - Ranks numbered from Red's side: rank 1 = top (board rank 9), rank 10 = bottom (board rank 0)
  /// - Files numbered left to right: file 1 = left (board file 0), file 9 = right (board file 8)
  ///
  /// Conversion formulas:
  /// - boardRank = 10 - gibRank
  /// - boardFile = gibFile - 1
  ///
  /// Example: "41" = GIB rank 4, file 1 = board rank 6, file 0
  static Map<String, Position>? parseGibMove(String gibMove) {
    // Remove any trailing annotations (장군, etc.)
    final cleanMove = gibMove.replaceAll(RegExp(r'[가-힣]+$'), '').trim();

    // Extract coordinate part (should be at least 4 digits)
    final coordMatch = RegExp(r'(\d)(\d)[^\d]*(\d)(\d)').firstMatch(cleanMove);
    if (coordMatch == null) return null;

    try {
      // Parse the 4 digits: YX YX format (rank-file rank-file)
      var gibFromRank = int.parse(
          coordMatch.group(1)!); // First digit = rank (1-10, 0 means 10)
      final gibFromFile =
          int.parse(coordMatch.group(2)!); // Second digit = file (1-9)
      var gibToRank = int.parse(
          coordMatch.group(3)!); // Third digit = rank (1-10, 0 means 10)
      final gibToFile =
          int.parse(coordMatch.group(4)!); // Fourth digit = file (1-9)

      // Some GIB files encode rank 10 as 0.
      if (gibFromRank == 0) gibFromRank = 10;
      if (gibToRank == 0) gibToRank = 10;

      // Validate GIB coordinates (1-based)
      if (gibFromRank < 1 ||
          gibFromRank > 10 ||
          gibFromFile < 1 ||
          gibFromFile > 9 ||
          gibToRank < 1 ||
          gibToRank > 10 ||
          gibToFile < 1 ||
          gibToFile > 9) {
        return null;
      }

      // Convert GIB coordinates to 0-based board coordinates
      final fromRank = 10 - gibFromRank; // GIB rank 1 (top) = board rank 9
      final fromFile = gibFromFile - 1; // GIB file 1 (left) = board file 0
      final toRank = 10 - gibToRank;
      final toFile = gibToFile - 1;

      return {
        'from': Position(file: fromFile, rank: fromRank),
        'to': Position(file: toFile, rank: toRank),
      };
    } catch (e) {
      return null;
    }
  }

  /// Replay moves on a board and return the resulting position
  /// Returns null if replay fails
  static Board? replayMovesToPosition(List<String> gibMoves, {int? upToMove}) {
    final board = Board();
    board.setupInitialPosition();

    final moveCount = upToMove ?? gibMoves.length;
    final movesToReplay = gibMoves.take(moveCount).toList();

    for (var i = 0; i < movesToReplay.length; i++) {
      final gibMove = movesToReplay[i];
      final positions = parseGibMove(gibMove);

      if (positions == null) {
        // Skip invalid moves
        continue;
      }

      final from = positions['from']!;
      final to = positions['to']!;

      // Make the move on the board
      board.movePiece(from, to);
    }

    return board;
  }

  /// Evaluate position score using Stockfish's new analyze function
  /// Returns evaluation in format: {'type': 'cp'/'mate', 'value': score}
  /// This uses the new stockfish_analyze C++ function that extracts score directly
  static Map<String, dynamic>? _evaluatePosition(
      Board board, PieceColor currentPlayer) {
    try {
      final fen = StockfishConverter.boardToFEN(board, currentPlayer);

      // Use the new analyze() function that gets score directly from Thread->rootMoves
      final result = StockfishFFI.analyze(fen, depth: 10);

      if (result != null) {
        return {
          'type': result['type'],
          'value': result['value'],
        };
      }

      // Fallback: position might be unclear
      return {'type': 'cp', 'value': 0};
    } catch (e) {
      print('ERROR in _evaluatePosition: $e');
      return null;
    }
  }

  /// Find the critical puzzle position using reverse analysis
  /// Returns the move index where the decisive sequence begins
  /// Uses Stockfish to detect cp -> mate transition
  static Future<int> findPuzzleStartPosition(
    List<String> gibMoves, {
    int minMovesFromEnd = 5,
    int maxMovesFromEnd = 30,
  }) async {
    // Start from near the end and work backwards
    final totalMoves = gibMoves.length;
    final startSearchFrom = (totalMoves - minMovesFromEnd).clamp(0, totalMoves);
    final endSearchAt = (totalMoves - maxMovesFromEnd).clamp(0, totalMoves);

    String? previousType;

    // Search backwards for cp -> mate transition
    for (int moveIdx = startSearchFrom; moveIdx >= endSearchAt; moveIdx--) {
      // Replay to this position
      final board = replayMovesToPosition(gibMoves, upToMove: moveIdx);
      if (board == null) continue;

      // Determine current player
      final currentPlayer =
          (moveIdx % 2 == 0) ? PieceColor.blue : PieceColor.red;

      // Evaluate position
      final eval = _evaluatePosition(board, currentPlayer);
      if (eval == null) continue;

      final currentType = eval['type'] as String;

      // Detect transition: mate -> cp (going backwards means cp -> mate going forwards)
      if (previousType == 'mate' && currentType == 'cp') {
        // Found the transition! The next position (moveIdx + 1) is where mate sequence starts
        return moveIdx + 1;
      }

      previousType = currentType;
    }

    // Fallback: return 70% if no critical position found
    return (totalMoves * 0.7).round().clamp(10, totalMoves - 5);
  }
}
