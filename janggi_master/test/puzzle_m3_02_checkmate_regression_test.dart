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

  test('m3_02 becomes mate after the palace-center capture', () async {
    const fen = '4ck3/4aa3/9/9/1p5p1/3R5/3P1r3/9/4C4/3K5 b - - 0 1';

    final state = GameState(gameMode: GameMode.twoPlayer);
    state.setPositionFromFen(fen, PieceColor.red);

    await _move(state, 'f4', 'f1');
    await _move(state, 'd1', 'd2');
    await _move(state, 'f1', 'e2');

    expect(
      state.isGameOver,
      isTrue,
      reason:
          'With the red chariot on the palace center, both palace-corner escapes are still covered diagonally.',
    );
    expect(state.gameOverReason, 'red_wins_checkmate');
  });
}
