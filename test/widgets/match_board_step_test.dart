import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/round_timeline.dart';
import 'package:goodlock_app/game/step_outcome.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/widgets/cell_tile.dart';
import 'package:goodlock_app/widgets/dashed_box.dart';
import 'package:goodlock_app/widgets/die_face_tile.dart';
import 'package:goodlock_app/widgets/match_board.dart';

import '../helpers/builders.dart';

const hit = DieFace('hit', 1, [
  FaceEffect(
    [
      TargetGroup('ENEMY', 'RELATIVE', [0]),
    ],
    [FacePart('Damage', 5)],
  ),
]);

/// Mine: m0..m3 on slots 0..3, slot 4 empty. Theirs: t0..t3 on slots 0..3, slot 4 empty.
List<PlayerView> board({int m1Hp = 15}) => [
  PlayerView(0, [
    character('m0', side: 0, slot: 0, face: hit),
    character('m1', side: 0, slot: 1, hp: m1Hp),
    character('m2', side: 0, slot: 2),
    character('m3', side: 0, slot: 3),
  ]),
  PlayerView(1, [
    character('t0', side: 1, slot: 0),
    character('t1', side: 1, slot: 1),
    character('t2', side: 1, slot: 2),
    character('t3', side: 1, slot: 3),
  ]),
];

/// m0 hits t0 and the empty cell 4 in front, and shields itself.
const hitAndShield = StepOutcome('m0', false, [
  CellOutcome(Cell(1, 0), 't0', 'Damage', '−5'),
  CellOutcome(Cell(1, 4), null, 'Damage', 'raté'),
  CellOutcome(Cell(0, 0), 'm0', 'Shield', 'Bouclier +4'),
], '1. Name m0 : ...');

Finder key(String k) => find.byKey(ValueKey(k));

Finder cellOf(String id) => find.ancestor(of: find.text('Name $id'), matching: find.byType(CellTile));

void main() {
  Future<void> open(
    WidgetTester tester, {
    List<PlayerView>? players,
    StepOutcome? outcome,
    Map<String, int>? roundStartHp,
    Widget? center,
    Size size = const Size(2400, 1080),
    double dpr = 2.625,
    void Function(CharacterView)? onPortraitTap,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchBoard(
            players: players ?? board(),
            me: 0,
            outcome: outcome,
            roundStartHp: roundStartHp,
            center: center,
            onPortraitTap: onPortraitTap,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Color borderColorOf(WidgetTester tester, String k) {
    final box = tester.widget<DecoratedBox>(key(k));
    return ((box.decoration as BoxDecoration).border! as Border).top.color;
  }

  /// The middle of the lane, between my cells and the opponent's (m1 and t1 are never highlighted here).
  double laneMiddle(WidgetTester tester) =>
      (tester.getRect(cellOf('m1')).right + tester.getRect(cellOf('t1')).left) / 2;

  group('STEP-1: the acting character', () {
    testWidgets('STEP-1: only the acting character\'s cell is ringed in white', (tester) async {
      await open(tester, outcome: hitAndShield);
      expect(key('actor-ring-m0'), findsOneWidget);
      expect(borderColorOf(tester, 'actor-ring-m0'), Colors.white);
      expect(
        find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('actor-ring-')),
        findsOneWidget,
      );
    });

    testWidgets('STEP-1: the acting character\'s cell comes forward, bigger than its neighbours', (tester) async {
      await open(tester, outcome: hitAndShield);
      expect(tester.getRect(cellOf('m0')).width, greaterThan(tester.getRect(cellOf('m1')).width));
      expect(tester.getRect(cellOf('m0')).height, greaterThan(tester.getRect(cellOf('m1')).height));
      // Still level with the cell it faces.
      expect(tester.getCenter(cellOf('m0')).dy, closeTo(tester.getCenter(cellOf('t0')).dy, 1));
    });

    testWidgets('STEP-1: the acting character\'s cell is painted after its neighbours and the lane, so above them', (
      tester,
    ) async {
      await open(tester, outcome: hitAndShield);
      // Rows, columns and stacks paint their children in order: the tree order is the paint order.
      final order = find
          .byWidgetPredicate(
            (w) =>
                w.key == const ValueKey('actor-ring-m0') ||
                w.key == const ValueKey('label-0-0') ||
                (w is CellTile && w.character.id != 'm0'),
          )
          .evaluate()
          .map((e) => e.widget is CellTile ? 'cell' : '${(e.widget.key as ValueKey).value}')
          .toList();
      expect(order.last, 'actor-ring-m0');
      expect(order.where((k) => k == 'cell'), hasLength(7));
      expect(order, contains('label-0-0'));
    });

    testWidgets('STEP-1: the acting character\'s portrait can still be tapped, and its neighbours\' too', (
      tester,
    ) async {
      final tapped = <String>[];
      await open(tester, outcome: hitAndShield, onPortraitTap: (c) => tapped.add(c.id));
      await tester.tap(key('portrait-m0'));
      await tester.tap(key('portrait-m1'));
      expect(tapped, ['m0', 'm1']);
    });

    testWidgets('STEP-1: with no outcome nothing is ringed and the lane shows its centre', (tester) async {
      await open(tester, center: const Text('a caption'));
      expect(key('actor-ring-m0'), findsNothing);
      expect(find.descendant(of: find.byType(MatchBoard), matching: find.byType(Transform)), findsNothing);
      expect(find.text('a caption'), findsOneWidget);
    });

    testWidgets('STEP-1: with an outcome the lane shows the step, not the centre', (tester) async {
      await open(tester, outcome: hitAndShield, center: const Text('a caption'));
      expect(find.text('a caption'), findsNothing);
    });

    testWidgets('STEP-5: a start or end notch rings nothing and labels nothing', (tester) async {
      await open(tester, outcome: const StepOutcome(null, false, [], 'Début du round.'));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              RegExp(r'^(actor-ring|target|label|skipped)-').hasMatch('${(w.key as ValueKey).value}'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('STEP-2: target cells and their labels', () {
    testWidgets('STEP-2: each target cell has a border in the colour of the effect, the others none', (tester) async {
      await open(tester, outcome: hitAndShield);
      expect(borderColorOf(tester, 'target-1-0'), effectColors['Damage']);
      expect(borderColorOf(tester, 'target-0-0'), effectColors['Shield']);
      expect(find.descendant(of: key('target-1-0'), matching: find.text('Name t0')), findsOneWidget);
      expect(key('target-1-1'), findsNothing);
      expect(key('target-0-1'), findsNothing);
    });

    testWidgets('STEP-2: an effect with no known colour gets a neutral border', (tester) async {
      await open(
        tester,
        outcome: const StepOutcome('m0', false, [CellOutcome(Cell(1, 2), 't2', '', 'sans effet')], ''),
      );
      expect(borderColorOf(tester, 'target-1-2'), Colors.white54);
      expect(tester.widget<Text>(key('label-1-2')).style?.color, Colors.white54);
    });

    testWidgets('STEP-2: the label shows what the effect did, in its colour, level with its cell', (tester) async {
      await open(tester, outcome: hitAndShield);
      final label = tester.widget<Text>(key('label-1-0'));
      expect(label.data, '−5');
      expect(label.style?.color, effectColors['Damage']);
      expect(tester.getCenter(key('label-1-0')).dy, closeTo(tester.getCenter(cellOf('t0')).dy, 1));
      expect(tester.widget<Text>(key('label-0-0')).data, 'Bouclier +4');
      expect(tester.getCenter(key('label-0-0')).dy, closeTo(tester.getCenter(cellOf('m0')).dy, 1));
    });

    testWidgets('STEP-2: a label of my side sits left in the lane, the opponent\'s right, in the same row', (
      tester,
    ) async {
      await open(tester, outcome: hitAndShield);
      final middle = laneMiddle(tester);
      final mine = tester.getRect(key('label-0-0'));
      final theirs = tester.getRect(key('label-1-0'));
      expect(mine.center.dx, lessThan(middle));
      expect(theirs.center.dx, greaterThan(middle));
      expect(mine.right, lessThanOrEqualTo(theirs.left));
      // Both stay in the lane.
      expect(mine.left, greaterThanOrEqualTo(tester.getRect(cellOf('m1')).right));
      expect(theirs.right, lessThanOrEqualTo(tester.getRect(cellOf('t1')).left));
    });
  });

  group('STEP-3: an empty target cell', () {
    testWidgets('STEP-3: an empty target cell is dashed in the colour of the effect, and its label reads "raté"', (
      tester,
    ) async {
      await open(tester, outcome: hitAndShield);
      final dashed = tester.widget<DashedBox>(key('target-1-4'));
      expect(dashed.color, effectColors['Damage']);
      expect(tester.widget<Text>(key('label-1-4')).data, 'raté');
      expect(tester.getCenter(key('label-1-4')).dy, closeTo(tester.getCenter(key('target-1-4')).dy, 1));
      // My empty cell, not a target, keeps its plain dashes.
      final plain = tester.widgetList<DashedBox>(find.byType(DashedBox)).where((d) => d.key == null);
      expect(plain.single.color, const DashedBox().color);
    });
  });

  group('STEP-4: a skipped action', () {
    const stunned = StepOutcome('t1', true, [], '2. Name t1 : action annulée (étourdi).');

    testWidgets('STEP-4: a skipped action reads "Action annulée (étourdi)" level with its character, on its side', (
      tester,
    ) async {
      await open(tester, outcome: stunned);
      expect(tester.widget<Text>(key('skipped-t1')).data, 'Action annulée (étourdi)');
      expect(tester.getCenter(key('skipped-t1')).dy, closeTo(tester.getCenter(cellOf('t1')).dy, 1));
      expect(tester.getCenter(key('skipped-t1')).dx, greaterThan(laneMiddle(tester)));
      expect(key('actor-ring-t1'), findsOneWidget);
    });

    testWidgets('STEP-4: a skipped action of mine reads on my side of the lane', (tester) async {
      await open(tester, outcome: const StepOutcome('m2', true, [], ''));
      expect(tester.getCenter(key('skipped-m2')).dx, lessThan(laneMiddle(tester)));
    });

    testWidgets('STEP-4: an actor that is no longer on the board shows no label', (tester) async {
      await open(tester, outcome: const StepOutcome('gone', true, [], ''));
      expect(key('skipped-gone'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('CELL-3: HP lost since the round started', () {
    Rect barOf(WidgetTester tester, String id) =>
        tester.getRect(find.descendant(of: key('hp-$id'), matching: find.byType(LinearProgressIndicator)));

    testWidgets('CELL-3: the bar shows the HP on display and a segment for the HP lost since the round started', (
      tester,
    ) async {
      await open(tester, roundStartHp: {'m1': 20});
      final bar = barOf(tester, 'm1');
      final lost = tester.getRect(key('hp-lost-m1'));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.descendant(of: key('hp-m1'), matching: find.byType(LinearProgressIndicator)),
            )
            .value,
        0.75,
      );
      expect(lost.left, closeTo(bar.left + bar.width * 0.75, 0.5));
      expect(lost.width, closeTo(bar.width * 0.25, 0.5));
      expect(lost.center.dy, closeTo(bar.center.dy, 0.5));
    });

    testWidgets('CELL-3: no segment when no HP was lost, or when the character was healed', (tester) async {
      await open(tester, players: board(m1Hp: 20), roundStartHp: {'m0': 20, 'm1': 12});
      expect(key('hp-lost-m0'), findsNothing);
      expect(key('hp-lost-m1'), findsNothing);
      expect(key('hp-lost-m2'), findsNothing); // no start HP given
    });

    testWidgets('CELL-3: the lost segment stops at the max HP', (tester) async {
      await open(tester, players: board(m1Hp: 10), roundStartHp: {'m1': 30});
      final bar = barOf(tester, 'm1');
      final lost = tester.getRect(key('hp-lost-m1'));
      expect(lost.left, closeTo(bar.left + bar.width * 0.5, 0.5));
      expect(lost.right, closeTo(bar.right, 0.5));
    });

    testWidgets('CELL-3: with no start HP there is no segment', (tester) async {
      await open(tester);
      expect(find.byWidgetPredicate((w) => '${w.key}'.contains('hp-lost-')), findsNothing);
    });
  });

  group('a step of a real timeline', () {
    // a (mine, slot 0) kills b (theirs, slot 0, 5 HP) in front; c (theirs, slot 1) is stunned.
    final a = character('a', side: 0, slot: 0, face: hit);
    final b = character('b', side: 1, slot: 0, hp: 5);
    final c = character('c', side: 1, slot: 1, states: const {'STUN': 1});
    final timeline = RoundTimeline.build(
      [a, b, c],
      [
        ResolveStep(
          'a',
          false,
          const [
            ResolvedEffect(['Damage'], [Cell(1, 0)]),
          ],
          [ResolveChange('b', b.copyWith(hp: 0))],
          unplayed: false,
        ),
        const ResolveStep('c', true, [], [], unplayed: false),
      ],
    );
    final startHp = {for (final ch in timeline.boardAt(0)) ch.id: ch.hp};

    Future<void> openNotch(WidgetTester tester, int notch) => open(
      tester,
      players: playersFromBoard(timeline.boardAt(notch)),
      outcome: stepOutcome(timeline, notch, resolving: true),
      roundStartHp: startHp,
    );

    testWidgets('STEP-1, STEP-2, CELL-6: the killed target has left its cell, which keeps the colour and the label', (
      tester,
    ) async {
      await openNotch(tester, 1);
      expect(key('actor-ring-a'), findsOneWidget);
      expect(find.text('Name b'), findsNothing);
      expect(tester.widget<DashedBox>(key('target-1-0')).color, effectColors['Damage']);
      expect(tester.widget<Text>(key('label-1-0')).data, '−5');
    });

    testWidgets('STEP-4: the stunned character\'s notch', (tester) async {
      await openNotch(tester, 2);
      expect(key('actor-ring-c'), findsOneWidget);
      expect(key('skipped-c'), findsOneWidget);
    });
  });

  group('a small phone', () {
    const small = Size(640, 360);
    const long = 'Bouclier +4 · déplacé · Puissance +2 · Étourdi · 1 t.';

    testWidgets('STEP-2: long labels on both sides of every row do not overflow at 640×360', (tester) async {
      await open(
        tester,
        size: small,
        dpr: 1,
        roundStartHp: {'m1': 20},
        outcome: StepOutcome('m0', false, [
          for (var slot = 0; slot < 5; slot++) ...[
            CellOutcome(Cell(0, slot), null, 'Shield', long),
            CellOutcome(Cell(1, slot), null, 'Damage', long),
          ],
        ], ''),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('STEP-4: a skipped action does not overflow at 640×360', (tester) async {
      await open(tester, size: small, dpr: 1, outcome: const StepOutcome('t3', true, [], ''));
      expect(tester.takeException(), isNull);
    });
  });
}
