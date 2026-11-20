import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/widgets/cell_tile.dart';
import 'package:goodlock_app/widgets/match_board.dart';

import '../helpers/builders.dart';

void main() {
  const damage = DieFace('hit', 1, [FaceEffect([], [FacePart('Damage', 5)])]);

  List<CharacterView> mine() => [
    character('m0', side: 0, slot: 0, face: damage),
    character('m1', side: 0, slot: 1, hp: 15),
    character('m2', side: 0, slot: 2, shield: 4),
    character('m3', side: 0, slot: 3),
  ];
  List<CharacterView> theirs() => [
    character('t0', side: 1, slot: 0, locked: true, face: damage),
    character('t1', side: 1, slot: 1),
    character('t2', side: 1, slot: 2),
    character('t3', side: 1, slot: 3),
  ];

  Future<void> open(WidgetTester tester, {Set<String> locks = const {}, void Function(String)? onFaceTap}) async {
    // A common 20:9 phone in landscape: 2400×1080 px at 2.625 dpr ≈ 914×411 dp.
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchBoard(
            players: [PlayerView(0, mine()), PlayerView(1, theirs())],
            me: 0,
            locks: locks,
            onFaceTap: onFaceTap,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('LAYOUT-3: my side is on the left, the opponent\'s on the right, cells 0 to 4 from top to bottom', (
    tester,
  ) async {
    await open(tester);

    expect(tester.getCenter(find.text('Name m0')).dx, lessThan(tester.getCenter(find.text('Name t0')).dx));
    expect(tester.getCenter(find.text('Name m0')).dy, lessThan(tester.getCenter(find.text('Name m1')).dy));
    expect(tester.getCenter(find.text('Name m1')).dy, lessThan(tester.getCenter(find.text('Name m3')).dy));
    // Each cell is level with the cell it faces.
    double cellDy(String name) =>
        tester.getCenter(find.ancestor(of: find.text(name), matching: find.byType(CellTile))).dy;
    expect(cellDy('Name m2'), closeTo(cellDy('Name t2'), 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('LAYOUT-3: seated second, I still see my side on the left and the opponent\'s on the right', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MatchBoard(players: [PlayerView(0, mine()), PlayerView(1, theirs())], me: 1)),
      ),
    );
    await tester.pump();

    // players[1] (t*) is mine: on the left, its faces on the lane side; players[0] (m*) on the right.
    expect(tester.getCenter(find.text('Name t0')).dx, lessThan(tester.getCenter(find.text('Name m0')).dx));
    expect(
      tester.getCenter(find.text('Name t0')).dx,
      lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio / 2),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('face-t0'))).dx,
      greaterThan(tester.getCenter(find.text('Name t0')).dx),
    );
    expect(tester.getCenter(find.text('Name t1')).dy, lessThan(tester.getCenter(find.text('Name t3')).dy));
  });

  testWidgets('LAYOUT-4: an empty cell is drawn at its place, on both sides', (tester) async {
    await open(tester);
    expect(find.text('vide'), findsNWidgets(2));
  });

  testWidgets('CELL-1: the face is on the lane side, the portrait on the edge of the screen', (tester) async {
    await open(tester);
    expect(
      tester.getCenter(find.byKey(const ValueKey('face-m0'))).dx,
      greaterThan(tester.getCenter(find.text('Name m0')).dx),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('face-t0'))).dx,
      lessThan(tester.getCenter(find.text('Name t0')).dx),
    );
  });

  testWidgets('CELL-2: shows the HP as text and a bar, and the status chips', (tester) async {
    await open(tester);
    expect(find.text('15/20'), findsOneWidget);
    expect(find.text('Bouclier 4'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.descendant(of: find.byKey(const ValueKey('hp-m1')), matching: find.byType(LinearProgressIndicator)),
    );
    expect(bar.value, 0.75);
  });

  testWidgets('CELL-4: a kept die of mine has a lock mark, and the opponent\'s never has one', (tester) async {
    await open(tester, locks: {'m1'});
    expect(find.byKey(const ValueKey('lock-m1')), findsOneWidget);
    expect(find.byKey(const ValueKey('lock-m0')), findsNothing);
    // t0's die was kept at the last Roll: still no lock mark on the opponent's side.
    expect(find.byKey(const ValueKey('lock-t0')), findsNothing);
  });

  testWidgets('CELL-4: a blank face reads as blank, and a face with an effect shows its value', (tester) async {
    await open(tester);
    expect(find.descendant(of: find.byKey(const ValueKey('face-m1')), matching: find.text('·')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('face-m0')), matching: find.text('5')), findsOneWidget);
  });

  testWidgets('CELL-5: tapping one of my faces reports it, tapping the opponent\'s does nothing', (tester) async {
    final tapped = <String>[];
    await open(tester, onFaceTap: tapped.add);
    await tester.tap(find.byKey(const ValueKey('face-m2')));
    await tester.tap(find.byKey(const ValueKey('face-t2')));
    expect(tapped, ['m2']);
  });

  testWidgets('CELL-5: with no handler my faces are not tappable', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('face-m2')));
    expect(tester.takeException(), isNull);
  });

  group('portrait', () {
    Future<void> openWith(
      WidgetTester tester, {
      void Function(CharacterView)? onPortraitTap,
      void Function(String)? onFaceTap,
    }) async {
      tester.view.physicalSize = const Size(2400, 1080);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchBoard(
              players: [PlayerView(0, mine()), PlayerView(1, theirs())],
              me: 0,
              onFaceTap: onFaceTap,
              onPortraitTap: onPortraitTap,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('CELL-5: tapping a portrait, mine or the opponent\'s, reports its character', (tester) async {
      final tapped = <CharacterView>[];
      await openWith(tester, onPortraitTap: tapped.add);
      await tester.tap(find.byKey(const ValueKey('portrait-m2')));
      await tester.tap(find.byKey(const ValueKey('portrait-t1')));
      expect(tapped.map((c) => c.id), ['m2', 't1']);
      expect(tapped.first.name, 'Name m2');
    });

    testWidgets('CELL-5: the portrait covers the name, the speed and the HP', (tester) async {
      await openWith(tester);
      for (final text in ['Name m0', 'vitesse 3', '20/20']) {
        expect(
          find.descendant(of: find.byKey(const ValueKey('portrait-m0')), matching: find.text(text)),
          findsOneWidget,
        );
      }
    });

    testWidgets('CELL-5: tapping a portrait does not keep its face, tapping a face opens no die view', (tester) async {
      final portraits = <String>[];
      final faces = <String>[];
      await openWith(tester, onPortraitTap: (c) => portraits.add(c.id), onFaceTap: faces.add);
      await tester.tap(find.byKey(const ValueKey('portrait-m1')));
      await tester.tap(find.byKey(const ValueKey('face-m3')));
      expect(portraits, ['m1']);
      expect(faces, ['m3']);
    });

    testWidgets('CELL-5: with no handler portraits are not tappable', (tester) async {
      await openWith(tester);
      for (final id in ['m2', 't2']) {
        expect(tester.widget<InkWell>(find.byKey(ValueKey('portrait-$id'))).onTap, isNull, reason: id);
      }
      await tester.tap(find.byKey(const ValueKey('portrait-m2')));
      expect(tester.takeException(), isNull);
    });
  });
}
