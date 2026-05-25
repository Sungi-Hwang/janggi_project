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

List<Map<String, dynamic>> _loadCatalogPuzzles() {
  final raw = File('assets/puzzles/puzzles.json').readAsStringSync(
    encoding: utf8,
  );
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(decoded['puzzles'] as List);
}

GameState _newState(Map<String, dynamic> puzzle, RuleMode ruleMode) {
  final state = GameState(
    gameMode: GameMode.twoPlayer,
    ruleMode: ruleMode,
  );
  final toMove = puzzle['toMove'] == 'red' ? PieceColor.red : PieceColor.blue;
  state.setPositionFromFen(puzzle['fen'] as String, toMove);
  return state;
}

PieceColor _opponent(PieceColor color) =>
    color == PieceColor.blue ? PieceColor.red : PieceColor.blue;

List<String> _immediateGeneralCaptures(GameState state, PieceColor player) {
  final opponentGeneral = state.board.findPiece(
    PieceType.general,
    _opponent(player),
  );
  if (opponentGeneral == null) return const <String>[];

  final captures = <String>[];
  for (final from in state.board.findAllPieces(player)) {
    final move = Move(from: from, to: opponentGeneral);
    if (state.canPlayMove(move, requiredColor: player)) {
      captures.add(move.toUCI());
    }
  }
  captures.sort();
  return captures;
}

Future<String?> _validatePuzzleLine(
  Map<String, dynamic> puzzle,
  RuleMode ruleMode,
  List<GameState> states,
) async {
  final solution = List<String>.from(puzzle['solution'] as List);
  final state = _newState(puzzle, ruleMode);
  states.add(state);
  for (var index = 0; index < solution.length; index++) {
    final rawMove = solution[index];
    final move = _parseMove(rawMove);
    if (!state.canPlayMove(move, requiredColor: state.currentPlayer)) {
      return 'illegal@$index:$rawMove';
    }
    await state.onSquareTapped(move.from);
    await state.onSquareTapped(move.to);

    final terminal = state.currentPlayerHasNoEscape || state.isGameOver;
    if (terminal && index < solution.length - 1) {
      return 'early-terminal@${index + 1}:$rawMove';
    }
  }

  final terminal = state.currentPlayerHasNoEscape || state.isGameOver;
  if (!terminal) {
    return 'not-terminal';
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugPrint = (String? message, {int? wrapWidth}) {};

  test('bundled multi-move puzzles never start with direct general capture',
      () async {
    final puzzles = _loadCatalogPuzzles();
    final bad = <String, List<String>>{};
    final states = <GameState>[];

    for (final ruleMode in RuleMode.values) {
      for (final puzzle in puzzles.where((item) => item['mateIn'] != 1)) {
        final state = _newState(puzzle, ruleMode);
        states.add(state);
        final player =
            puzzle['toMove'] == 'red' ? PieceColor.red : PieceColor.blue;
        final captures = _immediateGeneralCaptures(state, player);
        if (captures.isNotEmpty) {
          bad['${ruleMode.name}:${puzzle['id']}'] = captures;
        }
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    for (final state in states) {
      state.dispose();
    }

    expect(
      bad,
      isEmpty,
      reason: 'immediate general captures: ${jsonEncode(bad)}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('all bundled catalog puzzles replay cleanly in app rules', () async {
    final puzzles = _loadCatalogPuzzles();
    final failures = <String>[];
    final states = <GameState>[];

    for (final ruleMode in RuleMode.values) {
      for (final puzzle in puzzles) {
        final failure = await _validatePuzzleLine(puzzle, ruleMode, states);
        if (failure != null) {
          failures.add('${ruleMode.name}:${puzzle['id']}:$failure');
        }
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    for (final state in states) {
      state.dispose();
    }

    File('dev/puzzle_catalog_full_line_report.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
          'total': puzzles.length,
          'failures': failures,
        }),
        encoding: utf8,
      );

    expect(failures, isEmpty, reason: failures.join(', '));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
