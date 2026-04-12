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

const String _normalizedPath = 'test_tmp/kja_verify/normalized/kja_pds.jsonl';

Map<String, dynamic> _loadGame(String gameId) {
  final file = File(_normalizedPath);
  final lines = file.readAsLinesSync();
  for (final line in lines) {
    if (line.trim().isEmpty) {
      continue;
    }
    final decoded = jsonDecode(line) as Map<String, dynamic>;
    if (decoded['gameId'] == gameId) {
      return decoded;
    }
  }
  throw StateError('Could not find $gameId in $_normalizedPath');
}

Future<GameState> _replayOfficialPrefix({
  required String initialFen,
  required List<String> rawMoves,
}) async {
  final state = GameState(
    gameMode: GameMode.twoPlayer,
    ruleMode: RuleMode.officialKja,
  );
  state.setPositionFromFen(initialFen, PieceColor.blue);

  for (final rawMove in rawMoves) {
    final positions = GibParser.parseGibMove(rawMove);
    expect(positions, isNotNull, reason: 'Could not parse move "$rawMove".');

    final from = positions!['from']!;
    final to = positions['to']!;
    await state.onSquareTapped(from);
    expect(
      state.validMoves.contains(to),
      isTrue,
      reason:
          'Expected "$rawMove" to be legal for ${state.currentPlayer.name}.',
    );
    await state.onSquareTapped(to);
    expect(
      state.isGameOver,
      isFalse,
      reason: 'The game should still be ongoing after replaying "$rawMove".',
    );
  }

  return state;
}

void _silenceDebugPrint() {
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {};
  addTearDown(() {
    debugPrint = originalDebugPrint;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'official mode keeps exact engine tokens for the e8e10 regression',
    () async {
      _silenceDebugPrint();

      final game = _loadGame('kja_pds:64#1');
      final initialFen = game['initialFen'] as String;
      final rawMoves = List<String>.from(game['moves'] as List<dynamic>)
          .take(40)
          .toList(growable: false);

      final state = await _replayOfficialPrefix(
        initialFen: initialFen,
        rawMoves: rawMoves,
      );

      expect(state.moveHistory.last.toUCI(), 'e8e10');
      expect(
        StockfishFFI.getPositionState(
          rootFen: initialFen,
          moves: state.moveHistory.map((move) => move.toUCI()).toList(),
        ),
        isNotNull,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'official mode keeps exact engine tokens for the f8e9 regression',
    () async {
      _silenceDebugPrint();

      final game = _loadGame('kja_pds:73#1');
      final initialFen = game['initialFen'] as String;
      final rawMoves = List<String>.from(game['moves'] as List<dynamic>)
          .take(140)
          .toList(growable: false);

      final state = await _replayOfficialPrefix(
        initialFen: initialFen,
        rawMoves: rawMoves,
      );

      expect(state.moveHistory.last.toUCI(), 'f8e9');
      expect(
        StockfishFFI.getPositionState(
          rootFen: initialFen,
          moves: state.moveHistory.map((move) => move.toUCI()).toList(),
        ),
        isNotNull,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
