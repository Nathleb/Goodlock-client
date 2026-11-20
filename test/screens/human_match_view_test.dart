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
import '../helpers/rounds.dart';

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

  /// The id of my first character in the recorded match.
  final myFirst = (fixture('round_start')[1]['players'] as List).cast<Json>()[0]['team'][0]['id'] as String;

  /// The Keep of round 2 of the recorded match, my first die kept.
  GameStateView nextKeep() {
    final json = fixture('round_start')[1];
    ((json['players'] as List).cast<Json>()[0]['team'] as List).cast<Json>()[0]['isFaceLocked'] = true;
    return GameStateView.fromJson(json);
  }

  /// Round 1 of the recorded match, with nothing after it.
  Future<void> resolve0(WidgetTester tester) async {
    link.server(GameStateView.fromJson(fixture('round_start')[0]));
    link.serverResolved(RoundResolved.fromJson(fixture('round_resolved')[0]));
    await tester.pump();
  }

  GameStateView keep({int rollsLeft = 2, bool ready = false, List<String> locked = const []}) => stateOf(
    Phase.keep,
    rollsLeft: rollsLeft,
    myReady: ready,
    mine: [for (var i = 0; i < 4; i++) character('m$i', side: 0, slot: i, locked: locked.contains('m$i'))],
    theirs: [for (var i = 0; i < 4; i++) character('t$i', side: 1, slot: i)],
    preview: [for (final id in ['m0', 't0', 'm1']) ResolveStep(id, false, const [], const [], unplayed: false)],
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

    testWidgets('FLOW-6, END-2: the playback stops on the effect that ends the match, which stays under the result', (
      tester,
    ) async {
      await open(tester);
      link.serverResolved(lateRound());
      link.serverOver(const GameOver(0, EndReason.elimination));
      await tester.pump();
      await playUntilDone(tester);
      await tester.pump();

      expect(find.text('Victoire'), findsOneWidget);
      expect(caption(tester), startsWith('3. Name m2'));
      expect(matchScreen(tester).playhead.notch, 3);
    });

    testWidgets('FLOW-6: a game over that comes once the round is playing still stops on its last effect', (
      tester,
    ) async {
      await open(tester);
      link.serverResolved(lateRound());
      await tester.pump();
      await tester.pump(step);
      link.serverOver(const GameOver(1, EndReason.elimination));
      await playUntilDone(tester);
      await tester.pump();

      expect(find.text('Défaite'), findsOneWidget);
      expect(caption(tester), startsWith('3. Name m2'));
    });

    testWidgets('FLOW-6, END-1: the playback stops on the last action played, the unplayed ones after it', (
      tester,
    ) async {
      await open(tester);
      link.serverResolved(lateRound(unplayed: true));
      await tester.pump();
      await tester.pump(step * 20);
      await tester.pump();
      expect(matchScreen(tester).playhead.notch, 3, reason: 'the round stays on screen until the game over comes');

      link.serverOver(const GameOver(0, EndReason.elimination));
      await playUntilDone(tester);
      await tester.pump();
      expect(find.text('Victoire'), findsOneWidget);
      expect(caption(tester), startsWith('3. Name m2'));
    });

    for (final reason in [EndReason.concede, EndReason.clock, EndReason.reconnection]) {
      testWidgets('FLOW-6: a loss by ${reason.name} during the replay does not stop it: the round plays to its end, '
          'then the result shows', (tester) async {
        await open(tester);
        await resolve(tester);
        await tester.pump(step);
        link.serverOver(GameOver(1, reason));
        await tester.pump();
        expect(find.text('Défaite'), findsNothing);

        await playUntilDone(tester);
        await tester.pump();
        expect(find.text('Défaite'), findsOneWidget);
        expect(caption(tester), 'Fin du round.');
      });
    }

    testWidgets('STATE-7: an elimination at the next Upkeep (a poison death) does not stop the last round early', (
      tester,
    ) async {
      await open(tester);
      link.serverResolved(lateRound(kills: false));
      link.serverOver(const GameOver(0, EndReason.elimination));
      await tester.pump();
      await playUntilDone(tester);
      await tester.pump();

      expect(find.text('Victoire'), findsOneWidget);
      expect(caption(tester), 'Fin du round.');
    });

    testWidgets('LAYOUT-2: during Resolve the bar shows who held the initiative in the round played, not in the next', (
      tester,
    ) async {
      await open(tester);
      await resolve(tester); // round 1, initiative 0 (me); the Keep of round 2 (initiative 1) is already there
      expect(find.byTooltip('Initiative : toi'), findsOneWidget);
      await playUntilDone(tester);
      await tester.pump();
      expect(find.byTooltip('Initiative : adversaire'), findsOneWidget);

      link.serverResolved(RoundResolved.fromJson(fixture('round_resolved')[1])); // round 2, initiative 1
      link.server(GameStateView.fromJson(fixture('round_start')[2])); // round 3, initiative 0
      await tester.pump();
      expect(find.text('Round 2 · Résolution'), findsOneWidget);
      expect(find.byTooltip('Initiative : adversaire'), findsOneWidget);
      await playUntilDone(tester);
    });
  });

  group('KEEP-3: skipping the replay to reach the next Keep', () {
    /// Round 1 of the recorded match, with the Keep of round 2 coming [withNextKeep], my first die kept in it.
    Future<void> resolveRound1(WidgetTester tester, {bool withNextKeep = true}) async {
      link.server(GameStateView.fromJson(fixture('round_start')[0]));
      link.serverResolved(RoundResolved.fromJson(fixture('round_resolved')[0]));
      if (withNextKeep) link.server(nextKeep());
      await tester.pump();
    }

    Future<void> skipToTheKeep(WidgetTester tester) async {
      await tester.tap(key('skip-to-keep'));
      await tester.pump();
      await tester.pump();
      expect(controller.isResolving, isFalse);
      expect(matchScreen(tester).resolving, isFalse);
      expect(find.text('Round 2 · relances : 2'), findsOneWidget);
      expect(matchScreen(tester).playhead.notch, 0);
      expect(caption(tester), 'Début du round.');
      expect(key('lock-$myFirst'), findsOneWidget, reason: 'the dice kept in the Keep stay kept');
      expect(controller.locks, {myFirst});
    }

    testWidgets('the button shows during Resolve once the next Keep has come, not before', (tester) async {
      await open(tester);
      await resolveRound1(tester, withNextKeep: false);
      expect(key('skip-to-keep'), findsNothing);

      link.server(nextKeep());
      await tester.pump();
      expect(key('skip-to-keep'), findsOneWidget);
      expect(find.text('Passer au Keep'), findsOneWidget);
      expect(key('confirm'), findsNothing);
      await skipToTheKeep(tester);
    });

    testWidgets('works while the playback is paused', (tester) async {
      await open(tester);
      await resolveRound1(tester);
      await tester.pump(step);
      await tester.tap(key('timeline-play')); // pause
      await tester.pump(const Duration(seconds: 5));
      expect(controller.isResolving, isTrue);
      await skipToTheKeep(tester);
    });

    testWidgets('works once the die view was opened, and closed', (tester) async {
      await open(tester);
      await resolveRound1(tester);
      await tester.tap(key('portrait-$myFirst'));
      await tester.pumpAndSettle();
      await tester.tap(key('die-view-close'));
      await tester.pumpAndSettle();
      expect(controller.isResolving, isTrue, reason: 'opening the die view stops the playback');
      await skipToTheKeep(tester);
    });

    testWidgets('works during the end dwell', (tester) async {
      await open(tester, endDwell: const Duration(seconds: 10));
      await resolveRound1(tester);
      await tester.pump(step * 20);
      expect(caption(tester), 'Fin du round.');
      expect(controller.isResolving, isTrue);
      await skipToTheKeep(tester);
    });

    testWidgets('no button once the match is over', (tester) async {
      await open(tester);
      await resolveRound1(tester);
      link.serverOver(const GameOver(0, EndReason.concede));
      await tester.pump();
      expect(key('skip-to-keep'), findsNothing);
      await playUntilDone(tester);
    });

    testWidgets('no button in a Keep', (tester) async {
      await open(tester);
      link.server(keep());
      await tester.pump();
      expect(key('skip-to-keep'), findsNothing);
      expect(key('confirm'), findsOneWidget);
    });
  });

  group('dispose while the replay waits', () {
    testWidgets('a paused replay: nothing thrown, no timer left', (tester) async {
      await open(tester);
      await resolve0(tester);
      await tester.pump(step);
      await tester.tap(key('timeline-play')); // pause
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
      // A timer left pending fails the test once its widgets are gone.
    });

    testWidgets('the end dwell: nothing thrown, no timer left', (tester) async {
      await open(tester, endDwell: const Duration(seconds: 10));
      await resolve0(tester);
      await tester.pump(step * 20);
      expect(controller.isResolving, isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      // A timer left pending fails the test once its widgets are gone.
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
