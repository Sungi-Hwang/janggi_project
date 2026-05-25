import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/game/game_state.dart';
import 'package:janggi_master/models/move.dart';
import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/position.dart';
import 'package:janggi_master/models/rule_mode.dart';
import 'package:janggi_master/screens/game_screen.dart' show GameMode;

Position _parseSquare(String square) {
  final match = RegExp(
    r'^([a-i])(10|[1-9])$',
    caseSensitive: false,
  ).firstMatch(square.trim());
  if (match == null) {
    throw ArgumentError('Could not parse square: $square');
  }
  return Position(
    file: match.group(1)!.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0),
    rank: int.parse(match.group(2)!) - 1,
  );
}

Move _parseMove(String raw) {
  final match = RegExp(
    r'^([a-i])(10|[1-9])([a-i])(10|[1-9])$',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (match == null) {
    throw ArgumentError('Could not parse move: $raw');
  }
  return Move(
    from: _parseSquare('${match.group(1)}${match.group(2)}'),
    to: _parseSquare('${match.group(3)}${match.group(4)}'),
  );
}

List<Map<String, dynamic>> _loadGeneratedStrictPuzzles() {
  final file = File('dev/tail_strict_combined.json');
  if (!file.existsSync()) return const <Map<String, dynamic>>[];
  final decoded = jsonDecode(file.readAsStringSync(encoding: utf8)) as Map;
  return List<Map<String, dynamic>>.from(decoded['puzzles'] as List);
}

Future<GameState> _replay(Map<String, dynamic> puzzle) async {
  final state = GameState(
    gameMode: GameMode.twoPlayer,
    ruleMode: RuleMode.officialKja,
  );
  final toMove = puzzle['toMove'] == 'red' ? PieceColor.red : PieceColor.blue;
  state.setPositionFromFen(puzzle['fen'] as String, toMove);

  for (final rawMove in List<String>.from(puzzle['solution'] as List)) {
    final move = _parseMove(rawMove);
    await state.onSquareTapped(move.from);
    expect(
      state.validMoves.contains(move.to),
      isTrue,
      reason: 'Generated puzzle ${puzzle['id']} has illegal move $rawMove',
    );
    await state.onSquareTapped(move.to);
  }

  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugPrint = (String? message, {int? wrapWidth}) {};

  test('generated strict tail puzzles replay to a terminal mate position',
      () async {
    final puzzles = _loadGeneratedStrictPuzzles();
    if (puzzles.isEmpty) {
      return;
    }

    final sample = puzzles.take(5).toList(growable: false);
    final states = <GameState>[];
    for (final puzzle in sample) {
      expect(puzzle['mateIn'], 3);
      expect((puzzle['solution'] as List).length, 5);
      final state = await _replay(puzzle);
      states.add(state);
      expect(
        state.currentPlayerHasNoEscape || state.isGameOver,
        isTrue,
        reason: 'Generated puzzle ${puzzle['id']} did not finish.',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    for (final state in states) {
      state.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
