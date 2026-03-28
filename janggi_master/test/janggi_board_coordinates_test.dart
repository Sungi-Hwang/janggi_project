import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/models/board.dart';
import 'package:janggi_master/widgets/janggi_board_widget.dart';

void main() {
  testWidgets('board shows lettered files and numeric ranks', (tester) async {
    final board = Board()..setupInitialPosition();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              height: 520,
              child: JanggiBoardWidget(
                board: board,
                showCoordinates: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('A'), findsWidgets);
    expect(find.text('I'), findsWidgets);
    expect(find.text('10'), findsWidgets);
    expect(find.text('1'), findsWidgets);
  });
}
