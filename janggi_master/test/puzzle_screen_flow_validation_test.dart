import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/game/game_state.dart';
import 'package:janggi_master/models/move.dart';
import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/position.dart';
import 'package:janggi_master/models/puzzle_objective.dart';
import 'package:janggi_master/models/rule_mode.dart';
import 'package:janggi_master/screens/game_screen.dart' show GameMode;
import 'package:janggi_master/screens/puzzle_game_screen.dart'
    show PuzzleTerminalStatus, evaluatePuzzleTerminalStatus;

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

List<Map<String, dynamic>> _loadBundledCatalog() {
  final raw = File('assets/puzzles/puzzles.json').readAsStringSync(
    encoding: utf8,
  );
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(decoded['puzzles'] as List)
      .map((puzzle) => <String, dynamic>{
            ...puzzle,
            'dataset': 'bundled',
          })
      .toList(growable: false);
}

List<Map<String, dynamic>> _loadPublishedGenerated() {
  final file = File('dev/published_generated_puzzles_current.json');
  if (!file.existsSync()) return const <Map<String, dynamic>>[];
  final decoded = jsonDecode(file.readAsStringSync(encoding: utf8)) as List;
  return decoded.whereType<Map>().map((row) {
    final puzzle = Map<String, dynamic>.from(row);
    final mateIn = (puzzle['mate_in'] as num?)?.toInt() ??
        (puzzle['mateIn'] as num?)?.toInt() ??
        0;
    return <String, dynamic>{
      'id': puzzle['id'],
      'title': puzzle['title'],
      'fen': puzzle['fen'],
      'solution': List<String>.from(puzzle['solution'] as List),
      'mateIn': mateIn,
      'difficulty': mateIn,
      'toMove': puzzle['to_move'] ?? puzzle['toMove'],
      'source': puzzle['source'] ?? 'generated_selfplay_feed',
      'feedType': 'generated',
      'dataset': 'published_generated',
    };
  }).toList(growable: false);
}

class _PuzzleFlow {
  _PuzzleFlow(this.puzzle, this.ruleMode)
      : state = GameState(
          gameMode: GameMode.twoPlayer,
          ruleMode: ruleMode,
        ) {
    final normalized = PuzzleObjective.normalizePuzzleMap(puzzle);
    solution = List<String>.from(normalized['solution'] as List);
    targetPlayerMoves = PuzzleObjective.playerMoveCount(normalized);
    playerColor =
        normalized['toMove'] == 'red' ? PieceColor.red : PieceColor.blue;
    state.setPositionFromFen(normalized['fen'] as String, playerColor);
  }

  final Map<String, dynamic> puzzle;
  final RuleMode ruleMode;
  final GameState state;
  late final List<String> solution;
  late final int targetPlayerMoves;
  late final PieceColor playerColor;

  var solutionIndex = 0;
  var lastValidatedMoveCount = 0;
  var isFollowingSolutionLine = true;

  int get playerSolvedMoveCount => (state.moveHistory.length + 1) ~/ 2;

  String get label => '${puzzle['dataset']}:${ruleMode.name}:${puzzle['id']}';

  void recomputeProgressFromHistory() {
    final history = state.moveHistory;
    var matchedMoves = 0;

    while (matchedMoves < solution.length && matchedMoves < history.length) {
      final expectedMove = _parseMove(solution[matchedMoves]);
      final actualMove = history[matchedMoves];
      if (expectedMove != actualMove) break;
      matchedMoves++;
    }

    solutionIndex = matchedMoves;
    isFollowingSolutionLine = matchedMoves == history.length;
    lastValidatedMoveCount = history.length;
  }

  Move? expectedSolutionMoveForCurrentTurn() {
    if (!isFollowingSolutionLine || solutionIndex >= solution.length) {
      return null;
    }
    final move = _parseMove(solution[solutionIndex]);
    final piece = state.board.getPiece(move.from);
    if (piece == null || piece.color != state.currentPlayer) {
      return null;
    }
    return move;
  }

  Future<String?> playExpectedMove(String actor) async {
    final move = expectedSolutionMoveForCurrentTurn();
    if (move == null) {
      return '$actor:no-expected-move@index$solutionIndex';
    }
    if (!state.canPlayMove(move, requiredColor: state.currentPlayer)) {
      return '$actor:not-playable@index$solutionIndex:${move.toUCI()}';
    }

    await state.onSquareTapped(move.from);
    if (!state.validMoves.contains(move.to)) {
      return '$actor:selected-but-destination-not-highlighted@index$solutionIndex:${move.toUCI()}';
    }
    await state.onSquareTapped(move.to);
    recomputeProgressFromHistory();
    return null;
  }

  PuzzleTerminalStatus terminalStatus() {
    return evaluatePuzzleTerminalStatus(
      gameState: state,
      playerColor: playerColor,
      playerSolvedMoveCount: playerSolvedMoveCount,
      playerTotalMoveCount: targetPlayerMoves,
    );
  }

  String? terminalFailure(String actor) {
    final status = terminalStatus();
    switch (status) {
      case PuzzleTerminalStatus.solved:
        return solutionIndex >= solution.length
            ? null
            : '$actor:early-solved@index$solutionIndex';
      case PuzzleTerminalStatus.failed:
        return '$actor:screen-terminal-failure@index$solutionIndex:${state.gameOverReason ?? 'no-escape'}';
      case PuzzleTerminalStatus.none:
        return null;
    }
  }

  Future<String?> run() async {
    recomputeProgressFromHistory();
    while (solutionIndex < solution.length) {
      if (state.currentPlayer != playerColor) {
        final failure = await playExpectedMove('auto');
        if (failure != null) return failure;
        final terminal = terminalFailure('auto');
        if (terminal != null) return terminal;
        continue;
      }

      final hintMove = expectedSolutionMoveForCurrentTurn();
      if (hintMove == null) {
        return 'hint:no-solution-hint@index$solutionIndex';
      }
      final failure = await playExpectedMove('player-hint');
      if (failure != null) return failure;
      final terminal = terminalFailure('player-hint');
      if (terminal != null) return terminal;
      if (state.currentPlayer != playerColor &&
          playerSolvedMoveCount >= targetPlayerMoves &&
          solutionIndex < solution.length) {
        return 'no-player-moves-left-before-solution-end@index$solutionIndex';
      }
    }

    final terminal = terminalStatus();
    if (terminal != PuzzleTerminalStatus.solved) {
      return 'not-solved-after-solution:$terminal:${state.gameOverReason ?? 'ongoing'}';
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugPrint = (String? message, {int? wrapWidth}) {};

  test('generated puzzle #88 completes through the screen terminal logic',
      () async {
    final puzzle = _loadPublishedGenerated().singleWhere(
      (row) => row['id'] == 'gp_-125673c40ecb5aca',
    );
    final flow = _PuzzleFlow(puzzle, RuleMode.casualDefault);

    final failure = await flow.run();
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    flow.state.dispose();

    expect(failure, isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('new bundled mate-3 additions follow hint and auto flow', () async {
    const newIds = <String>{'m3_27', 'm3_28', 'm3_29', 'm3_30', 'm3_31'};
    final puzzles = _loadBundledCatalog()
        .where((puzzle) => newIds.contains(puzzle['id']))
        .toList(growable: false);
    expect(puzzles.length, newIds.length);

    final failures = <String>[];
    final successes = <String>[];
    final flows = <_PuzzleFlow>[];

    for (final ruleMode in RuleMode.values) {
      for (final puzzle in puzzles) {
        final flow = _PuzzleFlow(puzzle, ruleMode);
        flows.add(flow);
        final failure = await flow.run();
        if (failure != null) {
          failures.add('${flow.label}:$failure');
        } else {
          successes.add(flow.label);
        }
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    for (final flow in flows) {
      flow.state.dispose();
    }

    File('dev/new_bundled_mate3_flow_report.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
          'ids': newIds.toList(),
          'successes': successes,
          'failures': failures,
        }),
        encoding: utf8,
      );

    expect(failures, isEmpty, reason: failures.join(', '));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('all app puzzle sources follow the PuzzleGameScreen hint and auto flow',
      () async {
    final puzzles = <Map<String, dynamic>>[
      ..._loadBundledCatalog(),
      ..._loadPublishedGenerated(),
    ];
    final failures = <String>[];
    final flows = <_PuzzleFlow>[];

    for (final ruleMode in RuleMode.values) {
      for (final puzzle in puzzles) {
        final flow = _PuzzleFlow(puzzle, ruleMode);
        flows.add(flow);
        final failure = await flow.run();
        if (failure != null) {
          failures.add('${flow.label}:$failure');
        }
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    for (final flow in flows) {
      flow.state.dispose();
    }

    File('dev/puzzle_screen_flow_report.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
          'total': puzzles.length,
          'failures': failures,
        }),
        encoding: utf8,
      );

    expect(failures, isEmpty, reason: failures.join(', '));
  }, timeout: const Timeout(Duration(minutes: 12)));
}
