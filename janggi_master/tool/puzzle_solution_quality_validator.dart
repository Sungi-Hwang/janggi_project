import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/game/game_state.dart';
import 'package:janggi_master/models/move.dart';
import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/position.dart';
import 'package:janggi_master/screens/game_screen.dart' show GameMode;

Position? _parseSquare(String square) {
  final match = RegExp(
    r'^([a-i])(10|[1-9])$',
    caseSensitive: false,
  ).firstMatch(square.trim());
  if (match == null) return null;

  final file = match.group(1)!.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(match.group(2)!) - 1;
  return Position(file: file, rank: rank);
}

Move? _parseMove(String raw) {
  final match = RegExp(
    r'^([a-i])(10|[1-9])([a-i])(10|[1-9])$',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (match == null) return null;

  final from = _parseSquare('${match.group(1)}${match.group(2)}');
  final to = _parseSquare('${match.group(3)}${match.group(4)}');
  if (from == null || to == null) return null;
  return Move(from: from, to: to);
}

Future<void> _applyMove(GameState state, Move move) async {
  await state.onSquareTapped(move.from);
  await state.onSquareTapped(move.to);
}

Future<List<Move>> _allLegalMoves(GameState state) async {
  final moves = <Move>[];

  for (var rank = 0; rank < 10; rank++) {
    for (var file = 0; file < 9; file++) {
      final from = Position(file: file, rank: rank);
      final piece = state.board.getPiece(from);
      if (piece == null || piece.color != state.currentPlayer) {
        continue;
      }

      await state.onSquareTapped(from);
      final validMoves = List<Position>.from(state.validMoves);
      if (validMoves.isNotEmpty) {
        for (final to in validMoves) {
          moves.add(Move(from: from, to: to));
        }
      }
      await state.onSquareTapped(from); // Deselect.
    }
  }

  return moves;
}

Future<GameState> _buildStateFromPrefix({
  required String fen,
  required PieceColor toMove,
  required List<Move> prefixMoves,
}) async {
  final state = GameState(gameMode: GameMode.twoPlayer);
  state.setPositionFromFen(fen, toMove);
  for (final move in prefixMoves) {
    await _applyMove(state, move);
  }
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Keep output focused on the generated report.
  debugPrint = (String? message, {int? wrapWidth}) {};

  test(
    'scan puzzle solution quality against app completion rules',
    () async {
      final file = File('assets/puzzles/puzzles.json');
      expect(file.existsSync(), isTrue);

      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      var puzzles = List<Map<String, dynamic>>.from(
        decoded['puzzles'] as List<dynamic>,
      );
      final mateInFilter = int.tryParse(
        Platform.environment['PUZZLE_MATE_IN'] ?? '',
      );
      if (mateInFilter != null) {
        puzzles = puzzles
            .where((puzzle) => puzzle['mateIn'] == mateInFilter)
            .toList(growable: false);
      }

      final invalid = <Map<String, dynamic>>[];

      for (final puzzle in puzzles) {
        final fen = puzzle['fen'] as String;
        final toMove =
            (puzzle['toMove'] as String?) == 'red' ? PieceColor.red : PieceColor.blue;
        final solution = List<String>.from(puzzle['solution'] as List<dynamic>);
        final parsedSolution = <Move>[];
        var parseFailed = false;

        for (var i = 0; i < solution.length; i++) {
          final move = _parseMove(solution[i]);
          if (move == null) {
            invalid.add({
              'id': puzzle['id'],
              'title': puzzle['title'],
              'reason': 'parse',
              'ply': i + 1,
              'move': solution[i],
            });
            parseFailed = true;
            break;
          }
          parsedSolution.add(move);
        }
        if (parseFailed) {
          continue;
        }

        final state = GameState(gameMode: GameMode.twoPlayer);
        state.setPositionFromFen(fen, toMove);

        for (var i = 0; i < parsedSolution.length; i++) {
          final expectedMove = parsedSolution[i];
          final playerSideTurn = state.currentPlayer == toMove;

          await state.onSquareTapped(expectedMove.from);
          final expectedIsLegal = state.validMoves.contains(expectedMove.to);
          await state.onSquareTapped(expectedMove.from); // Deselect before branching.

          if (!expectedIsLegal) {
            invalid.add({
              'id': puzzle['id'],
              'title': puzzle['title'],
              'reason': 'illegal_expected',
              'ply': i + 1,
              'move': solution[i],
            });
            break;
          }

          if (playerSideTurn) {
            final legalMoves = await _allLegalMoves(state);
            for (final altMove in legalMoves) {
              final sameMove =
                  altMove.from == expectedMove.from && altMove.to == expectedMove.to;
              if (sameMove) {
                continue;
              }

              final altState = await _buildStateFromPrefix(
                fen: fen,
                toMove: toMove,
                prefixMoves: parsedSolution.take(i).toList(growable: false),
              );
              await _applyMove(altState, altMove);

              if (altState.isGameOver) {
                invalid.add({
                  'id': puzzle['id'],
                  'title': puzzle['title'],
                  'reason': 'alternative_immediate_win',
                  'ply': i + 1,
                  'move': solution[i],
                  'alternative': '${altMove.from.toAlgebraic()}${altMove.to.toAlgebraic()}',
                  'alternativeReason': altState.gameOverReason,
                });
                break;
              }
            }

            if (invalid.isNotEmpty && invalid.last['id'] == puzzle['id']) {
              break;
            }
          }

          await _applyMove(state, expectedMove);

          final isLastMove = i == parsedSolution.length - 1;
          if (!isLastMove && state.isGameOver) {
            invalid.add({
              'id': puzzle['id'],
              'title': puzzle['title'],
              'reason': 'line_ends_early',
              'ply': i + 1,
              'move': solution[i],
              'gameOverReason': state.gameOverReason,
            });
            break;
          }

          if (isLastMove && !state.isGameOver) {
            invalid.add({
              'id': puzzle['id'],
              'title': puzzle['title'],
              'reason': 'final_move_not_terminal',
              'ply': i + 1,
              'move': solution[i],
            });
            break;
          }
        }
      }

      final report = {
        'generatedAt': DateTime.now().toIso8601String(),
        'mateInFilter': mateInFilter,
        'count': invalid.length,
        'invalid': invalid,
      };

      final output = File('test_tmp/puzzle_solution_quality_report.json');
      await output.parent.create(recursive: true);
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );

      // ignore: avoid_print
      print('invalid_count=${invalid.length}');
      if (invalid.isNotEmpty) {
        // ignore: avoid_print
        print(const JsonEncoder.withIndent('  ')
            .convert(invalid.take(20).toList(growable: false)));
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
