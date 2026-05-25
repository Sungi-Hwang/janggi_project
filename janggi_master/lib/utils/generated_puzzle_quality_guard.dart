import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';
import 'puzzle_share_codec.dart';

class GeneratedPuzzleQualityGuard {
  const GeneratedPuzzleQualityGuard._();

  static bool hasImmediateGeneralCapture({
    required String fen,
    required String? toMove,
  }) {
    return immediateGeneralCaptureMoves(
      fen: fen,
      toMove: toMove,
    ).isNotEmpty;
  }

  static List<String> immediateGeneralCaptureMoves({
    required String fen,
    required String? toMove,
  }) {
    final board = PuzzleShareCodec.parseFenBoard(fen);
    if (board == null) return const <String>[];

    final player = _colorFromToMove(toMove, fen);
    final defender = _opponent(player);
    final defenderGeneral = board.findPiece(PieceType.general, defender);
    if (defenderGeneral == null) return const <String>[];

    final moves = <String>[];
    for (final from in board.findAllPieces(player)) {
      final piece = board.getPiece(from);
      if (piece == null) continue;
      if (_canAttack(board, piece, from, defenderGeneral)) {
        moves.add(_toUci(from, defenderGeneral));
      }
    }
    moves.sort();
    return moves;
  }

  static PieceColor _colorFromToMove(String? raw, String fen) {
    if (raw == 'red') return PieceColor.red;
    if (raw == 'blue') return PieceColor.blue;
    final parts = fen.trim().split(RegExp(r'\s+'));
    return parts.length > 1 && parts[1] == 'b'
        ? PieceColor.red
        : PieceColor.blue;
  }

  static PieceColor _opponent(PieceColor color) =>
      color == PieceColor.blue ? PieceColor.red : PieceColor.blue;

  static bool _canAttack(
    Board board,
    Piece piece,
    Position from,
    Position to,
  ) {
    final target = board.getPiece(to);
    if (target != null && target.color == piece.color) return false;

    switch (piece.type) {
      case PieceType.general:
      case PieceType.guard:
        if (!from.isInPalace(isRedPalace: piece.color == PieceColor.red) ||
            !to.isInPalace(isRedPalace: piece.color == PieceColor.red)) {
          return false;
        }
        return _isOneStepMove(from, to);
      case PieceType.horse:
        return _isHorseMove(board, from, to);
      case PieceType.elephant:
        return _isElephantMove(board, from, to);
      case PieceType.chariot:
        if (_isOrthogonalMove(from, to)) {
          return _isPathClear(board, from, to);
        }
        final palaceColor = _sharedPalaceColor(from, to);
        if (palaceColor == null) return false;
        return _isValidPalaceDiagonalMove(from, to, palaceColor) &&
            _isPalaceDiagonalPathClear(board, from, to, palaceColor);
      case PieceType.cannon:
        if (target != null && target.type == PieceType.cannon) return false;
        if (_isOrthogonalMove(from, to)) {
          return _isCannonMove(board, from, to);
        }
        final palaceColor = _sharedPalaceColor(from, to);
        if (palaceColor == null) return false;
        return _isValidPalaceDiagonalMove(from, to, palaceColor) &&
            _isCannonDiagonalMove(board, from, to, palaceColor);
      case PieceType.soldier:
        return _isSoldierMove(piece, from, to);
    }
  }

  static bool _isHorseMove(Board board, Position from, Position to) {
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;
    if (fileDiff.abs() == 2 && rankDiff.abs() == 1) {
      final blockPos = Position(
        file: from.file + (fileDiff > 0 ? 1 : -1),
        rank: from.rank,
      );
      return board.getPiece(blockPos) == null;
    }
    if (fileDiff.abs() == 1 && rankDiff.abs() == 2) {
      final blockPos = Position(
        file: from.file,
        rank: from.rank + (rankDiff > 0 ? 1 : -1),
      );
      return board.getPiece(blockPos) == null;
    }
    return false;
  }

  static bool _isElephantMove(Board board, Position from, Position to) {
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;
    if (fileDiff.abs() == 3 && rankDiff.abs() == 2) {
      final block1 = Position(
        file: from.file + (fileDiff > 0 ? 1 : -1),
        rank: from.rank,
      );
      final block2 = Position(
        file: from.file + (fileDiff > 0 ? 2 : -2),
        rank: from.rank + (rankDiff > 0 ? 1 : -1),
      );
      return board.getPiece(block1) == null && board.getPiece(block2) == null;
    }
    if (fileDiff.abs() == 2 && rankDiff.abs() == 3) {
      final block1 = Position(
        file: from.file,
        rank: from.rank + (rankDiff > 0 ? 1 : -1),
      );
      final block2 = Position(
        file: from.file + (fileDiff > 0 ? 1 : -1),
        rank: from.rank + (rankDiff > 0 ? 2 : -2),
      );
      return board.getPiece(block1) == null && board.getPiece(block2) == null;
    }
    return false;
  }

  static bool _isCannonMove(Board board, Position from, Position to) {
    final screen = _screenPieces(board, from, to);
    return screen.length == 1 && screen.single.type != PieceType.cannon;
  }

  static bool _isCannonDiagonalMove(
    Board board,
    Position from,
    Position to,
    bool isRedPalace,
  ) {
    final center = Position(file: 4, rank: isRedPalace ? 8 : 1);
    if (from == center || to == center) return false;
    if ((to.file - from.file).abs() != 2 || (to.rank - from.rank).abs() != 2) {
      return false;
    }
    final centerPiece = board.getPiece(center);
    return centerPiece != null && centerPiece.type != PieceType.cannon;
  }

  static List<Piece> _screenPieces(Board board, Position from, Position to) {
    if (!_isOrthogonalMove(from, to)) return const <Piece>[];
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;
    final fileStep = fileDiff == 0 ? 0 : (fileDiff > 0 ? 1 : -1);
    final rankStep = rankDiff == 0 ? 0 : (rankDiff > 0 ? 1 : -1);
    var current = Position(
      file: from.file + fileStep,
      rank: from.rank + rankStep,
    );
    final pieces = <Piece>[];
    while (current != to) {
      final piece = board.getPiece(current);
      if (piece != null) pieces.add(piece);
      current = Position(
        file: current.file + fileStep,
        rank: current.rank + rankStep,
      );
    }
    return pieces;
  }

  static bool _isSoldierMove(Piece piece, Position from, Position to) {
    final fileDiff = to.file - from.file;
    final rankDiff = to.rank - from.rank;
    if (piece.color == PieceColor.blue) {
      if (rankDiff == 1 && fileDiff == 0) return true;
      if (rankDiff == 0 && fileDiff.abs() == 1) return true;
      if (from.isInPalace(isRedPalace: false) &&
          to.isInPalace(isRedPalace: false) &&
          rankDiff == 1 &&
          fileDiff.abs() == 1) {
        return _isPalaceDiagonal(from, to, false);
      }
    } else {
      if (rankDiff == -1 && fileDiff == 0) return true;
      if (rankDiff == 0 && fileDiff.abs() == 1) return true;
      if (from.isInPalace(isRedPalace: true) &&
          to.isInPalace(isRedPalace: true) &&
          rankDiff == -1 &&
          fileDiff.abs() == 1) {
        return _isPalaceDiagonal(from, to, true);
      }
    }
    return false;
  }

  static bool _isOneStepMove(Position from, Position to) {
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

  static bool _isOrthogonalMove(Position from, Position to) {
    return from.file == to.file || from.rank == to.rank;
  }

  static bool _isPathClear(Board board, Position from, Position to) {
    if (!_isOrthogonalMove(from, to)) return false;
    return _screenPieces(board, from, to).isEmpty;
  }

  static bool? _sharedPalaceColor(Position from, Position to) {
    if (from.isInPalace(isRedPalace: false) &&
        to.isInPalace(isRedPalace: false)) {
      return false;
    }
    if (from.isInPalace(isRedPalace: true) &&
        to.isInPalace(isRedPalace: true)) {
      return true;
    }
    return null;
  }

  static bool _isPalaceDiagonal(Position from, Position to, bool isRedPalace) {
    final center = Position(file: 4, rank: isRedPalace ? 8 : 1);
    final corners = _palaceCorners(isRedPalace);
    for (final corner in corners) {
      if ((from == center && to == corner) ||
          (from == corner && to == center)) {
        return true;
      }
    }
    return false;
  }

  static bool _isValidPalaceDiagonalMove(
    Position from,
    Position to,
    bool isRedPalace,
  ) {
    final fileDiff = (to.file - from.file).abs();
    final rankDiff = (to.rank - from.rank).abs();
    if (fileDiff != rankDiff) return false;
    final center = Position(file: 4, rank: isRedPalace ? 8 : 1);
    final corners = _palaceCorners(isRedPalace);
    if (from == center) return corners.contains(to);
    if (to == center) return corners.contains(from);
    if (!corners.contains(from) || !corners.contains(to)) return false;
    return from.file != to.file && from.rank != to.rank;
  }

  static bool _isPalaceDiagonalPathClear(
    Board board,
    Position from,
    Position to,
    bool isRedPalace,
  ) {
    if ((to.file - from.file).abs() == 1 && (to.rank - from.rank).abs() == 1) {
      return true;
    }
    final center = Position(file: 4, rank: isRedPalace ? 8 : 1);
    if (from == center || to == center) return true;
    return board.getPiece(center) == null;
  }

  static List<Position> _palaceCorners(bool isRedPalace) {
    final lowRank = isRedPalace ? 7 : 0;
    final highRank = isRedPalace ? 9 : 2;
    return <Position>[
      Position(file: 3, rank: lowRank),
      Position(file: 5, rank: lowRank),
      Position(file: 3, rank: highRank),
      Position(file: 5, rank: highRank),
    ];
  }

  static String _toUci(Position from, Position to) {
    String square(Position position) {
      final file = String.fromCharCode('a'.codeUnitAt(0) + position.file);
      return '$file${position.rank + 1}';
    }

    return '${square(from)}${square(to)}';
  }
}
