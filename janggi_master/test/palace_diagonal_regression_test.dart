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

  test('chariot can move diagonally inside opponent palace', () async {
    const fen = '4ck3/4aa3/9/9/1p5p1/3R5/3P1r3/9/4C4/3K5 b - - 0 1';

    final state = GameState(gameMode: GameMode.twoPlayer);
    state.setPositionFromFen(fen, PieceColor.red);

    await _move(state, 'f4', 'f1');
    await _move(state, 'd1', 'd2');

    expect(state.currentPlayer, PieceColor.red);

    final redChariot = _uci('f1');
    await state.onSquareTapped(redChariot);

    expect(
      state.validMoves,
      contains(_uci('e2')),
      reason:
          'A chariot in the opponent palace must still be able to move along the palace diagonal.',
    );
  });
}
