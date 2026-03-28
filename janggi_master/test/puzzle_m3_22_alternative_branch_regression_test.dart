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

  test('m3_22 alternative d5d1 is not a checking move after e2f3', () async {
    const fen = '4k4/4a1P2/5a3/1pp3RB1/9/3r5/2b6/4A4/1b1cK4/9 b - - 0 1';

    final state = GameState(gameMode: GameMode.twoPlayer);
    state.setPositionFromFen(fen, PieceColor.red);

    await _move(state, 'd2', 'a2');
    await _move(state, 'e2', 'f3');
    await _move(state, 'd5', 'd1');

    expect(
      state.isInCheck,
      isFalse,
      reason:
          'After e2f3, the defending king has already left the palace center, so d5d1 should not count as check.',
    );

    expect(state.currentPlayer, PieceColor.blue);

    await state.onSquareTapped(_uci('g7'));
    expect(
      state.validMoves,
      contains(_uci('g1')),
      reason:
          'The defending blue chariot must still be able to answer with g7g1 in this branch.',
    );
  });
}
