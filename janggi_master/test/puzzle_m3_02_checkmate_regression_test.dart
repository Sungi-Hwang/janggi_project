import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/game/game_state.dart';
import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/position.dart';
import 'package:janggi_master/screens/game_screen.dart' show GameMode;

Position _uci(String square) {
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square.substring(1)) - 1;
  return Position(file: file, rank: rank);
}

Future<void> _move(GameState state, String from, String to) async {
  await state.onSquareTapped(_uci(from));
  await state.onSquareTapped(_uci(to));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('m3_02 should not end early after the center capture', () async {
    const fen = '4ck3/4aa3/9/9/1p5p1/3R5/3P1r3/9/4C4/3K5 b - - 0 1';

    final state = GameState(gameMode: GameMode.twoPlayer);
    state.setPositionFromFen(fen, PieceColor.red);

    await _move(state, 'f4', 'f1');
    await _move(state, 'd1', 'd2');
    await _move(state, 'f1', 'e2');

    expect(
      state.isGameOver,
      isFalse,
      reason: 'm3_02 is a mate-in-3 line and must continue after f1e2.',
    );

    await state.onSquareTapped(_uci('d2'));
    expect(
      state.validMoves,
      containsAll(<Position>[_uci('d1'), _uci('d3')]),
      reason:
          'After f1e2, the defending king must still be able to escape to d1 or d3.',
    );
  });
}
