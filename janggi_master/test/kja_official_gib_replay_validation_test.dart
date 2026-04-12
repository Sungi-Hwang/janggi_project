import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/game/game_state.dart';
import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/rule_mode.dart';
import 'package:janggi_master/screens/game_screen.dart' show GameMode;
import 'package:janggi_master/stockfish_ffi.dart';
import 'package:janggi_master/utils/gib_parser.dart';

const String _kjaNormalizedPath =
    'test_tmp/kja_verify/normalized/kja_pds.jsonl';

Map<String, dynamic> _decodeJsonLine(String line) {
  return jsonDecode(line) as Map<String, dynamic>;
}

String _gameLabel(Map<String, dynamic> game) {
  final title = (game['title'] as String?)?.trim();
  final gameId = (game['gameId'] as String?)?.trim();
  return (title != null && title.isNotEmpty)
      ? '$title [$gameId]'
      : (gameId ?? 'unknown-game');
}

List<Map<String, dynamic>> _loadNormalizedGames(File file) {
  return file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(_decodeJsonLine)
      .toList(growable: false);
}

String _recentRawMoves(List<String> rawMoves, int ply) {
  final start = ply - 2 < 0 ? 0 : ply - 2;
  final end = ply + 3 > rawMoves.length ? rawMoves.length : ply + 3;
  return rawMoves
      .sublist(start, end)
      .asMap()
      .entries
      .map((entry) => '${start + entry.key + 1}:${entry.value}')
      .join(' | ');
}

String _recentUciMoves(GameState state) {
  final moves = state.moveHistory.map((move) => move.toUCI()).toList();
  final start = moves.length - 5 < 0 ? 0 : moves.length - 5;
  return moves.sublist(start).join(' ');
}

List<Map<String, dynamic>> _selectRepresentativeGames(
  List<Map<String, dynamic>> games,
) {
  if (games.length <= 3) {
    return games;
  }

  return <Map<String, dynamic>>[
    games.first,
    games[games.length ~/ 2],
    games.last,
  ];
}

bool _shouldProbeEngine({
  required int ply,
  required int totalPlies,
}) {
  final moveNumber = ply + 1;
  return moveNumber == totalPlies || moveNumber % 20 == 0;
}

Future<String?> _replayOfficialGame(Map<String, dynamic> game) async {
  final initialFen = game['initialFen'] as String?;
  if (initialFen == null || initialFen.trim().isEmpty) {
    return '${_gameLabel(game)}: missing initial FEN';
  }

  final state = GameState(
    gameMode: GameMode.twoPlayer,
    ruleMode: RuleMode.officialKja,
  );
  state.setPositionFromFen(initialFen, PieceColor.blue);

  final rawMoves = List<String>.from(game['moves'] as List<dynamic>);

  for (int ply = 0; ply < rawMoves.length; ply++) {
    final rawMove = rawMoves[ply];
    final positions = GibParser.parseGibMove(rawMove);
    if (positions == null) {
      return '${_gameLabel(game)}: could not parse ply ${ply + 1} "$rawMove"';
    }

    if (state.isGameOver) {
      return '${_gameLabel(game)}: game ended early before ply ${ply + 1} '
          '(${state.gameOverReason ?? state.statusMessage})';
    }

    final from = positions['from']!;
    final to = positions['to']!;

    await state.onSquareTapped(from);
    if (!state.validMoves.contains(to)) {
      return '${_gameLabel(game)}: illegal ply ${ply + 1} "$rawMove" '
          'for ${state.currentPlayer.name}';
    }

    await state.onSquareTapped(to);

    if (_shouldProbeEngine(ply: ply, totalPlies: rawMoves.length)) {
      final engineState = StockfishFFI.getPositionState(
        rootFen: initialFen,
        moves: state.moveHistory.map((move) => move.toUCI()).toList(),
      );
      if (engineState == null) {
        return '${_gameLabel(game)}: engine rejected history after ply ${ply + 1} '
            '"$rawMove" (uci=${state.moveHistory.last.toUCI()}; '
            'recentRaw=${_recentRawMoves(rawMoves, ply)}; '
            'recentUci=${_recentUciMoves(state)})';
      }
    }
  }

  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final normalizedFile = File(_kjaNormalizedPath);
  final shouldRun = Platform.environment['RUN_KJA_VERIFY'] == '1' &&
      normalizedFile.existsSync();

  test(
    'replays imported KJA official GIB games without illegal moves or engine desync',
    () async {
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      final allGames = _loadNormalizedGames(normalizedFile);
      expect(allGames, isNotEmpty,
          reason: 'No imported KJA games found to replay.');
      final games = _selectRepresentativeGames(allGames);

      int totalPlies = 0;
      final failures = <String>[];

      for (final game in games) {
        totalPlies += (game['moveCount'] as num?)?.toInt() ?? 0;
        final failure = await _replayOfficialGame(game);
        if (failure != null) {
          failures.add(failure);
        }
      }

      expect(
        failures,
        isEmpty,
        reason:
            'Validated ${games.length} representative official games out of '
            '${allGames.length} imported official games / $totalPlies plies.\n'
            '${failures.join('\n')}',
      );
    },
    skip: !shouldRun,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
