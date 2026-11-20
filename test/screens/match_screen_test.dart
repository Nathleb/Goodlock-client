import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/human_match_controller.dart';
import 'package:goodlock_app/game/playhead.dart';
import 'package:goodlock_app/game/round_timeline.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/screens/match_screen.dart';
import 'package:goodlock_app/widgets/die_view.dart';
import 'package:goodlock_app/widgets/match_bar.dart';
import 'package:goodlock_app/widgets/match_board.dart';
import 'package:goodlock_app/widgets/timeline_bar.dart';

import '../helpers/builders.dart';
import '../helpers/fake_link.dart';

const hit = DieFace('hit', 1, [
  FaceEffect(
    [
      TargetGroup('ENEMY', 'RELATIVE', [0]),
    ],
    [FacePart('Damage', 5)],
  ),
]);

List<CharacterView> mine({List<String> locked = const []}) => [
  for (var i = 0; i < 4; i++) character('m$i', side: 0, slot: i, face: i == 0 ? hit : blankFace, locked: locked.contains('m$i')),
];
List<CharacterView> theirs() => [for (var i = 0; i < 4; i++) character('t$i', side: 1, slot: i, face: i == 1 ? hit : blankFace)];

/// m0 hits t0 for 5, then t1 kills m1, then m2 plays a blank face: five notches.
List<ResolveStep> round() => [
  ResolveStep('m0', false, const [
    ResolvedEffect(['Damage'], [Cell(1, 0)]),
  ], [ResolveChange('t0', character('t0', side: 1, slot: 0, hp: 15))]),
  ResolveStep('t1', false, const [
    ResolvedEffect(['Damage'], [Cell(0, 1)]),
  ], [ResolveChange('m1', character('m1', side: 0, slot: 1, hp: 0))]),
  const ResolveStep('m2', false, [], []),
];

GameStateView keep({bool ready = false, List<String> locked = const []}) =>
    stateOf(Phase.keep, myReady: ready, mine: mine(locked: locked), theirs: theirs(), preview: round());

Finder key(String k) => find.byKey(ValueKey(k));

void main() {
  late FakeLink link;
  late HumanMatchController controller;
  late Playhead playhead;

  /// A common 20:9 phone in landscape by default: 2400×1080 px at 2.625 dpr ≈ 914×411 dp.
  Future<void> open(
    WidgetTester tester, {
    GameStateView? state,
    bool resolving = false,
    String? phaseLabel,
    Size size = const Size(2400, 1080),
    double dpr = 2.625,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    link = FakeLink();
    controller = HumanMatchController(link, me: 0);
    addTearDown(controller.dispose);
    link.server(state ?? keep());
    final timeline = resolving ? RoundTimeline.build([...mine(), ...theirs()], round()) : controller.keepTimeline!;
    playhead = Playhead(stepDelay: const Duration(milliseconds: 10))..load(timeline.notchCount);
    addTearDown(playhead.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchScreen(
            controller: controller,
            playhead: playhead,
            timeline: timeline,
            resolving: resolving,
            phaseLabel: phaseLabel,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> at(WidgetTester tester, int notch) async {
    playhead.seekToNotch(notch);
    await tester.pump();
  }

  Finder caption() => key('step-caption');
  String captionText(WidgetTester tester) => tester.widget<Text>(caption()).data!;

  testWidgets('LAYOUT-1: three bands, the status bar on top, the board in the middle, the timeline at the bottom', (
    tester,
  ) async {
    await open(tester);

    final bar = tester.getRect(find.byType(MatchBar));
    final board = tester.getRect(find.byType(MatchBoard));
    final timeline = tester.getRect(find.byType(TimelineBar));
    expect(bar.bottom, lessThanOrEqualTo(board.top));
    expect(board.bottom, lessThanOrEqualTo(timeline.top));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(640, 360), Size(800, 360)]) {
    for (final resolving in [false, true]) {
      testWidgets('LAYOUT-1: no overflow at ${size.width.toInt()}×${size.height.toInt()} '
          '(${resolving ? 'Resolve' : 'Keep'}), on every notch', (tester) async {
        await open(tester, size: size, dpr: 1, resolving: resolving, phaseLabel: resolving ? 'Round 1 · Résolution' : null);
        for (var notch = 0; notch < 5; notch++) {
          await at(tester, notch);
          expect(tester.takeException(), isNull, reason: 'notch $notch');
        }
      });
    }
  }

  testWidgets('TL-1: the timeline shows the round, one token per action', (tester) async {
    await open(tester);
    expect(find.byType(TimelineBar), findsOneWidget);
    for (final id in ['m0', 't1', 'm2']) {
      expect(key('token-$id'), findsOneWidget);
    }
  });

  testWidgets('LAYOUT-2, STEP-5: the status bar captions the step on display and follows the playhead', (tester) async {
    await open(tester);
    expect(captionText(tester), 'Début du round.');
    expect(find.descendant(of: find.byType(MatchBar), matching: caption()), findsOneWidget);

    await at(tester, 1);
    expect(captionText(tester), startsWith('1. Name m0 : 5 dégâts'));

    await at(tester, 4);
    expect(captionText(tester), 'Fin du round si personne ne relance.');
  });

  testWidgets('LAYOUT-2: the status bar keeps the round, the rerolls left and the Confirm button in the Keep', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Round 1 · relances : 2'), findsOneWidget);
    expect(key('confirm'), findsOneWidget);
  });

  testWidgets('STEP-1, CELL-3, CELL-6: the board shows the state of the notch, the dead off their cell', (tester) async {
    await open(tester);
    expect(find.text('20/20'), findsNWidgets(8));

    await at(tester, 1);
    expect(find.text('15/20'), findsOneWidget);
    expect(key('hp-lost-t0'), findsOneWidget);

    await at(tester, 2);
    expect(find.text('Name m1'), findsNothing);

    await at(tester, 0);
    expect(find.text('Name m1'), findsOneWidget);
  });

  testWidgets('CELL-5: in the Keep, tapping my face keeps or releases it wherever the playhead stands', (tester) async {
    await open(tester);

    await at(tester, 2);
    await tester.tap(key('face-m2'));
    await tester.pump();
    expect(controller.locks, {'m2'});
    expect(key('lock-m2'), findsOneWidget);
    expect(playhead.notch, 2, reason: 'keeping a die does not move the playhead');

    await at(tester, 4);
    await tester.tap(key('face-m2'));
    await tester.pump();
    expect(controller.locks, isEmpty);
    expect(key('lock-m2'), findsNothing);
  });

  testWidgets('GAME-8: once confirmed, my faces cannot be tapped', (tester) async {
    await open(tester, state: keep(ready: true, locked: ['m0']));
    expect(tester.widget<InkWell>(key('face-m2')).onTap, isNull);
    await tester.tap(key('face-m2'));
    await tester.pump();
    expect(controller.locks, {'m0'});
    expect(key('cancel'), findsOneWidget);
  });

  testWidgets('CELL-4: in the Keep, the opponent\'s faces cannot be tapped and never show a lock mark', (tester) async {
    final theirsLocked = [
      for (var i = 0; i < 4; i++) character('t$i', side: 1, slot: i, face: i == 1 ? hit : blankFace, locked: i == 0),
    ];
    await open(tester, state: stateOf(Phase.keep, mine: mine(), theirs: theirsLocked, preview: round()));
    await tester.tap(key('face-t1'));
    await tester.pump();

    expect(controller.locks, isEmpty);
    expect(key('lock-t0'), findsNothing);
    expect(key('lock-t1'), findsNothing);
  });

  testWidgets('GAME-9: in the Keep, nothing says whether the opponent has confirmed', (tester) async {
    await open(tester);
    expect(find.textContaining('prêt'), findsNothing);
    expect(find.textContaining('a confirmé'), findsNothing);
  });

  testWidgets('FLOW-4: in Resolve, faces cannot be tapped, and the bar reads Resolve with no Confirm', (tester) async {
    await open(tester, resolving: true, phaseLabel: 'Round 1 · Résolution');
    await tester.tap(key('face-m2'));
    await tester.pump();

    expect(controller.locks, isEmpty);
    expect(find.text('Round 1 · Résolution'), findsOneWidget);
    expect(key('confirm'), findsNothing);
    expect(key('cancel'), findsNothing);

    await at(tester, 4);
    expect(captionText(tester), 'Fin du round.');
  });

  testWidgets('CELL-5, TL-6: tapping a portrait, on either side, stops the playback and opens the die view', (
    tester,
  ) async {
    await open(tester, resolving: true);
    playhead.play();
    await tester.pump();

    await tester.tap(key('portrait-t2'));
    await tester.pump(); // no time passes: the playback is stopped by the tap, not over
    expect(playhead.playing, isFalse);
    expect(playhead.notch, 0);
    await tester.pumpAndSettle();
    expect(find.byType(DieView), findsOneWidget);
    expect(find.descendant(of: find.byType(DieView), matching: find.text('Name t2')), findsOneWidget);

    await tester.tap(key('die-view-close'));
    await tester.pumpAndSettle();
    await tester.tap(key('portrait-m0'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(DieView), matching: find.text('Name m0')), findsOneWidget);
  });
}
