import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/human_match_controller.dart';
import 'package:goodlock_app/screens/selection_screen.dart';

import '../helpers/builders.dart';
import '../helpers/fake_link.dart';

void main() {
  late FakeLink link;
  late HumanMatchController controller;

  Future<void> open(WidgetTester tester) async {
    // A common 20:9 phone in landscape: 2400×1080 px at 2.625 dpr ≈ 914×411 dp.
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    link = FakeLink();
    controller = HumanMatchController(link, me: 0);
    addTearDown(controller.dispose);
    link.server(selectionState());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SelectionScreen(controller: controller)),
      ),
    );
    await tester.pump();
  }

  Future<void> pick(WidgetTester tester, Iterable<String> ids) async {
    for (final id in ids) {
      await tester.tap(find.text('Char $id'));
      await tester.pump();
    }
  }

  testWidgets('CHAR-1: shows both decks, six characters each, with their stats, in landscape without overflow', (
    tester,
  ) async {
    await open(tester);

    for (var i = 0; i < 6; i++) {
      expect(find.text('Char a$i'), findsOneWidget);
      expect(find.text('Char b$i'), findsOneWidget);
    }
    expect(find.textContaining('PV 20'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SEL-2: counts the picks and enables Confirm at exactly four', (tester) async {
    await open(tester);
    expect(find.text('0/4 choisis'), findsOneWidget);

    await pick(tester, ['a0', 'a1', 'a2']);
    expect(find.text('3/4 choisis'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('confirm'))).onPressed, isNull);

    await pick(tester, ['a3']);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('confirm'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('confirm')));
    expect(link.sent, ['confirmSelection a0,a1,a2,a3']);
  });

  testWidgets('SEL-2: a fifth character is not kept, and a kept one is released by a second tap', (tester) async {
    await open(tester);
    await pick(tester, ['a0', 'a1', 'a2', 'a3', 'a4']);
    expect(controller.picks, ['a0', 'a1', 'a2', 'a3']);
    await pick(tester, ['a0']);
    expect(controller.picks, ['a1', 'a2', 'a3']);
  });

  testWidgets('CHAR-1: the opponent\'s deck is read only', (tester) async {
    await open(tester);
    await pick(tester, ['b0', 'b1']);
    expect(controller.picks, isEmpty);
  });

  testWidgets('GAME-8: once confirmed the button reads Cancel and the cards no longer react', (tester) async {
    await open(tester);
    await pick(tester, ['a0', 'a1', 'a2', 'a3']);
    link.server(selectionState(ready: true, myPicks: ['a0', 'a1', 'a2', 'a3']));
    await tester.pump();

    expect(find.text('Annuler'), findsOneWidget);
    await pick(tester, ['a4']);
    expect(controller.picks, ['a0', 'a1', 'a2', 'a3']);

    await tester.tap(find.byKey(const ValueKey('cancel')));
    expect(link.sent.last, 'cancelSelection');
  });

  testWidgets('GAME-9: nothing says whether the opponent has confirmed', (tester) async {
    await open(tester);
    expect(find.textContaining('prêt'), findsNothing);
    expect(find.textContaining('a confirmé'), findsNothing);
    expect(find.textContaining('En attente de l'), findsNothing);
  });
}
