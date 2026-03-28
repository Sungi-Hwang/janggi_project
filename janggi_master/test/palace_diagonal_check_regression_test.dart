import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/game/game_state.dart';
import 'package:janggi_master/models/board.dart';
import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/position.dart';
import 'package:janggi_master/screens/game_screen.dart' show GameMode;

Position _pos(int file, int rank) => Position(file: file, rank: rank);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('red chariot gives check diagonally inside blue palace', () {
    final board = Board()
      ..setPiece(
        _pos(4, 1),
        const Piece(type: PieceType.general, color: PieceColor.blue),
      )
      ..setPiece(
        _pos(5, 2),
        const Piece(type: PieceType.chariot, color: PieceColor.red),
      )
      ..setPiece(
        _pos(3, 8),
        const Piece(type: PieceType.general, color: PieceColor.red),
      );

    final state = GameState(gameMode: GameMode.twoPlayer);
    state.applyCustomStartPosition(
      customBoard: board,
      startingPlayer: PieceColor.blue,
    );

    expect(
      state.isInCheck,
      isTrue,
      reason:
          'A chariot on a palace corner must give check to the opposing general on the palace center.',
    );
    expect(state.showCheckNotification, isTrue);
  });

  test('blue chariot gives check diagonally inside red palace', () {
    final board = Board()
      ..setPiece(
        _pos(4, 8),
        const Piece(type: PieceType.general, color: PieceColor.red),
      )
      ..setPiece(
        _pos(5, 7),
        const Piece(type: PieceType.chariot, color: PieceColor.blue),
      )
      ..setPiece(
        _pos(3, 1),
        const Piece(type: PieceType.general, color: PieceColor.blue),
      );

    final state = GameState(gameMode: GameMode.twoPlayer);
    state.applyCustomStartPosition(
      customBoard: board,
      startingPlayer: PieceColor.red,
    );

    expect(
      state.isInCheck,
      isTrue,
      reason:
          'A chariot on a palace corner must also give check inside the opponent palace, regardless of piece color.',
    );
    expect(state.showCheckNotification, isTrue);
  });
}
