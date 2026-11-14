import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/human_match_controller.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/screens/placement_screen.dart';

import '../helpers/builders.dart';
import '../helpers/fake_link.dart';

void main() {
  late FakeLink link;
  late HumanMatchController controller;

  List<CharacterView> team() => [for (var i = 0; i < 4; i++) character('m$i', side: 0, slot: i)];

  Future<void> open(WidgetTester tester, {bool ready = false}) async {
    // A common 20:9 phone in landscape: 2400×1080 px at 2.625 dpr ≈ 914×411 dp.
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    link = FakeLink();
    controller = HumanMatchController(link, me: 0);
    addTearDown(controller.dispose);
    link.server(stateOf(Phase.placement, myReady: ready, mine: team()));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlacementScreen(controller: controller)),
      ),
    );
    await tester.pump();
  }

  Finder cell(int slot) => find.byKey(ValueKey('cell-$slot'));
  Finder nameIn(int slot, String name) => find.descendant(of: cell(slot), matching: find.text(name));

  testWidgets('PLACE-1: starts with the four characters on cells 0 to 3 and cell 4 empty, without overflow', (
    tester,
  ) async {
    await open(tester);

    for (var i = 0; i < 4; i++) {
      expect(nameIn(i, 'Name m$i'), findsOneWidget);
    }
    expect(find.descendant(of: cell(4), matching: find.text('vide')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PLACE-2: two taps move a character to the empty cell, and the layout is sent', (tester) async {
    await open(tester);

    await tester.tap(cell(1));
    await tester.pump();
    expect(controller.selectedSlot, 1);
    await tester.tap(cell(4));
    await tester.pump();

    expect(nameIn(4, 'Name m1'), findsOneWidget);
    expect(find.descendant(of: cell(1), matching: find.text('vide')), findsOneWidget);
    expect(link.sent, ['rearrangeTeam m0,-,m2,m3,m1']);
  });

  testWidgets('PLACE-2: a tap on an occupied cell swaps the two characters', (tester) async {
    await open(tester);

    await tester.tap(cell(0));
    await tester.pump();
    await tester.tap(cell(3));
    await tester.pump();

    expect(nameIn(0, 'Name m3'), findsOneWidget);
    expect(nameIn(3, 'Name m0'), findsOneWidget);
  });

  testWidgets('GAME-7: the opponent\'s side stays masked before the first round', (tester) async {
    await open(tester);
    expect(find.textContaining('masquée'), findsOneWidget);
    expect(find.textContaining('Name t'), findsNothing);
  });

  testWidgets('GAME-8: once confirmed the layout is frozen and the button reads Cancel', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('confirm')));
    expect(link.sent.last, 'confirmPlacement');
    link.server(stateOf(Phase.placement, myReady: true, mine: team()));
    await tester.pump();

    expect(find.text('Annuler'), findsOneWidget);
    await tester.tap(cell(1));
    await tester.tap(cell(4));
    await tester.pump();
    expect(link.sent.where((s) => s.startsWith('rearrangeTeam')), isEmpty);

    await tester.tap(find.byKey(const ValueKey('cancel')));
    expect(link.sent.last, 'cancelPlacement');
  });
}
