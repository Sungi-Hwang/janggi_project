import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/game/game_state.dart';
import 'package:janggi_master/models/board.dart';
import 'package:janggi_master/models/piece.dart';
import 'package:janggi_master/models/position.dart';
import 'package:janggi_master/models/rule_mode.dart';
import 'package:janggi_master/screens/game_screen.dart' show GameMode;

Board _minimalPalaceBoard() {
  final board = Board();
  board.setPiece(
    const Position(file: 4, rank: 1),
    const Piece(type: PieceType.general, color: PieceColor.blue),
  );
  board.setPiece(
    const Position(file: 3, rank: 0),
    const Piece(type: PieceType.guard, color: PieceColor.blue),
  );
  board.setPiece(
    const Position(file: 5, rank: 0),
    const Piece(type: PieceType.guard, color: PieceColor.blue),
  );
  board.setPiece(
    const Position(file: 4, rank: 8),
    const Piece(type: PieceType.general, color: PieceColor.red),
  );
  board.setPiece(
    const Position(file: 4, rank: 3),
    const Piece(type: PieceType.soldier, color: PieceColor.blue),
  );
  board.setPiece(
    const Position(file: 3, rank: 9),
    const Piece(type: PieceType.guard, color: PieceColor.red),
  );
  board.setPiece(
    const Position(file: 5, rank: 9),
    const Piece(type: PieceType.guard, color: PieceColor.red),
  );
  return board;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('game state keeps the selected casual rule mode', () {
    final state = GameState(
      gameMode: GameMode.twoPlayer,
      ruleMode: RuleMode.casualDefault,
    );

    expect(state.ruleMode, RuleMode.casualDefault);
  });

  test('game state keeps the selected official rule mode', () {
    final state = GameState(
      gameMode: GameMode.twoPlayer,
      ruleMode: RuleMode.officialKja,
    );

    expect(state.ruleMode, RuleMode.officialKja);
  });

  test('rule modes map to distinct engine variants', () {
    expect(RuleMode.casualDefault.engineVariantName, 'janggimodern');
    expect(RuleMode.officialKja.engineVariantName, 'janggi');
  });

  test('official mode custom starts use engine legal moves directly', () async {
    final state = GameState(
      gameMode: GameMode.twoPlayer,
      ruleMode: RuleMode.officialKja,
    );
    state.applyCustomStartPosition(
      customBoard: _minimalPalaceBoard(),
      startingPlayer: PieceColor.blue,
    );

    await state.onSquareTapped(const Position(file: 3, rank: 0));

    expect(state.validMoves, contains(const Position(file: 3, rank: 1)));
  });

  test('official mode puzzle starts use engine legal moves directly', () async {
    final state = GameState(
      gameMode: GameMode.twoPlayer,
      ruleMode: RuleMode.officialKja,
    );
    state.setPuzzlePosition(_minimalPalaceBoard(), PieceColor.blue);

    await state.onSquareTapped(const Position(file: 3, rank: 0));

    expect(state.validMoves, contains(const Position(file: 3, rank: 1)));
  });
}
