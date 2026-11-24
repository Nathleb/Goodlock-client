import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/widgets/cell_tile.dart';

import '../helpers/builders.dart';

Finder key(String k) => find.byKey(ValueKey(k));

void main() {
  Future<void> open(
    WidgetTester tester, {
    VoidCallback? onPortraitTap,
    VoidCallback? onFaceTap,
    bool locked = false,
    bool mine = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 60,
              child: CellTile(
                character: character('m0', side: 0, slot: 0),
                mine: mine,
                locked: locked,
                onPortraitTap: onPortraitTap,
                onFaceTap: onFaceTap,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The material the ink of [target] is drawn on.
  MaterialInkController inkOf(WidgetTester tester, String target) =>
      Material.of(tester.element(find.descendant(of: key(target), matching: find.byType(Padding)).first));

  for (final target in ['portrait-m0', 'face-m0']) {
    testWidgets('CELL-5: a tap on the ${target.split('-').first} shows, its ink drawn on the cell\'s own colour', (
      tester,
    ) async {
      for (final mine in [true, false]) {
        await open(tester, mine: mine, onPortraitTap: () {}, onFaceTap: () {});
        final ink = inkOf(tester, target);
        final cellColor = Theme.of(tester.element(find.byType(CellTile))).colorScheme.surfaceContainerHighest;
        // Above the cell's colour, not on the screen's material under it, where the cell would hide it.
        expect(ink.color, cellColor, reason: 'mine: $mine');
        expect(find.descendant(of: find.byType(CellTile), matching: find.byType(Material)), findsOneWidget);

        final gesture = await tester.startGesture(tester.getCenter(key(target)));
        await tester.pump(const Duration(milliseconds: 200));
        expect(ink, paints..rrect(), reason: 'mine: $mine');
        await gesture.up();
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('CELL-5: the portrait is a button that opens the die view of its character', (tester) async {
    await open(tester, onPortraitTap: () {});
    final node = tester.getSemantics(key('portrait-m0'));
    expect(node, isSemantics(isButton: true, hasTapAction: true));
    expect(node.label, startsWith('Voir le dé de Name m0'));
    // Still a button, not the progress bar of the HP.
    expect(node.role, isNot(SemanticsRole.progressBar));
  });

  testWidgets('CELL-5: my face, when it can be tapped, is a button that says whether the die is kept', (tester) async {
    await open(tester, onFaceTap: () {});
    expect(tester.getSemantics(key('face-m0')), isSemantics(isButton: true, hasTapAction: true));
    expect(tester.getSemantics(key('face-m0')).label, startsWith('Garder / relâcher le dé de Name m0 (relâché)'));

    await open(tester, onFaceTap: () {}, locked: true);
    expect(tester.getSemantics(key('face-m0')).label, startsWith('Garder / relâcher le dé de Name m0 (gardé)'));
  });

  testWidgets('CELL-5: with no handler, neither the portrait nor the face is announced as a button', (tester) async {
    await open(tester);
    for (final target in ['portrait-m0', 'face-m0']) {
      final node = tester.getSemantics(key(target));
      expect(node, isNot(isSemantics(isButton: true)), reason: target);
      expect(node, isNot(isSemantics(hasTapAction: true)), reason: target);
      expect(node.label, isNot(contains('dé de')), reason: target);
    }
  });
}
