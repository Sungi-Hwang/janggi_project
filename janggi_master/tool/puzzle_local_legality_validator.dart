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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Keep the validation output focused on the final JSON report.
  debugPrint = (String? message, {int? wrapWidth}) {};

  test(
    'scan puzzle solution legality against app move rules',
    () async {
      final file = File('assets/puzzles/puzzles.json');
      expect(file.existsSync(), isTrue);

      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final puzzles = List<Map<String, dynamic>>.from(
        decoded['puzzles'] as List<dynamic>,
      );

      final invalid = <Map<String, dynamic>>[];

      for (final puzzle in puzzles) {
        final state = GameState(gameMode: GameMode.twoPlayer);
        final fen = puzzle['fen'] as String;
        final toMove =
            (puzzle['toMove'] as String?) == 'red' ? PieceColor.red : PieceColor.blue;
        state.setPositionFromFen(fen, toMove);

        final solution = List<String>.from(puzzle['solution'] as List<dynamic>);

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
            break;
          }

          await state.onSquareTapped(move.from);
          final isLegal = state.validMoves.contains(move.to);
          if (!isLegal) {
            invalid.add({
              'id': puzzle['id'],
              'title': puzzle['title'],
              'reason': 'illegal',
              'ply': i + 1,
              'move': solution[i],
              'currentPlayer': state.currentPlayer.name,
              'from': move.from.toAlgebraic(),
              'to': move.to.toAlgebraic(),
              'valid': state.validMoves.map((p) => p.toAlgebraic()).toList(),
            });
            break;
          }

          await state.onSquareTapped(move.to);
        }
      }

      final report = {
        'generatedAt': DateTime.now().toIso8601String(),
        'count': invalid.length,
        'invalid': invalid,
      };

      final output = File('dev/test_tmp/puzzle_local_legality_report.json');
      await output.parent.create(recursive: true);
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );

      // ignore: avoid_print
      print('invalid_count=${invalid.length}');
      if (invalid.isNotEmpty) {
        // ignore: avoid_print
        print(const JsonEncoder.withIndent('  ').convert(invalid.take(20).toList()));
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
