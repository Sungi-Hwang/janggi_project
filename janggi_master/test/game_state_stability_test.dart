import 'package:flutter_test/flutter_test.dart';

import 'package:janggi_master/game/game_state.dart';
import 'package:janggi_master/models/board.dart';
import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/position.dart';
import 'package:janggi_master/screens/game_screen.dart' show GameMode;

Future<void> _tapMove(
  GameState state,
  Position from,
  Position to,
) async {
  await state.onSquareTapped(from);
  await state.onSquareTapped(to);
}

Board _undoReproBoard() {
  final board = Board();
  board.clear();
  board.setPiece(
    const Position(file: 4, rank: 1),
    const Piece(type: PieceType.general, color: PieceColor.blue),
  );
  board.setPiece(
    const Position(file: 3, rank: 0),
    const Piece(type: PieceType.guard, color: PieceColor.blue),
  );
  board.setPiece(
    const Position(file: 4, rank: 8),
    const Piece(type: PieceType.general, color: PieceColor.red),
  );
  board.setPiece(
    const Position(file: 3, rank: 9),
    const Piece(type: PieceType.guard, color: PieceColor.red),
  );
  return board;
}

Board _customStartCheckBoard() {
  final board = Board();
  board.clear();
  board.setPiece(
    const Position(file: 4, rank: 1),
    const Piece(type: PieceType.general, color: PieceColor.blue),
  );
  board.setPiece(
    const Position(file: 4, rank: 8),
    const Piece(type: PieceType.general, color: PieceColor.red),
  );
  board.setPiece(
    const Position(file: 4, rank: 5),
    const Piece(type: PieceType.chariot, color: PieceColor.blue),
  );
  return board;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('undo should not trigger premature threefold repetition after replay',
      () async {
    final state = GameState(gameMode: GameMode.twoPlayer);
    state.setPuzzlePosition(_undoReproBoard(), PieceColor.blue);

    await _tapMove(
      state,
      const Position(file: 3, rank: 0),
      const Position(file: 3, rank: 1),
    );
    await _tapMove(
      state,
      const Position(file: 3, rank: 9),
      const Position(file: 3, rank: 8),
    );
    await _tapMove(
      state,
      const Position(file: 3, rank: 1),
      const Position(file: 3, rank: 0),
    );
    await _tapMove(
      state,
      const Position(file: 3, rank: 8),
      const Position(file: 3, rank: 9),
    );
    await _tapMove(
      state,
      const Position(file: 3, rank: 0),
      const Position(file: 3, rank: 1),
    );

    expect(state.isGameOver, isFalse);

    state.undoMove();

    await _tapMove(
      state,
      const Position(file: 3, rank: 0),
      const Position(file: 3, rank: 1),
    );

    expect(
      state.isGameOver,
      isFalse,
      reason:
          'Replaying the same move after undo should only recreate the second occurrence.',
    );
  });

  test('custom start in a normal game should detect initial check state', () {
    final state = GameState(gameMode: GameMode.twoPlayer);
    state.applyCustomStartPosition(
      customBoard: _customStartCheckBoard(),
      startingPlayer: PieceColor.red,
    );

    expect(
      state.statusMessage.toUpperCase(),
      contains('CHECK'),
      reason:
          'Normal game custom starts should not silently bypass initial check detection.',
    );
  });
}
