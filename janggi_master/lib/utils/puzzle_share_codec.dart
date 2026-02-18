import 'dart:convert';

import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';
import 'stockfish_converter.dart';

class PuzzleShareCodec {
  static const String prefix = 'JM_PUZZLE_V1:';
  static const String _typeSetup = 'setup';
  static const String _typeFull = 'full';

  static String encodeSetupFromBoard({
    required String title,
    required Board board,
    required PieceColor bottomColor,
  }) {
    final fen = StockfishConverter.boardToFEN(board, bottomColor);
    final toMove = bottomColor == PieceColor.red ? 'red' : 'blue';
    return encodeSetup(
      title: title,
      fen: fen,
      toMove: toMove,
    );
  }

  static String encodeSetup({
    required String title,
    required String fen,
    required String toMove,
  }) {
    final payload = <String, dynamic>{
      'v': 1,
      't': _typeSetup,
      'title': title.trim(),
      'fen': fen.trim(),
      'toMove': _normalizeToMove(toMove),
    };
    return _encodePayload(payload);
  }

  static String encodePuzzle(Map<String, dynamic> puzzle) {
    final solution = List<String>.from(puzzle['solution'] ?? <String>[]);
    final payload = <String, dynamic>{
      'v': 1,
      't': _typeFull,
      'title': (puzzle['title'] as String? ?? '').trim(),
      'fen': (puzzle['fen'] as String? ?? '').trim(),
      'solution': solution,
      'toMove': _normalizeToMove(puzzle['toMove'] as String?),
      'mateIn': _resolveMateIn(puzzle['mateIn'], solution),
    };
    return _encodePayload(payload);
  }

  static Map<String, dynamic> decode(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      throw const FormatException('Empty share code.');
    }

    late final Map<String, dynamic> payload;
    if (input.startsWith(prefix)) {
      final encoded = input.substring(prefix.length);
      final decoded = utf8.decode(base64Url.decode(encoded));
      final map = jsonDecode(decoded);
      if (map is! Map) {
        throw const FormatException('Invalid share payload.');
      }
      payload = Map<String, dynamic>.from(map);
    } else {
      final map = jsonDecode(input);
      if (map is! Map) {
        throw const FormatException('Invalid JSON payload.');
      }
      payload = Map<String, dynamic>.from(map);
    }

    final fen = (payload['fen'] as String?)?.trim() ?? '';
    if (fen.isEmpty) {
      throw const FormatException('Missing FEN.');
    }

    final solution = payload['solution'] is List
        ? List<String>.from(payload['solution'])
        : <String>[];
    final type = payload['t'] == _typeFull || solution.isNotEmpty
        ? _typeFull
        : _typeSetup;

    return <String, dynamic>{
      'v': payload['v'] is num ? (payload['v'] as num).toInt() : 1,
      't': type,
      'title': (payload['title'] as String? ?? '').trim(),
      'fen': fen,
      'toMove': _normalizeToMove(payload['toMove'] as String?),
      'solution': solution,
      'mateIn': _resolveMateIn(payload['mateIn'], solution),
    };
  }

  static Map<String, dynamic> toSavablePuzzle(Map<String, dynamic> decoded) {
    final solution = List<String>.from(decoded['solution'] ?? <String>[]);
    return <String, dynamic>{
      'title': (decoded['title'] as String? ?? '').trim(),
      'fen': decoded['fen'] as String,
      'solution': solution,
      'mateIn': _resolveMateIn(decoded['mateIn'], solution),
      'toMove': _normalizeToMove(decoded['toMove'] as String?),
    };
  }

  static Board? parseFenBoard(String fen) {
    try {
      final board = Board();
      final parts = fen.trim().split(' ');
      if (parts.isEmpty) return null;
      final ranks = parts.first.split('/');
      if (ranks.length < 10) return null;

      for (int fenRank = 0; fenRank < 10; fenRank++) {
        int file = 0;
        for (final char in ranks[fenRank].split('')) {
          final digit = int.tryParse(char);
          if (digit != null) {
            file += digit;
            continue;
          }
          final piece = _fenCharToPiece(char);
          if (piece != null && file >= 0 && file < 9) {
            final boardRank = 9 - fenRank;
            board.setPiece(Position(file: file, rank: boardRank), piece);
          }
          file++;
        }
      }
      return board;
    } catch (_) {
      return null;
    }
  }

  static String _encodePayload(Map<String, dynamic> payload) {
    final jsonText = jsonEncode(payload);
    final encoded = base64Url.encode(utf8.encode(jsonText));
    return '$prefix$encoded';
  }

  static Piece? _fenCharToPiece(String char) {
    if (char.isEmpty) return null;
    final isBlue = char == char.toUpperCase();
    final lower = char.toLowerCase();

    PieceType? type;
    switch (lower) {
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
    }

    if (type == null) return null;
    return Piece(type: type, color: isBlue ? PieceColor.blue : PieceColor.red);
  }

  static String _normalizeToMove(String? raw) {
    return raw == 'red' ? 'red' : 'blue';
  }

  static int _resolveMateIn(dynamic rawMateIn, List<String> solution) {
    final fromPayload = rawMateIn is num ? rawMateIn.toInt() : null;
    if (fromPayload != null && fromPayload > 0) return fromPayload;
    final bySolution = (solution.length + 1) ~/ 2;
    return bySolution < 1 ? 1 : bySolution;
  }
}
