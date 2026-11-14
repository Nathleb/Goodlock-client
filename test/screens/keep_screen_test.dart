import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/human_match_controller.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/screens/keep_screen.dart';

import '../helpers/builders.dart';
import '../helpers/fake_link.dart';

void main() {
  late FakeLink link;
  late HumanMatchController controller;

  GameStateView keep({int round = 0, int rollsLeft = 2, bool ready = false, List<String> locked = const []}) => stateOf(
    Phase.keep,
    round: round,
    rollsLeft: rollsLeft,
    myReady: ready,
    mine: [for (var i = 0; i < 4; i++) character('m$i', side: 0, slot: i, locked: locked.contains('m$i'))],
    theirs: [for (var i = 0; i < 4; i++) character('t$i', side: 1, slot: i, locked: i == 0)],
  );

  Future<void> open(WidgetTester tester, GameStateView state) async {
    // A common 20:9 phone in landscape: 2400×1080 px at 2.625 dpr ≈ 914×411 dp.
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    link = FakeLink();
    controller = HumanMatchController(link, me: 0);
    addTearDown(controller.dispose);
    link.server(state);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: KeepScreen(controller: controller)),
      ),
    );
    await tester.pump();
  }

  Finder face(String id) => find.byKey(ValueKey('face-$id'));
  Finder lock(String id) => find.byKey(ValueKey('lock-$id'));

  testWidgets('LAYOUT-2: shows the round and the rerolls left, both teams and the Confirm button', (tester) async {
    await open(tester, keep(round: 2, rollsLeft: 1));

    expect(find.text('Round 3 · relances : 1'), findsOneWidget);
    expect(find.text('Name m0'), findsOneWidget);
    expect(find.text('Name t0'), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CELL-5: tapping my faces keeps and releases them, with a lock mark', (tester) async {
    await open(tester, keep());

    await tester.tap(face('m1'));
    await tester.pump();
    expect(lock('m1'), findsOneWidget);
    await tester.tap(face('m3'));
    await tester.pump();
    expect(lock('m3'), findsOneWidget);
    await tester.tap(face('m1'));
    await tester.pump();
    expect(lock('m1'), findsNothing);
  });

  testWidgets('KEEP-1: Confirm sends the kept dice', (tester) async {
    await open(tester, keep());
    await tester.tap(face('m2'));
    await tester.tap(face('m0'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('confirm')));

    expect(link.sent, ['confirmKeep m2,m0']);
  });

  testWidgets('FLOW-3: the second Keep starts with the dice kept in the first one', (tester) async {
    await open(tester, keep());
    await tester.tap(face('m0'));
    link.server(keep(rollsLeft: 1, locked: ['m0']));
    await tester.pump();

    expect(lock('m0'), findsOneWidget);
    expect(find.text('Round 1 · relances : 1'), findsOneWidget);
  });

  testWidgets('CELL-4: the opponent\'s faces cannot be tapped and never show a lock mark', (tester) async {
    await open(tester, keep());
    await tester.tap(face('t1'));
    await tester.pump();

    expect(controller.locks, isEmpty);
    expect(lock('t0'), findsNothing);
  });

  testWidgets('GAME-8: once confirmed the dice are frozen and the button reads Cancel', (tester) async {
    await open(tester, keep());
    await tester.tap(face('m0'));
    link.server(keep(ready: true, locked: ['m0']));
    await tester.pump();

    expect(find.text('Annuler'), findsOneWidget);
    await tester.tap(face('m1'));
    await tester.pump();
    expect(lock('m1'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cancel')));
    expect(link.sent.last, 'cancelKeep');
  });

  testWidgets('GAME-9: nothing says whether the opponent has confirmed', (tester) async {
    await open(tester, keep());
    expect(find.textContaining('prêt'), findsNothing);
    expect(find.textContaining('a confirmé'), findsNothing);
  });
}
