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

  test('m3_22 alternative d5d1 is still check after e2f3', () async {
    const fen = '4k4/4a1P2/5a3/1pp3RB1/9/3r5/2b6/4A4/1b1cK4/9 b - - 0 1';

    final state = GameState(gameMode: GameMode.twoPlayer);
    state.setPositionFromFen(fen, PieceColor.red);

    await _move(state, 'd2', 'a2');
    await _move(state, 'e2', 'f3');
    await _move(state, 'd5', 'd1');

    expect(
      state.isInCheck,
      isTrue,
      reason:
          'After e2f3, the blue general is still on the opposite palace corner, so the diagonal d1-e2-f3 remains a checking line while the center is empty.',
    );

    expect(state.currentPlayer, PieceColor.blue);

    await state.onSquareTapped(_uci('g7'));
    expect(
      state.validMoves,
      isNot(contains(_uci('g1'))),
      reason:
          'Because the diagonal d1-e2-f3 check is still active, blue cannot ignore it with g7g1.',
    );
  });
}
