import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/human_match_controller.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/screens/match_screen.dart';
import 'package:goodlock_app/screens/spectator_match_view.dart';
import 'package:goodlock_app/widgets/die_view.dart';

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
          body: SpectatorMatchView(
            controller: controller,
            stepDelay: step,
            endDwell: Duration.zero,
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

  /// Round [i] of the recorded match: its Keep, the round the server resolved, then the next Keep or the game over.
  void round(int i, {GameOver? over}) {
    link.server(GameStateView.fromJson(fixture('round_start')[i]));
    link.serverResolved(RoundResolved.fromJson(fixture('round_resolved')[i]));
    if (over == null) {
      link.server(GameStateView.fromJson(fixture('round_start')[i + 1]));
    } else {
      link.serverOver(over);
    }
  }

  testWidgets('before combat, says what the bots are doing, with the clocks and nothing to confirm', (tester) async {
    await open(tester);
    expect(find.text('En attente du serveur…'), findsOneWidget);

    link.server(selectionState());
    await tester.pump();
    expect(find.textContaining('chaque bot garde 4 de ses 6'), findsOneWidget);
    expect(key('clock-me'), findsOneWidget);
    expect(key('confirm'), findsNothing);
    expect(find.byTooltip('Abandonner'), findsNothing, reason: 'a spectator has no match to concede');

    link.server(stateOf(Phase.placement, mine: [for (var i = 0; i < 4; i++) character('m$i', side: 0, slot: i)]));
    await tester.pump();
    expect(find.textContaining('Placement'), findsWidgets);
    expect(key('confirm'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FLOW-4: replays the round the server resolved by itself, read-only', (tester) async {
    await open(tester);
    round(0);
    await tester.pump();

    final screen = tester.widget<MatchScreen>(find.byType(MatchScreen));
    expect(screen.resolving, isTrue);
    expect(find.text('Round 1 · Résolution'), findsOneWidget);
    expect(caption(tester), 'Début du round.');
    expect(key('confirm'), findsNothing);
    expect(key('cancel'), findsNothing);
    expect(find.byTooltip('Abandonner'), findsNothing, reason: 'a spectator has no match to concede');
    expect(key('clock-me'), findsOneWidget);

    await tester.pump(step);
    await tester.pump(step);
    expect(caption(tester), startsWith('2. '));
    expect(tester.takeException(), isNull);
  });

  testWidgets('FLOW-5: the played round stays on screen, on its last notch, until the next one comes', (tester) async {
    await open(tester);
    round(0);
    await tester.pump();
    await playUntilDone(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MatchScreen), findsOneWidget);
    expect(caption(tester), 'Fin du round.');
    expect(find.text('Round 1 · Résolution'), findsOneWidget);

    round(1);
    await tester.pump();
    expect(find.text('Round 2 · Résolution'), findsOneWidget);
    expect(caption(tester), 'Début du round.');
    await playUntilDone(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LAYOUT-2: the bar shows who held the initiative in the round replayed, not in the next Keep', (
    tester,
  ) async {
    await open(tester);
    round(0); // initiative 0; the Keep of round 2 that came with it, 1
    await tester.pump();
    expect(find.byTooltip('Initiative : toi'), findsOneWidget);
    await playUntilDone(tester);

    round(1); // initiative 1; the Keep of round 3, 0
    await tester.pump();
    expect(find.byTooltip('Initiative : adversaire'), findsOneWidget);
    await playUntilDone(tester);
  });

  testWidgets('TL-6: a pause holds the replay; fast forward ends it', (tester) async {
    await open(tester);
    round(0);
    await tester.pump();
    await tester.pump(step);
    await tester.tap(key('timeline-play')); // pause
    await tester.pump(const Duration(seconds: 5));
    expect(controller.isResolving, isTrue);
    expect(caption(tester), startsWith('1. '));

    await tester.tap(key('timeline-fast-forward'));
    await tester.pump(step);
    await tester.pump();
    expect(controller.isResolving, isFalse);
    expect(caption(tester), 'Fin du round.');
  });

  testWidgets('CELL-5: tapping a portrait opens the die view; tapping a face keeps nothing', (tester) async {
    await open(tester);
    round(0);
    await tester.pump();
    final someone = RoundResolved.fromJson(fixture('round_resolved')[0]).startOfResolve.players[0].team.first;

    await tester.tap(key('face-${someone.id}'));
    await tester.pump();
    expect(controller.locks, isEmpty);

    await tester.tap(key('portrait-${someone.id}'));
    await tester.pumpAndSettle();
    expect(find.byType(DieView), findsOneWidget);
  });

  testWidgets('FLOW-6: the replay stops on the effect that ends the match, the result over it, and leaves', (
    tester,
  ) async {
    await open(tester);
    link.serverResolved(lateRound());
    link.serverOver(const GameOver(0, EndReason.elimination));
    await tester.pump();
    expect(find.text('Victoire'), findsNothing); // the round is still playing

    await playUntilDone(tester);
    await tester.pump();

    expect(find.text('Victoire'), findsOneWidget);
    expect(caption(tester), startsWith('3. Name m2'));
    await tester.tap(find.text('Retour'));
    expect(left, isTrue);
  });

  testWidgets('FLOW-6: a match that ends before any round shows its result at once', (tester) async {
    await open(tester);
    link.server(selectionState());
    link.serverOver(const GameOver(1, EndReason.concede));
    await tester.pump();

    expect(find.text('Défaite'), findsOneWidget);
  });
}
