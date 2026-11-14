import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/widgets/cell_tile.dart';
import 'package:goodlock_app/widgets/match_board.dart';

import '../helpers/builders.dart';

void main() {
  const damage = DieFace('hit', 1, [FaceEffect('Damage', 5, [])]);

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
}
