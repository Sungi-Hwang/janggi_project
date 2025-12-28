import 'package:flutter/services.dart';
import '../models/piece.dart';

/// Represents a position from the EPD opening book
class EPDPosition {
  final String fen;
  final PieceColor activeColor;
  final int moveNumber;
  final PieceSetup? blueSetup;
  final PieceSetup? redSetup;

  const EPDPosition({
    required this.fen,
    required this.activeColor,
    required this.moveNumber,
    this.blueSetup,
    this.redSetup,
  });

  @override
  String toString() =>
      'EPDPosition(fen: $fen, active: $activeColor, move: $moveNumber, blue: $blueSetup, red: $redSetup)';
}

/// Parser for Janggi EPD opening book
/// Loads and processes the janggi.epd file containing 12,417 opening positions
class EPDParser {
  static List<EPDPosition>? _cachedPositions;

  /// Load all positions from the EPD file
  /// Returns cached result if already loaded
  static Future<List<EPDPosition>> loadPositions() async {
    if (_cachedPositions != null) {
      return _cachedPositions!;
    }

    try {
      final epdContent = await rootBundle.loadString('assets/janggi.epd');
      final lines = epdContent.split('\n');
      final positions = <EPDPosition>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final position = _parseLine(trimmed);
        if (position != null) {
          positions.add(position);
        }
      }

      _cachedPositions = positions;
      return positions;
    } catch (e) {
      print('Error loading EPD file: $e');
      return [];
    }
  }

  /// Parse a single EPD line into EPDPosition
  static EPDPosition? _parseLine(String line) {
    try {
      // EPD format: [FEN] [active color] [castling] [en passant] [halfmove] [fullmove]
      // Example: rnba1abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ABNR w - - 0 1
      final parts = line.split(' ');
      if (parts.length < 6) return null;

      final fen = line; // Keep full FEN string
      final activeColor = parts[1] == 'w' ? PieceColor.blue : PieceColor.red;
      final moveNumber = int.tryParse(parts[5]) ?? 1;
      final blueSetup = detectBlueSetup(parts[0]);
      final redSetup = detectRedSetup(parts[0]);

      return EPDPosition(
        fen: fen,
        activeColor: activeColor,
        moveNumber: moveNumber,
        blueSetup: blueSetup,
        redSetup: redSetup,
      );
    } catch (e) {
      print('Error parsing EPD line: $line - $e');
      return null;
    }
  }

  /// Detect Blue piece setup from FEN
  /// Blue pieces are at the bottom (last rank in FEN)
  /// FEN ranks go from top (rank 10) to bottom (rank 1)
  static PieceSetup? detectBlueSetup(String boardPart) {
    try {
      final ranks = boardPart.split('/');
      if (ranks.length != 10) return null;

      final bottomRank = ranks.last; // Blue's back row

      // Pattern matching based on piece arrangement
      // Format: R-?-?-A-_-A-?-?-R where ? are N (horse) or B (elephant)
      // We check positions 1,2,6,7 (files b,c,g,h)

      if (bottomRank.contains('RBNA1ABNR')) {
        // R-B-N-A-_-A-B-N-R = 마상마상 (horse-elephant-horse-elephant)
        return PieceSetup.horseElephantHorseElephant;
      } else if (bottomRank.contains('RBNA1ANBR')) {
        // R-B-N-A-_-A-N-B-R = 마상상마 (horse-elephant-elephant-horse)
        return PieceSetup.horseElephantElephantHorse;
      } else if (bottomRank.contains('RNBA1ABNR')) {
        // R-N-B-A-_-A-B-N-R = 상마마상 (elephant-horse-horse-elephant)
        return PieceSetup.elephantHorseHorseElephant;
      } else if (bottomRank.contains('RNBA1ANBR')) {
        // R-N-B-A-_-A-N-B-R = 상마상마 (elephant-horse-elephant-horse)
        return PieceSetup.elephantHorseElephantHorse;
      }

      return null;
    } catch (e) {
      print('Error detecting Blue setup: $e');
      return null;
    }
  }

  /// Detect Red piece setup from FEN
  /// Red pieces are at the top (first rank in FEN)
  static PieceSetup? detectRedSetup(String boardPart) {
    try {
      final ranks = boardPart.split('/');
      if (ranks.length != 10) return null;

      final topRank = ranks.first; // Red's back row

      // Same pattern matching but with lowercase letters (Red pieces)
      if (topRank.contains('rbna1abnr')) {
        return PieceSetup.horseElephantHorseElephant;
      } else if (topRank.contains('rbna1anbr')) {
        return PieceSetup.horseElephantElephantHorse;
      } else if (topRank.contains('rnba1abnr')) {
        return PieceSetup.elephantHorseHorseElephant;
      } else if (topRank.contains('rnba1anbr')) {
        return PieceSetup.elephantHorseElephantHorse;
      }

      return null;
    } catch (e) {
      print('Error detecting Red setup: $e');
      return null;
    }
  }

  /// Filter positions by piece setup
  static List<EPDPosition> filterBySetup(
    List<EPDPosition> positions,
    PieceSetup? blueSetup,
    PieceSetup? redSetup,
  ) {
    return positions.where((pos) {
      final matchBlue = blueSetup == null || pos.blueSetup == blueSetup;
      final matchRed = redSetup == null || pos.redSetup == redSetup;
      return matchBlue && matchRed;
    }).toList();
  }

  /// Build a move tree: Map<currentFEN, List<possibleNextMoves>>
  /// This allows O(1) lookup of valid moves from any position
  static Map<String, List<String>> buildMoveTree(List<EPDPosition> positions) {
    final moveTree = <String, List<String>>{};

    // Sort positions by move number to ensure chronological order
    final sortedPositions = List<EPDPosition>.from(positions)
      ..sort((a, b) => a.moveNumber.compareTo(b.moveNumber));

    // For each position, we need to find what moves lead to it
    // This requires tracking parent-child relationships
    // For simplicity, we'll use a different approach:
    // Group positions by move number, then by matching board states

    for (int i = 0; i < sortedPositions.length - 1; i++) {
      final current = sortedPositions[i];
      final next = sortedPositions[i + 1];

      // Check if next position is one move after current
      if (next.moveNumber == current.moveNumber ||
          next.moveNumber == current.moveNumber + 1) {
        // Extract the position part (before move counters) for comparison
        final currentKey = normalizeFEN(current.fen);

        if (!moveTree.containsKey(currentKey)) {
          moveTree[currentKey] = [];
        }

        // Add the next position as a possible continuation
        moveTree[currentKey]!.add(next.fen);
      }
    }

    return moveTree;
  }

  /// Normalize FEN for comparison by removing move counters
  /// Keep only the position and active color parts
  static String normalizeFEN(String fen) {
    final parts = fen.split(' ');
    if (parts.length >= 2) {
      // Return position + active color only
      return '${parts[0]} ${parts[1]}';
    }
    return fen;
  }

  /// Get valid next moves from a given FEN position
  static List<String> getValidNextMoves(
    Map<String, List<String>> moveTree,
    String currentFEN,
  ) {
    final normalized = normalizeFEN(currentFEN);
    return moveTree[normalized] ?? [];
  }

  /// Clear cached positions (useful for testing or memory management)
  static void clearCache() {
    _cachedPositions = null;
  }
}
