import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/human_match_controller.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/screens/human_match_view.dart';
import 'package:goodlock_app/screens/match_screen.dart';
import 'package:goodlock_app/screens/placement_screen.dart';
import 'package:goodlock_app/screens/selection_screen.dart';

import '../helpers/builders.dart';
import '../helpers/fake_link.dart';

List<Json> fixture(String name) =>
    (jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as List).cast<Json>();

const step = Duration(milliseconds: 10);

void main() {
  late FakeLink link;
  late HumanMatchController controller;
  var left = false;

  Future<void> open(WidgetTester tester, {Duration endDwell = Duration.zero}) async {
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
          body: HumanMatchView(
            controller: controller,
            stepDelay: step,
            endDwell: endDwell,
            onLeave: () => left = true,
          ),
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

  Finder key(String k) => find.byKey(ValueKey(k));
  String caption(WidgetTester tester) => tester.widget<Text>(key('step-caption')).data!;
  MatchScreen matchScreen(WidgetTester tester) => tester.widget<MatchScreen>(find.byType(MatchScreen));

  GameStateView keep({int rollsLeft = 2, bool ready = false, List<String> locked = const []}) => stateOf(
    Phase.keep,
    rollsLeft: rollsLeft,
    myReady: ready,
    mine: [for (var i = 0; i < 4; i++) character('m$i', side: 0, slot: i, locked: locked.contains('m$i'))],
    theirs: [for (var i = 0; i < 4; i++) character('t$i', side: 1, slot: i)],
    preview: [for (final id in ['m0', 't0', 'm1']) ResolveStep(id, false, const [], const [])],
  );

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
    expect(find.byType(MatchScreen), findsOneWidget);
    expect(matchScreen(tester).resolving, isFalse);

    link.server(stateOf(Phase.roll, mine: [for (var i = 0; i < 4; i++) character('m$i', side: 0, slot: i)]));
    await tester.pump();
    expect(find.text('En attente du serveur…'), findsOneWidget);
  });

  group('FLOW-3: the Keep', () {
    testWidgets('UX-1, LAYOUT-1: the match screen shows the preview of the round, without playing it', (tester) async {
      await open(tester);
      link.server(keep());
      await tester.pump();

      expect(find.byType(MatchScreen), findsOneWidget);
      expect(key('token-t0'), findsOneWidget);
      expect(key('clock-me'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(caption(tester), 'Début du round.');
    });

    testWidgets('CELL-5, KEEP-1: tapping my faces keeps them, wherever the playhead stands, and Confirm sends them', (
      tester,
    ) async {
      await open(tester);
      link.server(keep());
      await tester.pump();

      await tester.tap(key('token-t0'));
      await tester.pump();
      expect(caption(tester), startsWith('2. Name t0'));
      await tester.tap(key('face-m2'));
      await tester.pump();
      expect(key('lock-m2'), findsOneWidget);
      expect(caption(tester), startsWith('2. Name t0'), reason: 'keeping a die does not move the playhead');

      await tester.tap(key('confirm'));
      expect(link.sent, ['confirmKeep m2']);
    });

    testWidgets('GAME-8: once confirmed the dice are frozen and the button reads Cancel', (tester) async {
      await open(tester);
      link.server(keep());
      await tester.pump();
      await tester.tap(key('token-m1'));
      await tester.tap(key('face-m0'));
      link.server(keep(ready: true, locked: ['m0']));
      await tester.pump();

      expect(caption(tester), startsWith('3. Name m1'), reason: 'the echo of Confirm does not move the playhead');
      await tester.tap(key('face-m1'));
      await tester.pump();
      expect(key('lock-m1'), findsNothing);
      await tester.tap(key('cancel'));
      expect(link.sent.last, 'cancelKeep');
    });

    testWidgets('TL-6, FLOW-3: after a Roll the playhead goes back to the beginning, the kept dice still kept', (
      tester,
    ) async {
      await open(tester);
      link.server(keep());
      await tester.pump();
      await tester.tap(key('face-m0'));
      await tester.tap(key('token-m1'));
      await tester.pump();

      link.server(keep(rollsLeft: 1, locked: ['m0']));
      await tester.pump();
      expect(caption(tester), 'Début du round.');
      expect(key('lock-m0'), findsOneWidget);
      expect(find.text('Round 1 · relances : 1'), findsOneWidget);
    });
  });

  group('FLOW-4..6: Resolve', () {
    Future<void> resolve(WidgetTester tester, {bool over = false}) async {
      link.server(GameStateView.fromJson(fixture('round_start')[0]));
      link.serverResolved(RoundResolved.fromJson(fixture('round_resolved')[0]));
      // The next round's Keep comes right after the resolved round.
      if (!over) link.server(GameStateView.fromJson(fixture('round_start')[1]));
      if (over) link.serverOver(const GameOver(0, EndReason.elimination));
      await tester.pump();
    }

    testWidgets('FLOW-4: plays the round the server resolved, then the Keep comes back', (tester) async {
      await open(tester);
      await resolve(tester);

      expect(matchScreen(tester).resolving, isTrue);
      expect(find.text('Round 1 · Résolution'), findsOneWidget);
      expect(key('confirm'), findsNothing);
      expect(key('clock-me'), findsOneWidget);

      await playUntilDone(tester);
      await tester.pump();

      expect(matchScreen(tester).resolving, isFalse);
      expect(find.text('Round 2 · relances : 2'), findsOneWidget);
      expect(caption(tester), 'Début du round.');
      expect(tester.takeException(), isNull);
    });

    testWidgets('FLOW-4, FLOW-5: the playback starts by itself and stops on the last notch, which stays a moment', (
      tester,
    ) async {
      await open(tester, endDwell: const Duration(seconds: 1));
      await resolve(tester);
      expect(caption(tester), 'Début du round.');

      await tester.pump(step);
      await tester.pump(step);
      expect(caption(tester), startsWith('2. '));

      await tester.pump(step * 20);
      expect(caption(tester), 'Fin du round.');
      expect(controller.isResolving, isTrue, reason: 'the end of the round stays on screen a moment');

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(controller.isResolving, isFalse);
    });

    testWidgets('FLOW-4: a pause holds the round; fast forward ends it', (tester) async {
      await open(tester);
      await resolve(tester);
      await tester.pump(step);
      await tester.tap(key('timeline-play')); // pause
      await tester.pump(const Duration(seconds: 5));
      expect(controller.isResolving, isTrue);
      expect(caption(tester), startsWith('1. '));

      await tester.tap(key('timeline-fast-forward'));
      await tester.pump(step); // the end dwell, none here
      await tester.pump();
      expect(controller.isResolving, isFalse);
    });

    testWidgets('FLOW-6: the result comes once the last round is played, and leaves the match', (tester) async {
      await open(tester);
      await resolve(tester, over: true);
      expect(find.text('Victoire'), findsNothing); // the round is still playing

      await playUntilDone(tester);
      await tester.pump();

      expect(find.text('Victoire'), findsOneWidget);
      await tester.tap(find.text('Retour'));
      expect(left, isTrue);
    });

    testWidgets('FLOW-6: the playback stops on the effect that ends the match, which stays under the result', (
      tester,
    ) async {
      await open(tester);
      await resolve(tester, over: true);
      await playUntilDone(tester);
      await tester.pump();

      expect(find.text('Victoire'), findsOneWidget);
      expect(caption(tester), startsWith('8. Garran'));
    });

    testWidgets('FLOW-6: a game over that comes once the round is playing still stops on its last effect', (
      tester,
    ) async {
      await open(tester);
      link.server(GameStateView.fromJson(fixture('round_start')[0]));
      link.serverResolved(RoundResolved.fromJson(fixture('round_resolved')[0]));
      await tester.pump();
      await tester.pump(step);
      link.serverOver(const GameOver(1, EndReason.elimination));
      await playUntilDone(tester);
      await tester.pump();

      expect(find.text('Défaite'), findsOneWidget);
      expect(caption(tester), startsWith('8. Garran'));
    });
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
