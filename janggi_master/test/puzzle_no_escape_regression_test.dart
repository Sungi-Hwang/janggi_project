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

Position? _parseSquare(String square) {
  final match = RegExp(
    r'^([a-i])(10|[1-9])$',
    caseSensitive: false,
  ).firstMatch(square.trim());
  if (match == null) {
    return null;
  }

  final file = match.group(1)!.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(match.group(2)!) - 1;
  return Position(file: file, rank: rank);
}

Move _parseMove(String raw) {
  final match = RegExp(
    r'^([a-i])(10|[1-9])([a-i])(10|[1-9])$',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (match == null) {
    throw ArgumentError('Could not parse move: $raw');
  }

  final from = _parseSquare('${match.group(1)}${match.group(2)}');
  final to = _parseSquare('${match.group(3)}${match.group(4)}');
  if (from == null || to == null) {
    throw ArgumentError('Could not parse move: $raw');
  }

  return Move(from: from, to: to);
}

Map<String, dynamic> _loadPuzzle(String id) {
  final raw = File('assets/puzzles/puzzles.json').readAsStringSync(
    encoding: utf8,
  );
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final puzzles = List<Map<String, dynamic>>.from(
    decoded['puzzles'] as List<dynamic>,
  );
  return puzzles.firstWhere((puzzle) => puzzle['id'] == id);
}

Future<GameState> _replaySolution(
  String id, {
  required RuleMode ruleMode,
}) async {
  final puzzle = _loadPuzzle(id);
  final state = GameState(
    gameMode: GameMode.twoPlayer,
    ruleMode: ruleMode,
  );
  final toMove = puzzle['toMove'] == 'red' ? PieceColor.red : PieceColor.blue;

  state.setPositionFromFen(puzzle['fen'] as String, toMove);

  for (final rawMove
      in List<String>.from(puzzle['solution'] as List<dynamic>)) {
    final move = _parseMove(rawMove);
    await state.onSquareTapped(move.from);
    expect(
      state.validMoves.contains(move.to),
      isTrue,
      reason: 'Stored move $rawMove should stay legal for puzzle $id',
    );
    await state.onSquareTapped(move.to);
  }

  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugPrint = (String? message, {int? wrapWidth}) {};

  group('Puzzle no-escape regressions', () {
    test('representative catalog puzzles leave no legal reply in casual mode',
        () async {
      final states = <GameState>[];
      for (final id in const ['m1_01', 'm2_01', 'm3_22']) {
        final state = await _replaySolution(
          id,
          ruleMode: RuleMode.casualDefault,
        );
        states.add(state);
        expect(
          state.currentPlayerHasNoEscape,
          isTrue,
          reason: 'Puzzle $id should leave the defender with no legal reply.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      for (final state in states) {
        state.dispose();
      }
    });

    test('representative catalog puzzles leave no legal reply in official mode',
        () async {
      final states = <GameState>[];
      for (final id in const ['m1_01', 'm2_01', 'm3_22']) {
        final state = await _replaySolution(
          id,
          ruleMode: RuleMode.officialKja,
        );
        states.add(state);
        expect(
          state.currentPlayerHasNoEscape,
          isTrue,
          reason: 'Puzzle $id should leave the defender with no legal reply.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      for (final state in states) {
        state.dispose();
      }
    });
  });
}
