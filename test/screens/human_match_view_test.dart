import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/human_match_controller.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/screens/human_match_view.dart';
import 'package:goodlock_app/screens/keep_screen.dart';
import 'package:goodlock_app/screens/placement_screen.dart';
import 'package:goodlock_app/screens/selection_screen.dart';

import '../helpers/builders.dart';
import '../helpers/fake_link.dart';

List<Json> fixture(String name) =>
    (jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as List).cast<Json>();

void main() {
  late FakeLink link;
  late HumanMatchController controller;
  var left = false;

  Future<void> open(WidgetTester tester) async {
    // A common 20:9 phone in landscape: 2400×1080 px at 2.625 dpr ≈ 914×411 dp.
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    left = false;
    link = FakeLink();
    controller = HumanMatchController(link, me: 0);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HumanMatchView(controller: controller, speed: 8, haptics: false, onLeave: () => left = true),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> playUntilDone(WidgetTester tester) async {
    var frames = 0;
    while (controller.isResolving && frames < 6000) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    expect(controller.isResolving, isFalse, reason: 'the round did not finish playing');
  }

  testWidgets('shows the screen of each phase as the server moves on', (tester) async {
    await open(tester);
    expect(find.text('En attente du serveur…'), findsOneWidget);

    link.server(selectionState());
    await tester.pump();
    expect(find.byType(SelectionScreen), findsOneWidget);

    link.server(stateOf(Phase.placement, mine: [for (var i = 0; i < 4; i++) character('m$i', side: 0, slot: i)]));
    await tester.pump();
    expect(find.byType(PlacementScreen), findsOneWidget);
    expect(find.byType(SelectionScreen), findsNothing);

    link.server(GameStateView.fromJson(fixture('round_start')[0]));
    await tester.pump();
    expect(find.byType(KeepScreen), findsOneWidget);
  });

  testWidgets('FLOW-4: plays the round the server resolved, then the Keep comes back', (tester) async {
    await open(tester);
    link.server(GameStateView.fromJson(fixture('round_start')[0]));
    await tester.pump();

    link.serverResolved(RoundResolved.fromJson(fixture('round_resolved')[0]));
    await tester.pump();
    expect(find.byType(KeepScreen), findsNothing); // the Resolve scene takes the screen

    await playUntilDone(tester);
    link.server(GameStateView.fromJson(fixture('round_start')[1]));
    await tester.pump();

    expect(find.byType(KeepScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FLOW-6: the result comes once the last round is played, and leaves the match', (tester) async {
    await open(tester);
    link.server(GameStateView.fromJson(fixture('round_start')[0]));
    link.serverResolved(RoundResolved.fromJson(fixture('round_resolved')[0]));
    link.serverOver(const GameOver(0, EndReason.elimination));
    await tester.pump();
    expect(find.text('Victoire'), findsNothing); // the round is still playing

    await playUntilDone(tester);
    await tester.pump();

    expect(find.text('Victoire'), findsOneWidget);
    await tester.tap(find.text('Retour'));
    expect(left, isTrue);
  });

  testWidgets('FLOW-6: a match that ends before any round (a concession) shows its result at once', (tester) async {
    await open(tester);
    link.server(selectionState());
    link.serverOver(const GameOver(1, EndReason.concede));
    await tester.pump();

    expect(find.text('Défaite'), findsOneWidget);
    expect(find.text('Tu as abandonné.'), findsOneWidget);
  });
}
