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

List<Map<String, dynamic>> _loadPublishedPuzzles() {
  final file = File('dev/published_generated_puzzles_current.json');
  if (!file.existsSync()) return const <Map<String, dynamic>>[];
  final decoded = jsonDecode(file.readAsStringSync(encoding: utf8));
  return List<Map<String, dynamic>>.from(decoded as List);
}

GameState _newState(Map<String, dynamic> puzzle, RuleMode ruleMode) {
  final state = GameState(
    gameMode: GameMode.twoPlayer,
    ruleMode: ruleMode,
  );
  final toMove = puzzle['to_move'] == 'red' ? PieceColor.red : PieceColor.blue;
  state.setPositionFromFen(puzzle['fen'] as String, toMove);
  return state;
}

Future<void> _playMove(GameState state, String rawMove) async {
  final move = _parseMove(rawMove);
  await state.onSquareTapped(move.from);
  if (!state.validMoves.contains(move.to)) {
    throw StateError('Illegal move $rawMove');
  }
  await state.onSquareTapped(move.to);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugPrint = (String? message, {int? wrapWidth}) {};

  test('published generated mate-3 puzzles have no immediate general capture',
      () async {
    final puzzles = _loadPublishedPuzzles();
    if (puzzles.isEmpty) {
      return;
    }

    final bad = <String, List<String>>{};
    final states = <GameState>[];
    for (final ruleMode in RuleMode.values) {
      for (final puzzle in puzzles) {
        final state = _newState(puzzle, ruleMode);
        states.add(state);
        final player =
            puzzle['to_move'] == 'red' ? PieceColor.red : PieceColor.blue;
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

    File('dev/published_generated_immediate_capture_report.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
          'bad': bad,
        }),
        encoding: utf8,
      );

    expect(
      bad,
      isEmpty,
      reason: 'immediate general captures: ${jsonEncode(bad)}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('published generated mate-3 puzzles do not solve after the first move',
      () async {
    final puzzles = _loadPublishedPuzzles();
    if (puzzles.isEmpty) {
      return;
    }

    final earlySolved = <String>[];
    final illegalFirstMoves = <String>[];
    final states = <GameState>[];
    for (final ruleMode in RuleMode.values) {
      for (final puzzle in puzzles) {
        final solution = List<String>.from(puzzle['solution'] as List);
        expect(solution.length, 5, reason: '${puzzle['id']} solution length');

        final state = _newState(puzzle, ruleMode);
        states.add(state);
        try {
          await _playMove(state, solution.first);
        } catch (_) {
          illegalFirstMoves.add(
            '${ruleMode.name}:${puzzle['id']}:${solution.first}',
          );
          continue;
        }
        if (state.currentPlayerHasNoEscape || state.isGameOver) {
          earlySolved.add('${ruleMode.name}:${puzzle['id']}');
        }
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    for (final state in states) {
      state.dispose();
    }

    final report = <String, dynamic>{
      'illegalFirstMoves': illegalFirstMoves,
      'earlySolved': earlySolved,
    };
    File('dev/published_generated_mate_depth_report.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(report),
        encoding: utf8,
      );

    expect(
      illegalFirstMoves,
      isEmpty,
      reason: 'illegal first moves: ${illegalFirstMoves.join(', ')}',
    );
    expect(
      earlySolved,
      isEmpty,
      reason: 'early solved: ${earlySolved.join(', ')}',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('published generated mate-3 puzzles complete within the stored line',
      () async {
    final puzzles = _loadPublishedPuzzles();
    if (puzzles.isEmpty) {
      return;
    }

    final bad = <String>[];
    final states = <GameState>[];
    for (final ruleMode in RuleMode.values) {
      for (final puzzle in puzzles) {
        final solution = List<String>.from(puzzle['solution'] as List);
        final state = _newState(puzzle, ruleMode);
        states.add(state);
        try {
          for (var i = 0; i < solution.length; i++) {
            await _playMove(state, solution[i]);
            final isTerminal =
                state.currentPlayerHasNoEscape || state.isGameOver;
            if (isTerminal && i < solution.length - 1) {
              bad.add('${ruleMode.name}:${puzzle['id']}:early@${i + 1}');
              break;
            }
          }
          final isTerminal = state.currentPlayerHasNoEscape || state.isGameOver;
          if (!isTerminal) {
            bad.add('${ruleMode.name}:${puzzle['id']}:not-terminal');
          }
        } catch (error) {
          bad.add('${ruleMode.name}:${puzzle['id']}:$error');
        }
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    for (final state in states) {
      state.dispose();
    }

    File('dev/published_generated_full_line_report.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
          'bad': bad,
        }),
        encoding: utf8,
      );

    expect(bad, isEmpty, reason: bad.join(', '));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
