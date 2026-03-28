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

  test('m3_22 exact line remains a winning mate sequence', () async {
    const fen = '4k4/4a1P2/5a3/1pp3RB1/9/3r5/2b6/4A4/1b1cK4/9 b - - 0 1';

    final state = GameState(gameMode: GameMode.twoPlayer);
    state.setPositionFromFen(fen, PieceColor.red);

    await _move(state, 'd2', 'a2');
    await _move(state, 'e2', 'f3');
    await _move(state, 'd5', 'f5');
    await _move(state, 'h7', 'f4');
    await _move(state, 'f5', 'f4');

    expect(state.isGameOver, isTrue);
    expect(
      state.gameOverReason,
      anyOf('red_wins_capture', 'red_wins_checkmate'),
    );
  });

  test('m3_22 slower second move is still weaker than the catalog line', () async {
    const fen = '4k4/4a1P2/5a3/1pp3RB1/9/3r5/2b6/4A4/1b1cK4/9 b - - 0 1';

    final state = GameState(gameMode: GameMode.twoPlayer);
    state.setPositionFromFen(fen, PieceColor.red);

    await _move(state, 'd2', 'a2');
    await _move(state, 'e2', 'f3');
    await _move(state, 'd5', 'h5');

    expect(state.isGameOver, isFalse);
    expect(state.currentPlayer, PieceColor.blue);
  });
}
