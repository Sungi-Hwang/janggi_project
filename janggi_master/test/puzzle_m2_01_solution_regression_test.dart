import 'dart:convert';
import 'dart:io';

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
  if (match == null) {
    return null;
  }

  final file = match.group(1)!.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(match.group(2)!) - 1;
  return Position(file: file, rank: rank);
}

Move? _parseMove(String raw) {
  final match = RegExp(
    r'^([a-i])(10|[1-9])([a-i])(10|[1-9])$',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (match == null) {
    return null;
  }

  final from = _parseSquare('${match.group(1)}${match.group(2)}');
  final to = _parseSquare('${match.group(3)}${match.group(4)}');
  if (from == null || to == null) {
    return null;
  }

  return Move(from: from, to: to);
}

Future<void> _applyMove(GameState state, String rawMove) async {
  final move = _parseMove(rawMove);
  expect(move, isNotNull, reason: 'Could not parse move $rawMove');
  await state.onSquareTapped(move!.from);
  expect(
    state.validMoves.contains(move.to),
    isTrue,
    reason: 'Move $rawMove should be legal for ${state.currentPlayer.name}',
  );
  await state.onSquareTapped(move.to);
}

Map<String, dynamic> _loadPuzzle(String id) {
  final raw = File('assets/puzzles/puzzles.json').readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final puzzles = List<Map<String, dynamic>>.from(
    decoded['puzzles'] as List<dynamic>,
  );
  return puzzles.firstWhere((puzzle) => puzzle['id'] == id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('m2_01 exact line should finish as mate', () async {
    final puzzle = _loadPuzzle('m2_01');
    final state = GameState(gameMode: GameMode.twoPlayer);
    final toMove =
        puzzle['toMove'] == 'red' ? PieceColor.red : PieceColor.blue;

    state.setPositionFromFen(puzzle['fen'] as String, toMove);

    await _applyMove(state, 'g3f3');
    await _applyMove(state, 'f2f3');
    await _applyMove(state, 'f4f7');

    expect(
      state.isGameOver,
      isTrue,
      reason: 'The catalog line for m2_01 should end the puzzle immediately.',
    );
    expect(state.gameOverReason, 'red_wins_checkmate');
  });
}
