import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/playhead.dart';
import 'package:goodlock_app/game/round_timeline.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/widgets/face_glyph.dart';
import 'package:goodlock_app/widgets/timeline_bar.dart';

import '../helpers/builders.dart';

const hit = DieFace('hit', 1, [
  FaceEffect(
    [
      TargetGroup('ENEMY', 'RELATIVE', [0]),
    ],
    [FacePart('Damage', 5)],
  ),
]);

ResolveStep step(String actor, {List<CharacterView> after = const [], bool skipped = false}) =>
    ResolveStep(actor, skipped, const [], [for (final c in after) ResolveChange(c.id, c)], unplayed: false);

/// A step the match ended before (END-1): skipped, with no changes.
ResolveStep unplayedStep(String actor) => ResolveStep(actor, true, const [], const [], unplayed: true);

/// [count] tokens k0..k(count-1), each with a face that hits, both teams in turn.
RoundTimeline manyTokens(int count) {
  final ids = [for (var i = 0; i < count; i++) 'k$i'];
  return RoundTimeline.build(
    [for (var i = 0; i < count; i++) character(ids[i], side: i % 2, slot: i ~/ 2, face: hit)],
    [for (final id in ids) step(id)],
  );
}

/// a (mine, hits), b (theirs, blank), c (mine, hits), in that order.
RoundTimeline threeTokens({List<String> order = const ['a', 'b', 'c']}) => RoundTimeline.build(
  [
    character('a', side: 0, slot: 0, face: hit),
    character('b', side: 1, slot: 0),
    character('c', side: 0, slot: 1, face: hit),
  ],
  [for (final id in order) step(id)],
);

Finder token(String id) => find.byKey(ValueKey('token-$id'));

void main() {
  Future<void> open(WidgetTester tester, RoundTimeline timeline, Playhead playhead, {int me = 0}) async {
    // A small phone in landscape.
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              TimelineBar(timeline: timeline, playhead: playhead, me: me),
            ],
          ),
        ),
      ),
    );
  }

  Playhead loaded(RoundTimeline timeline) {
    final p = Playhead()..load(timeline.notchCount);
    addTearDown(p.dispose);
    return p;
  }

  /// The bar alone at the bottom of a landscape screen [width] dp wide.
  Future<void> openAt(WidgetTester tester, RoundTimeline timeline, Playhead playhead, {required double width}) async {
    tester.view.physicalSize = Size(width * 3, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TimelineBar(timeline: timeline, playhead: playhead, me: 0),
          ),
        ),
      ),
    );
  }

  Color ringOf(WidgetTester tester, String id) {
    final container = tester.widget<Container>(
      find.descendant(of: token(id), matching: find.byType(Container)).first,
    );
    return (container.decoration! as BoxDecoration).border!.top.color;
  }

  double opacityOf(WidgetTester tester, String id) =>
      tester.widget<Opacity>(find.descendant(of: token(id), matching: find.byType(Opacity)).first).opacity;

  group('TL-1: tokens', () {
    testWidgets('TL-1: one token per action, in resolution order from left to right', (tester) async {
      final timeline = threeTokens(order: ['b', 'c', 'a']);
      await open(tester, timeline, loaded(timeline));

      expect(find.byType(FaceGlyph), findsNWidgets(3));
      final xs = [for (final id in ['b', 'c', 'a']) tester.getCenter(token(id)).dx];
      expect(xs[0], lessThan(xs[1]));
      expect(xs[1], lessThan(xs[2]));
      expect(tester.takeException(), isNull);
    });

    testWidgets('TL-1: a token shows the face of its character and a portrait with its initial', (tester) async {
      final timeline = threeTokens();
      await open(tester, timeline, loaded(timeline));

      expect(find.descendant(of: token('a'), matching: find.text('5')), findsOneWidget);
      expect(find.descendant(of: token('b'), matching: find.text('·')), findsOneWidget, reason: 'a blank face');
      expect(find.descendant(of: token('a'), matching: find.text('N')), findsOneWidget, reason: 'Name a');
    });

    testWidgets('TL-1: a token has the colour of its team, mine and the opponent\'s differ', (tester) async {
      final timeline = threeTokens();
      await open(tester, timeline, loaded(timeline));
      final mine = ringOf(tester, 'a');
      final theirs = ringOf(tester, 'b');

      expect(ringOf(tester, 'c'), mine);
      expect(theirs, isNot(mine));

      // Seen from the other seat, the colours swap.
      await open(tester, timeline, loaded(timeline), me: 1);
      expect(ringOf(tester, 'a'), theirs);
      expect(ringOf(tester, 'b'), mine);
    });

    testWidgets('TL-1: eight tokens fit a phone in landscape, each one wide enough to tap', (tester) async {
      final ids = [for (var i = 0; i < 8; i++) 'k$i'];
      final timeline = RoundTimeline.build(
        [for (var i = 0; i < 8; i++) character(ids[i], side: i % 2, slot: i ~/ 2, face: hit)],
        [for (final id in ids) step(id)],
      );
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 3; // 640×360 dp
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TimelineBar(timeline: timeline, playhead: loaded(timeline), me: 0),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TimelineBar)).height, inInclusiveRange(56, 76));
      for (final id in ids) {
        expect(tester.getRect(token(id)).right, lessThanOrEqualTo(640));
        expect(tester.getSize(token(id)).width, greaterThanOrEqualTo(44));
      }
    });
  });

  group('TL-1: narrow screens', () {
    testWidgets('TL-1: on a narrow bar the tokens shrink to fit the track, each still wide enough to tap', (
      tester,
    ) async {
      final timeline = manyTokens(8);
      await openAt(tester, timeline, loaded(timeline), width: 480); // 8 × 52 dp do not fit

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('timeline-scroll')), findsNothing, reason: 'they fit without scrolling');
      final track = tester.getRect(find.byKey(const ValueKey('timeline-track')));
      final rects = [for (var i = 0; i < 8; i++) tester.getRect(token('k$i'))];
      for (final r in rects) {
        expect(r.left, greaterThanOrEqualTo(track.left));
        expect(r.right, lessThanOrEqualTo(track.right));
        expect(r.width, greaterThanOrEqualTo(44));
      }
      for (var i = 1; i < 8; i++) {
        expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right), reason: 'k$i does not overlap k${i - 1}');
      }
    });

    testWidgets('TL-1: when even the narrowest tokens do not fit, the row scrolls and follows the playhead', (
      tester,
    ) async {
      final timeline = manyTokens(8); // 10 notches
      final playhead = loaded(timeline);
      await openAt(tester, timeline, playhead, width: 384);
      final view = tester.getRect(find.byKey(const ValueKey('timeline-scroll')));

      expect(tester.takeException(), isNull);
      final rects = [for (var i = 0; i < 8; i++) tester.getRect(token('k$i'))];
      for (var i = 0; i < 8; i++) {
        expect(rects[i].width, greaterThanOrEqualTo(44), reason: 'k$i stays a touch target');
        if (i > 0) expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right));
      }
      expect(rects.last.right, greaterThan(view.right), reason: 'the last token starts out of view');

      playhead.fastForward();
      await tester.pumpAndSettle();
      expect(tester.getRect(token('k7')).right, lessThanOrEqualTo(view.right), reason: 'the row followed the playhead');
      final marker = tester.getCenter(find.byKey(const ValueKey('timeline-playhead'))).dx;
      expect(marker, inInclusiveRange(view.left, view.right));

      playhead.seekToNotch(0);
      await tester.pumpAndSettle();
      expect(tester.getRect(token('k0')).left, greaterThanOrEqualTo(view.left), reason: 'and back to the start');
    });

    testWidgets('TL-6: on a scrolling row, dragging to the edge of the view scrolls on to the next steps', (
      tester,
    ) async {
      final timeline = manyTokens(8);
      final playhead = loaded(timeline);
      await openAt(tester, timeline, playhead, width: 384);
      final view = tester.getRect(find.byKey(const ValueKey('timeline-scroll')));
      final start = tester.getCenter(token('k0'));

      final gesture = await tester.startGesture(start);
      await gesture.moveTo(Offset(view.right - 5, start.dy));
      await tester.pumpAndSettle();
      final atEdge = playhead.notch;
      expect(atEdge, greaterThan(0));

      await gesture.moveBy(const Offset(1, 0));
      await tester.pumpAndSettle();
      await gesture.up();
      expect(playhead.notch, greaterThan(atEdge), reason: 'the row scrolled under the finger');
      expect(tester.takeException(), isNull);
    });
  });

  group('TL-3: states', () {
    testWidgets('TL-3: the steps already played are faded, the current step is circled', (tester) async {
      final timeline = threeTokens();
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);

      expect(find.byKey(const ValueKey('token-current-a')), findsNothing, reason: 'notch 0: before any action');
      expect(opacityOf(tester, 'a'), 1);

      playhead.seekToNotch(2); // after b's action
      await tester.pump();
      expect(opacityOf(tester, 'a'), lessThan(1));
      expect(opacityOf(tester, 'b'), 1);
      expect(opacityOf(tester, 'c'), 1);
      expect(find.byKey(const ValueKey('token-current-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('token-current-a')), findsNothing);
      expect(find.byKey(const ValueKey('token-current-c')), findsNothing);

      playhead.fastForward(); // the end of the round: every action played, none current
      await tester.pump();
      expect([for (final id in ['a', 'b', 'c']) opacityOf(tester, id)], everyElement(lessThan(1)));
      expect(find.byWidgetPredicate((w) => '${w.key}'.contains('token-current-')), findsNothing);
    });

    testWidgets('TL-3: a stunned character\'s token has a stun mark and is dimmed', (tester) async {
      final timeline = RoundTimeline.build(
        [character('a', side: 0, slot: 0, face: hit), character('b', side: 1, slot: 0, face: hit)],
        [step('a', skipped: true), step('b')],
      );
      await open(tester, timeline, loaded(timeline));

      expect(find.byKey(const ValueKey('token-stunned-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('token-stunned-b')), findsNothing);
      expect(opacityOf(tester, 'a'), lessThan(1));
      expect(opacityOf(tester, 'b'), 1);
    });

    testWidgets('TL-3: the token of a character that died before its turn is darkened, with a death mark', (
      tester,
    ) async {
      final timeline = RoundTimeline.build(
        [character('a', side: 0, slot: 0, face: hit), character('b', side: 1, slot: 0, hp: 3, face: hit)],
        [
          step('a', after: [character('b', side: 1, slot: 0, hp: 0, face: hit)]),
          step('b', skipped: true),
        ],
      );
      await open(tester, timeline, loaded(timeline));

      expect(find.byKey(const ValueKey('token-dead-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('token-dead-a')), findsNothing);
      expect(find.byKey(const ValueKey('token-stunned-b')), findsNothing);
      expect(opacityOf(tester, 'b'), lessThan(1));
    });
  });

  group('TL-3: what each state looks like', () {
    bool darkened(WidgetTester tester, String id) => find
        .descendant(
          of: token(id),
          matching: find.byWidgetPredicate((w) {
            if (w is! Container) return false;
            final overlay = w.foregroundDecoration;
            if (overlay is! BoxDecoration || overlay.color == null) return false;
            return overlay.color!.a >= 0.5 && overlay.color!.computeLuminance() < 0.01;
          }),
        )
        .evaluate()
        .isNotEmpty;

    testWidgets('TL-3: a dead character\'s token is darkened by a black overlay, a stunned one\'s is not', (
      tester,
    ) async {
      final timeline = RoundTimeline.build(
        [
          character('a', side: 0, slot: 0, face: hit),
          character('b', side: 1, slot: 0, hp: 3, face: hit),
          character('c', side: 0, slot: 1, face: hit),
        ],
        [
          step('a', after: [character('b', side: 1, slot: 0, hp: 0, face: hit)]),
          step('b', skipped: true),
          step('c', skipped: true),
        ],
      );
      await open(tester, timeline, loaded(timeline));

      expect(darkened(tester, 'b'), isTrue, reason: 'dead');
      expect(darkened(tester, 'c'), isFalse, reason: 'stunned: dimmed, not darkened');
      expect(darkened(tester, 'a'), isFalse);
    });

    testWidgets('TL-3 (user decision): a blank face is neither dimmed nor marked, its glyph says it', (tester) async {
      final timeline = threeTokens(); // b has a blank face
      await open(tester, timeline, loaded(timeline));

      expect(opacityOf(tester, 'b'), 1);
      expect(find.descendant(of: token('b'), matching: find.byType(Icon)), findsNothing);
      expect(find.descendant(of: token('b'), matching: find.text('·')), findsOneWidget);
    });

    testWidgets('END-1: an action the match ended before is faded with a match-ended mark', (tester) async {
      final timeline = RoundTimeline.build(
        [character('a', side: 0, slot: 0, face: hit), character('b', side: 1, slot: 0, face: hit)],
        [step('a'), unplayedStep('b')],
      );
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);

      expect(find.byKey(const ValueKey('token-unplayed-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('token-unplayed-a')), findsNothing);
      expect(find.byKey(const ValueKey('token-stunned-b')), findsNothing, reason: 'it was not stunned');
      expect(find.byKey(const ValueKey('token-dead-b')), findsNothing);
      expect(opacityOf(tester, 'b'), 0.5);
      expect(opacityOf(tester, 'a'), 1);
      expect(find.byKey(const ValueKey('token-current-b')), findsNothing);

      playhead.seekToNotch(1); // on a's action
      await tester.pump();
      expect(find.byKey(const ValueKey('token-current-b')), findsNothing);

      playhead.seekToNotch(2); // on b's
      await tester.pump();
      expect(find.byKey(const ValueKey('token-current-b')), findsOneWidget);
      expect(opacityOf(tester, 'b'), 0.5);

      playhead.fastForward();
      await tester.pump();
      expect(find.byKey(const ValueKey('token-current-b')), findsNothing);
      expect(opacityOf(tester, 'b'), 0.5);
    });
  });

  group('TL-4: the playhead', () {
    testWidgets('TL-4: the playhead runs from before the first token to after the last one', (tester) async {
      final timeline = threeTokens();
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);
      final marker = find.byKey(const ValueKey('timeline-playhead'));

      final xs = <double>[];
      for (var notch = 0; notch < timeline.notchCount; notch++) {
        playhead.seekToNotch(notch);
        await tester.pump();
        xs.add(tester.getCenter(marker).dx);
      }

      expect(xs.first, lessThanOrEqualTo(tester.getRect(token('a')).left));
      expect(xs.last, greaterThanOrEqualTo(tester.getRect(token('c')).right));
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThan(xs[i - 1]), reason: 'notch $i is right of notch ${i - 1}');
      }
    });
  });

  group('mismatched or empty timelines', () {
    testWidgets('a playhead with more notches than the timeline is drawn on the timeline\'s last notch', (
      tester,
    ) async {
      final timeline = threeTokens(); // 5 notches
      final playhead = Playhead()..load(8);
      addTearDown(playhead.dispose);
      await open(tester, timeline, playhead);
      final marker = find.byKey(const ValueKey('timeline-playhead'));

      playhead.seekToNotch(4);
      await tester.pump();
      final last = tester.getCenter(marker).dx;
      playhead.seekToNotch(7);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getCenter(marker).dx, last);
      expect(find.byWidgetPredicate((w) => '${w.key}'.contains('token-current-')), findsNothing);
    });

    testWidgets('a playhead with fewer notches than the timeline still shows its notch', (tester) async {
      final timeline = threeTokens(); // 5 notches
      final playhead = Playhead()..load(3);
      addTearDown(playhead.dispose);
      await open(tester, timeline, playhead);

      playhead.seekToNotch(2);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('token-current-b')), findsOneWidget);
    });

    testWidgets('a round with no action: dragging or tapping the track moves nothing and throws nothing', (
      tester,
    ) async {
      final timeline = RoundTimeline.build([character('a', side: 0, slot: 0, face: hit)], const []);
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);
      final track = find.byKey(const ValueKey('timeline-track'));

      await tester.drag(track, const Offset(200, 0));
      await tester.tap(track);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(playhead.notch, 0);
    });
  });

  group('TL-6: interactions', () {
    testWidgets('TL-6: the play button plays and pauses, its icon follows', (tester) async {
      final timeline = threeTokens();
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);
      final play = find.byKey(const ValueKey('timeline-play'));

      expect(find.descendant(of: play, matching: find.byIcon(Icons.play_arrow)), findsOneWidget);
      await tester.tap(play);
      await tester.pump();
      expect(playhead.playing, isTrue);
      expect(find.descendant(of: play, matching: find.byIcon(Icons.pause)), findsOneWidget);

      await tester.tap(play);
      await tester.pump();
      expect(playhead.playing, isFalse);
      expect(find.descendant(of: play, matching: find.byIcon(Icons.play_arrow)), findsOneWidget);
    });

    testWidgets('TL-6: fast forward puts the playhead on the last notch', (tester) async {
      final timeline = threeTokens();
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);

      await tester.tap(find.byKey(const ValueKey('timeline-fast-forward')));
      await tester.pump();
      expect(playhead.notch, timeline.notchCount - 1);
    });

    testWidgets('TL-6: tapping a token puts the playhead on its action', (tester) async {
      final timeline = threeTokens();
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);

      await tester.tap(token('b'));
      await tester.pump();
      expect(playhead.notch, 2);
      expect(find.byKey(const ValueKey('token-current-b')), findsOneWidget);
    });

    testWidgets('TL-6: tapping a token stops the playback', (tester) async {
      final timeline = threeTokens();
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);

      playhead.play();
      await tester.pump();
      await tester.tap(token('a'));
      await tester.pump();
      expect(playhead.playing, isFalse);
      expect(playhead.notch, 1);
    });

    testWidgets('TL-6: dragging along the timeline moves the playhead to the nearest notch', (tester) async {
      final timeline = threeTokens(); // 5 notches
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);
      final right = tester.getRect(token('c')).right + 30;

      await tester.dragFrom(tester.getCenter(token('a')), Offset(right - tester.getCenter(token('a')).dx, 0));
      await tester.pump();
      expect(playhead.atEnd, isTrue);

      // The centre of b, the middle of three tokens, is halfway along the timeline.
      final b = tester.getCenter(token('b'));
      await tester.dragFrom(Offset(right, b.dy), Offset(b.dx - right, 0));
      await tester.pump();
      expect(playhead.notch, 2);

      final left = tester.getRect(token('a')).left - 30;
      await tester.dragFrom(b, Offset(left - b.dx, 0));
      await tester.pump();
      expect(playhead.notch, 0);
    });
  });

  group('accessibility', () {
    testWidgets('the play and fast forward buttons have tooltips, the play one follows the playback', (tester) async {
      final timeline = threeTokens();
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);

      expect(find.byTooltip('Lecture'), findsOneWidget);
      expect(find.byTooltip('Fin du round'), findsOneWidget);
      playhead.play();
      await tester.pump();
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('Lecture'), findsNothing);
      playhead.pause();
    });

    testWidgets('each token is a button named by its character, its face and the state of its action', (
      tester,
    ) async {
      final timeline = threeTokens();
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Name a, hit, à venir')),
        matchesSemantics(label: 'Name a, hit, à venir', isButton: true, hasSelectedState: true, hasTapAction: true),
      );

      playhead.seekToNotch(2);
      await tester.pump();
      expect(find.bySemanticsLabel('Name a, hit, joué'), findsOneWidget);
      expect(find.bySemanticsLabel('Name c, hit, à venir'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Name b, rest, en cours')),
        matchesSemantics(
          label: 'Name b, rest, en cours',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('a token says why its action does not play: stunned, dead, or left unplayed', (tester) async {
      final timeline = RoundTimeline.build(
        [
          character('a', side: 0, slot: 0, face: hit),
          character('b', side: 1, slot: 0, hp: 3, face: hit),
          character('c', side: 0, slot: 1, face: hit),
          character('d', side: 1, slot: 1, face: hit),
        ],
        [
          step('a', after: [character('b', side: 1, slot: 0, hp: 0, face: hit)]),
          step('b', skipped: true),
          step('c', skipped: true),
          unplayedStep('d'),
        ],
      );
      final playhead = loaded(timeline);
      await open(tester, timeline, playhead);

      expect(find.bySemanticsLabel('Name b, hit, mort'), findsOneWidget);
      expect(find.bySemanticsLabel('Name c, hit, étourdi'), findsOneWidget);
      expect(find.bySemanticsLabel('Name d, hit, non joué'), findsOneWidget);

      playhead.seekToNotch(3); // on c's action
      await tester.pump();
      expect(find.bySemanticsLabel('Name c, hit, étourdi, en cours'), findsOneWidget);
    });

    testWidgets('a face with no description is named by its value, or as blank', (tester) async {
      const bare = DieFace('', 1, [
        FaceEffect(
          [
            TargetGroup('ENEMY', 'RELATIVE', [0]),
          ],
          [FacePart('Damage', 7)],
        ),
      ]);
      final timeline = RoundTimeline.build(
        [
          character('a', side: 0, slot: 0, face: bare),
          character('b', side: 1, slot: 0, face: const DieFace('', 0, [])),
        ],
        [step('a'), step('b')],
      );
      await open(tester, timeline, loaded(timeline));

      expect(find.bySemanticsLabel('Name a, valeur 7, à venir'), findsOneWidget);
      expect(find.bySemanticsLabel('Name b, face vide, à venir'), findsOneWidget);
    });
  });

  group('TL-2: motion', () {
    testWidgets('TL-2: when the order changes, the tokens slide to their new rank', (tester) async {
      final playhead = Playhead()..load(5);
      addTearDown(playhead.dispose);
      await open(tester, threeTokens(), playhead);
      final before = tester.getCenter(token('c')).dx;

      await open(tester, threeTokens(order: ['c', 'a', 'b']), playhead);
      await tester.pump(const Duration(milliseconds: 100));
      final sliding = tester.getCenter(token('c')).dx;
      expect(sliding, lessThan(before), reason: 'c has started to move left');

      await tester.pumpAndSettle();
      final after = [for (final id in ['c', 'a', 'b']) tester.getCenter(token(id)).dx];
      expect(sliding, greaterThan(after[0]), reason: 'c slid, it did not jump');
      expect(after[0], lessThan(after[1]));
      expect(after[1], lessThan(after[2]));
    });
  });
}
