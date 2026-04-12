import 'dart:convert';
import 'dart:io';

import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';

class GibDecodedContent {
  const GibDecodedContent({
    required this.text,
    required this.encoding,
  });

  final String text;
  final String encoding;
}

class GibNormalizedGame {
  const GibNormalizedGame({
    required this.sourceId,
    required this.sourceType,
    required this.sourceUrl,
    required this.downloadUrl,
    required this.localPath,
    required this.gameId,
    required this.gameIndex,
    required this.title,
    required this.round,
    required this.date,
    required this.players,
    required this.result,
    required this.setupBlue,
    required this.setupRed,
    required this.moves,
    required this.moveCount,
    required this.initialFen,
    required this.rawMetadata,
    required this.encoding,
  });

  final String sourceId;
  final String sourceType;
  final String? sourceUrl;
  final String? downloadUrl;
  final String localPath;
  final String gameId;
  final int gameIndex;
  final String title;
  final String? round;
  final String? date;
  final Map<String, String?> players;
  final String? result;
  final String? setupBlue;
  final String? setupRed;
  final List<String> moves;
  final int moveCount;
  final String? initialFen;
  final Map<String, String> rawMetadata;
  final String encoding;

  Map<String, dynamic> toJson() {
    return {
      'sourceId': sourceId,
      'sourceType': sourceType,
      'sourceUrl': sourceUrl,
      'downloadUrl': downloadUrl,
      'localPath': localPath,
      'gameId': gameId,
      'gameIndex': gameIndex,
      'title': title,
      'round': round,
      'date': date,
      'players': players,
      'result': result,
      'setupBlue': setupBlue,
      'setupRed': setupRed,
      'moves': moves,
      'moveCount': moveCount,
      'initialFen': initialFen,
      'rawMetadata': rawMetadata,
      'encoding': encoding,
    };
  }
}

class GibParser {
  static final RegExp _metadataPattern = RegExp(r'\[([^\]"]+)\s*"([^"]*)"\]');
  static final RegExp _numberedMovePattern = RegExp(r'\b\d+\.\s*([^\s]+)');
  static final RegExp _coordPattern = RegExp(r'(\d)(\d)[^\d]*(\d)(\d)');

  static const Map<String, String> _metadataKeyAliases = {
    'title': 'title',
    'event': 'title',
    'gametitle': 'title',
    '대회명': 'title',
    '대국명': 'title',
    'round': 'round',
    '회전': 'round',
    'date': 'date',
    '대국일자': 'date',
    'blueplayer': 'bluePlayer',
    '초대국자': 'bluePlayer',
    'redplayer': 'redPlayer',
    '한대국자': 'redPlayer',
    'hanplayer1': 'bluePlayer',
    'hanplayer2': 'redPlayer',
    'result': 'result',
    '대국결과': 'result',
    'bluesetup': 'setupBlue',
    '초차림': 'setupBlue',
    'redsetup': 'setupRed',
    '한차림': 'setupRed',
    'setupblue': 'setupBlue',
    'setupred': 'setupRed',
    'fen': 'initialFen',
    'initialfen': 'initialFen',
    'position': 'initialFen',
    'board': 'initialFen',
  };

  static List<Map<String, dynamic>> parseGibFile(String gibContent) {
    final normalized = parseNormalizedGames(
      gibContent,
      sourceId: 'legacy',
      sourceType: 'legacy',
      sourceUrl: null,
      localPath: '',
      encoding: 'utf8',
    );
    return normalized.map(_legacyGameRecordFromNormalized).toList();
  }

  static Map<String, dynamic> parseGib(String gibContent) {
    final games = parseGibFile(gibContent);
    return games.isNotEmpty
        ? games.first
        : {
            'metadata': <String, String>{},
            'moves': <String>[],
            'fen': null,
            'title': 'Untitled GIB',
            'description': '',
          };
  }

  static GibDecodedContent decodeBytes(
    List<int> bytes, {
    String? sourceLabel,
  }) {
    final utf8Decoded = _tryDecodeUtf8(bytes);
    if (utf8Decoded != null && _looksDecoded(utf8Decoded)) {
      return GibDecodedContent(text: utf8Decoded, encoding: 'utf8');
    }

    if (Platform.isWindows) {
      for (final codePage in const <int>[949, 51949]) {
        final decoded = _decodeWithWindowsCodePage(bytes, codePage);
        if (decoded != null && _looksDecoded(decoded)) {
          return GibDecodedContent(
            text: decoded,
            encoding: codePage == 949 ? 'cp949' : 'euc-kr',
          );
        }
      }
    }

    return GibDecodedContent(
      text: utf8.decode(bytes, allowMalformed: true),
      encoding: 'utf8-lossy',
    );
  }

  static List<GibNormalizedGame> parseNormalizedGamesFromBytes(
    List<int> bytes, {
    required String sourceId,
    required String sourceType,
    required String? sourceUrl,
    required String localPath,
    String? downloadUrl,
  }) {
    final decoded = decodeBytes(bytes, sourceLabel: localPath);
    return parseNormalizedGames(
      decoded.text,
      sourceId: sourceId,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
      localPath: localPath,
      encoding: decoded.encoding,
      downloadUrl: downloadUrl,
    );
  }

  static List<GibNormalizedGame> parseNormalizedGames(
    String gibContent, {
    required String sourceId,
    required String sourceType,
    required String? sourceUrl,
    required String localPath,
    required String encoding,
    String? downloadUrl,
  }) {
    final lines = const LineSplitter().convert(gibContent);
    final games = <GibNormalizedGame>[];
    Map<String, String>? currentMetadata;
    final currentMoves = <String>[];
    int gameIndex = 0;

    void flushCurrentGame() {
      if (currentMetadata == null || currentMoves.isEmpty) {
        currentMetadata = null;
        currentMoves.clear();
        return;
      }

      games.add(
        _createNormalizedGame(
          metadata: currentMetadata!,
          moves: List<String>.from(currentMoves),
          sourceId: sourceId,
          sourceType: sourceType,
          sourceUrl: sourceUrl,
          localPath: localPath,
          encoding: encoding,
          gameIndex: gameIndex,
          downloadUrl: downloadUrl,
        ),
      );
      gameIndex++;
      currentMetadata = null;
      currentMoves.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final metadataEntry = _parseMetadataLine(line);
      if (metadataEntry != null) {
        if (currentMetadata != null && currentMoves.isNotEmpty) {
          flushCurrentGame();
        }
        currentMetadata ??= <String, String>{};
        currentMetadata![metadataEntry.key] = metadataEntry.value;
        continue;
      }

      final extractedMoves = extractNumberedMoves(line);
      if (extractedMoves.isNotEmpty) {
        currentMoves.addAll(extractedMoves);
      }
    }

    flushCurrentGame();
    return games;
  }

  static GibNormalizedGame parsePlainTextMoveList(
    String content, {
    required String sourceId,
    required String sourceType,
    required String localPath,
    required String title,
    required String encoding,
    String? sourceUrl,
  }) {
    final moves = <String>[];
    final rawMetadata = <String, String>{};

    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final metadataEntry = _parseMetadataLine(line);
      if (metadataEntry != null) {
        rawMetadata[metadataEntry.key] = metadataEntry.value;
      }
      moves.addAll(extractNumberedMoves(line));
    }

    final blueSetup =
        parsePieceSetup(_findCanonicalMetadataValue(rawMetadata, 'setupBlue'));
    final redSetup =
        parsePieceSetup(_findCanonicalMetadataValue(rawMetadata, 'setupRed'));

    return GibNormalizedGame(
      sourceId: sourceId,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
      downloadUrl: null,
      localPath: localPath,
      gameId: '$sourceId#1',
      gameIndex: 0,
      title: title,
      round: _findCanonicalMetadataValue(rawMetadata, 'round'),
      date: _findCanonicalMetadataValue(rawMetadata, 'date'),
      players: {
        'blue': _findCanonicalMetadataValue(rawMetadata, 'bluePlayer'),
        'red': _findCanonicalMetadataValue(rawMetadata, 'redPlayer'),
      },
      result: _findCanonicalMetadataValue(rawMetadata, 'result'),
      setupBlue:
          blueSetup == null ? null : pieceSetupToCanonicalString(blueSetup),
      setupRed: redSetup == null ? null : pieceSetupToCanonicalString(redSetup),
      moves: moves,
      moveCount: moves.length,
      initialFen: createInitialFen(blueSetup: blueSetup, redSetup: redSetup),
      rawMetadata: rawMetadata,
      encoding: encoding,
    );
  }

  static List<String> extractNumberedMoves(String line) {
    return _numberedMovePattern
        .allMatches(line)
        .map((match) => match.group(1)?.trim() ?? '')
        .where((move) => move.isNotEmpty)
        .toList(growable: false);
  }

  static bool looksLikeGib(String content) {
    return content.contains('[') &&
        _metadataPattern.hasMatch(content) &&
        _numberedMovePattern.hasMatch(content);
  }

  static bool looksLikePlainTextMoveList(String content) {
    return !looksLikeGib(content) && _numberedMovePattern.hasMatch(content);
  }

  static PieceSetup? parsePieceSetup(String? rawValue) {
    if (rawValue == null) return null;
    final normalized = rawValue
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9가-힣]+'), '')
        .toLowerCase();

    switch (normalized) {
      case '상마마상':
      case 'elephanthorsehorseelephant':
        return PieceSetup.elephantHorseHorseElephant;
      case '상마상마':
      case 'elephanthorseelephanthorse':
        return PieceSetup.elephantHorseElephantHorse;
      case '마상상마':
      case 'horseelephantelephanthorse':
        return PieceSetup.horseElephantElephantHorse;
      case '마상마상':
      case 'horseelephanthorseelephant':
        return PieceSetup.horseElephantHorseElephant;
      default:
        return null;
    }
  }

  static String pieceSetupToCanonicalString(PieceSetup setup) {
    switch (setup) {
      case PieceSetup.elephantHorseHorseElephant:
        return 'elephantHorseHorseElephant';
      case PieceSetup.elephantHorseElephantHorse:
        return 'elephantHorseElephantHorse';
      case PieceSetup.horseElephantElephantHorse:
        return 'horseElephantElephantHorse';
      case PieceSetup.horseElephantHorseElephant:
        return 'horseElephantHorseElephant';
    }
  }

  static String createInitialFen({
    PieceSetup? blueSetup,
    PieceSetup? redSetup,
  }) {
    final board = Board();
    board.setupInitialPosition(
      blueSetup: blueSetup ?? PieceSetup.horseElephantHorseElephant,
      redSetup: redSetup ?? PieceSetup.horseElephantHorseElephant,
    );
    return boardToFen(board, PieceColor.blue);
  }

  static Board? fenToBoard(String fen) {
    try {
      final parts = fen.split(' ');
      if (parts.isEmpty) return null;

      final board = Board();
      board.clear();
      final rows = parts.first.split('/');
      if (rows.length != 10) return null;

      for (int rank = 0; rank < 10; rank++) {
        int file = 0;
        for (int i = 0; i < rows[rank].length; i++) {
          final char = rows[rank][i];
          final digit = int.tryParse(char);
          if (digit != null) {
            file += digit;
            continue;
          }
          final piece = _charToPiece(char);
          if (piece != null && file < 9) {
            board.setPiece(Position(file: file, rank: 9 - rank), piece);
          }
          file++;
        }
      }
      return board;
    } catch (_) {
      return null;
    }
  }

  static String boardToFen(Board board, PieceColor currentPlayer) {
    final buffer = StringBuffer();
    for (int rank = 9; rank >= 0; rank--) {
      int emptyCount = 0;
      for (int file = 0; file < 9; file++) {
        final piece = board.getPiece(Position(file: file, rank: rank));
        if (piece == null) {
          emptyCount++;
          continue;
        }
        if (emptyCount > 0) {
          buffer.write(emptyCount);
          emptyCount = 0;
        }
        buffer.write(_pieceToChar(piece));
      }
      if (emptyCount > 0) {
        buffer.write(emptyCount);
      }
      if (rank > 0) {
        buffer.write('/');
      }
    }
    buffer.write(' ');
    buffer.write(currentPlayer == PieceColor.blue ? 'w' : 'b');
    buffer.write(' - - 0 1');
    return buffer.toString();
  }

  static Map<String, Position>? parseGibMove(String gibMove) {
    final coordMatch = _coordPattern.firstMatch(gibMove);
    if (coordMatch == null) return null;

    try {
      var gibFromRank = int.parse(coordMatch.group(1)!);
      final gibFromFile = int.parse(coordMatch.group(2)!);
      var gibToRank = int.parse(coordMatch.group(3)!);
      final gibToFile = int.parse(coordMatch.group(4)!);

      if (gibFromRank == 0) gibFromRank = 10;
      if (gibToRank == 0) gibToRank = 10;

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

      return {
        'from': Position(file: gibFromFile - 1, rank: 10 - gibFromRank),
        'to': Position(file: gibToFile - 1, rank: 10 - gibToRank),
      };
    } catch (_) {
      return null;
    }
  }

  static Board? replayMovesToPosition(
    List<String> gibMoves, {
    int? upToMove,
    PieceSetup blueSetup = PieceSetup.horseElephantHorseElephant,
    PieceSetup redSetup = PieceSetup.horseElephantHorseElephant,
    Board? initialBoard,
  }) {
    final board = initialBoard?.copy() ?? Board();
    if (initialBoard == null) {
      board.setupInitialPosition(blueSetup: blueSetup, redSetup: redSetup);
    }

    final moveCount = upToMove ?? gibMoves.length;
    for (final gibMove in gibMoves.take(moveCount)) {
      final positions = parseGibMove(gibMove);
      if (positions == null) continue;
      board.movePiece(positions['from']!, positions['to']!);
    }
    return board;
  }

  static GibNormalizedGame _createNormalizedGame({
    required Map<String, String> metadata,
    required List<String> moves,
    required String sourceId,
    required String sourceType,
    required String? sourceUrl,
    required String localPath,
    required String encoding,
    required int gameIndex,
    String? downloadUrl,
  }) {
    final title =
        _findCanonicalMetadataValue(metadata, 'title') ?? 'Untitled GIB Game';
    final round = _findCanonicalMetadataValue(metadata, 'round');
    final date = _findCanonicalMetadataValue(metadata, 'date');
    final bluePlayer = _findCanonicalMetadataValue(metadata, 'bluePlayer');
    final redPlayer = _findCanonicalMetadataValue(metadata, 'redPlayer');
    final result = _findCanonicalMetadataValue(metadata, 'result');
    final setupBlue =
        parsePieceSetup(_findCanonicalMetadataValue(metadata, 'setupBlue'));
    final setupRed =
        parsePieceSetup(_findCanonicalMetadataValue(metadata, 'setupRed'));
    final explicitFen = _findCanonicalMetadataValue(metadata, 'initialFen');
    final initialFen = explicitFen ??
        createInitialFen(blueSetup: setupBlue, redSetup: setupRed);

    return GibNormalizedGame(
      sourceId: sourceId,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
      downloadUrl: downloadUrl,
      localPath: localPath,
      gameId: '$sourceId#${gameIndex + 1}',
      gameIndex: gameIndex,
      title: title,
      round: round,
      date: date,
      players: {
        'blue': bluePlayer,
        'red': redPlayer,
      },
      result: result,
      setupBlue:
          setupBlue == null ? null : pieceSetupToCanonicalString(setupBlue),
      setupRed: setupRed == null ? null : pieceSetupToCanonicalString(setupRed),
      moves: moves,
      moveCount: moves.length,
      initialFen: initialFen,
      rawMetadata: Map<String, String>.from(metadata),
      encoding: encoding,
    );
  }

  static Map<String, dynamic> _legacyGameRecordFromNormalized(
    GibNormalizedGame game,
  ) {
    return {
      'metadata': game.rawMetadata,
      'moves': List<String>.from(game.moves),
      'fen': game.initialFen,
      'title': game.title,
      'description': '',
      'bluePlayer': game.players['blue'] ?? 'blue',
      'redPlayer': game.players['red'] ?? 'red',
      'result': game.result ?? '',
    };
  }

  static String? _findCanonicalMetadataValue(
    Map<String, String> metadata,
    String canonicalKey,
  ) {
    for (final entry in metadata.entries) {
      final alias = _metadataKeyAliases[_normalizeMetadataKey(entry.key)];
      if (alias == canonicalKey) {
        return entry.value.trim();
      }
    }

    final values = metadata.values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (values.isEmpty) return null;

    switch (canonicalKey) {
      case 'title':
        return values.isNotEmpty ? values[0] : null;
      case 'round':
        return values.length > 1 ? values[1] : null;
      case 'date':
        for (final value in values) {
          if (RegExp(r'^\d{4}[-./]\d{2}[-./]\d{2}$').hasMatch(value)) {
            return value.replaceAll('.', '-');
          }
        }
        return values.length > 2 ? values[2] : null;
      case 'bluePlayer':
        return values.length > 4 ? values[4] : null;
      case 'redPlayer':
        return values.length > 5 ? values[5] : null;
      case 'setupBlue':
        return values.length > 6 ? values[6] : null;
      case 'setupRed':
        return values.length > 7 ? values[7] : null;
      case 'result':
        return values.isNotEmpty ? values.last : null;
      default:
        return null;
    }
  }

  static String _normalizeMetadataKey(String key) {
    return key.trim().toLowerCase().replaceAll(RegExp(r'[\s_:\-]'), '');
  }

  static MapEntry<String, String>? _parseMetadataLine(String line) {
    final strictMatch = _metadataPattern.firstMatch(line);
    if (strictMatch != null) {
      return MapEntry(
        strictMatch.group(1)!.trim(),
        strictMatch.group(2)!.trim(),
      );
    }

    if (!line.startsWith('[') || !line.contains('"')) {
      return null;
    }

    final firstQuote = line.indexOf('"');
    if (firstQuote <= 1) {
      return null;
    }

    final key = line.substring(1, firstQuote).trim();
    var value = line.substring(firstQuote + 1).trim();
    if (value.endsWith('"]')) {
      value = value.substring(0, value.length - 2);
    } else if (value.endsWith(']')) {
      value = value.substring(0, value.length - 1);
    } else if (value.endsWith('"')) {
      value = value.substring(0, value.length - 1);
    }

    if (key.isEmpty || value.isEmpty) {
      return null;
    }
    return MapEntry(key, value.trim());
  }

  static String? _tryDecodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return null;
    }
  }

  static bool _looksDecoded(String value) {
    if (value.trim().isEmpty) return false;
    if (value.contains('\uFFFD') || value.contains('\u0000')) return false;
    if (looksLikeGib(value) || looksLikePlainTextMoveList(value)) return true;
    return value.contains('[') && value.contains('"');
  }

  static String? _decodeWithWindowsCodePage(List<int> bytes, int codePage) {
    final tempDir = Directory.systemTemp.createTempSync('janggi_gib_decode_');
    final tempFile = File('${tempDir.path}${Platform.pathSeparator}input.bin');
    tempFile.writeAsBytesSync(bytes, flush: true);

    final escapedPath = tempFile.path.replaceAll("'", "''");
    final script = [
      r'$OutputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false)',
      '[System.Text.Encoding]::GetEncoding($codePage).GetString('
          "[System.IO.File]::ReadAllBytes('$escapedPath'))",
    ].join('; ');

    try {
      final result = Process.runSync(
        'powershell',
        <String>['-NoProfile', '-Command', script],
        runInShell: false,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) {
        return null;
      }
      return (result.stdout as String).replaceAll('\r\n', '\n').trimRight();
    } catch (_) {
      return null;
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  }

  static Piece? _charToPiece(String char) {
    final isBlue = char == char.toUpperCase();
    final color = isBlue ? PieceColor.blue : PieceColor.red;
    final lower = char.toLowerCase();

    final type = switch (lower) {
      'k' => PieceType.general,
      'a' => PieceType.guard,
      'n' => PieceType.horse,
      'b' => PieceType.elephant,
      'r' => PieceType.chariot,
      'c' => PieceType.cannon,
      'p' => PieceType.soldier,
      _ => null,
    };
    if (type == null) return null;
    return Piece(type: type, color: color);
  }

  static String _pieceToChar(Piece piece) {
    final base = switch (piece.type) {
      PieceType.general => 'k',
      PieceType.guard => 'a',
      PieceType.horse => 'n',
      PieceType.elephant => 'b',
      PieceType.chariot => 'r',
      PieceType.cannon => 'c',
      PieceType.soldier => 'p',
    };
    return piece.color == PieceColor.blue ? base.toUpperCase() : base;
  }
}
