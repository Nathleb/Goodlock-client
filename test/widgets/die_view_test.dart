import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/widgets/die_face_tile.dart';
import 'package:goodlock_app/widgets/die_view.dart';

/// Six different faces, some with two effects and several parts, to fill the view.
List<DieFace> sixFaces() => [
      DieFace('Coup de taille dans les rangs ennemis', 1, [
        FaceEffect([TargetGroup('ENEMY', 'RELATIVE', [0, 1])], [FacePart('Damage', 4), FacePart('ApplyState', 0, state: 'POISON', duration: 2)]),
        FaceEffect([TargetGroup('ALLY', 'ABSOLUTE', [0])], [FacePart('Heal', 2)]),
      ]),
      DieFace('Soin', 0, [
        FaceEffect([TargetGroup('ALLY', 'RELATIVE', [-1, 1])], [FacePart('Heal', 3)]),
      ]),
      DieFace('Garde', 2, [
        FaceEffect([TargetGroup('ALLY', 'RELATIVE', [0])], [FacePart('Shield', 5)]),
      ]),
      DieFace('Échange', -1, [
        FaceEffect([TargetGroup('ENEMY', 'ABSOLUTE', [0, 4])], [FacePart('Swap', 0)]),
      ]),
      DieFace('Malédiction', 0, [
        FaceEffect([TargetGroup('ENEMY', 'ABSOLUTE', [2])], [FacePart('ApplyStat', -2, stat: 'POWER', duration: 2), FacePart('FixedDamage', 1)]),
      ]),
      const DieFace('Repos', 0, []),
    ];

CharacterView knight({List<DieFace>? die, DieFace? face}) {
  final faces = die ?? sixFaces();
  return CharacterView(
    id: 'k1',
    catalogId: 'knight',
    name: 'Chevalier',
    hp: 20,
    maxHp: 20,
    shield: 0,
    baseSpeed: 7,
    baseDie: faces,
    // A copy, not the same instance: the face is found by value.
    face: face ?? sixFaces()[2],
    faceIndex: 2,
    isFaceLocked: false,
    position: const Cell(0, 0),
  );
}

Finder faceCard(int i) => find.byKey(ValueKey('die-face-$i'));
final current = find.byKey(const ValueKey('die-face-current'));

void main() {
  /// The smallest landscape phone the app targets: 640×360 dp.
  Future<void> open(WidgetTester tester, CharacterView character) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(onPressed: () => showDieView(context, character), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('DIE-1: shows the name and base speed of the character', (tester) async {
    await open(tester, knight());
    expect(find.text('Chevalier'), findsOneWidget);
    expect(find.text('vitesse 7'), findsOneWidget);
  });

  testWidgets('DIE-1: shows the six faces side by side, in order', (tester) async {
    await open(tester, knight());
    for (var i = 0; i < 6; i++) {
      expect(faceCard(i), findsOneWidget);
    }
    for (var i = 1; i < 6; i++) {
      expect(tester.getTopLeft(faceCard(i)).dy, closeTo(tester.getTopLeft(faceCard(0)).dy, 0.5));
      expect(tester.getTopLeft(faceCard(i)).dx, greaterThan(tester.getTopRight(faceCard(i - 1)).dx - 0.5));
    }
  });

  testWidgets('DIE-1: each face shows its effect, value, targeting and priority bracket', (tester) async {
    await open(tester, knight());
    Finder inFace(int i, Finder f) => find.descendant(of: faceCard(i), matching: f);
    expect(inFace(0, find.text('Coup de taille dans les rangs ennemis')), findsOneWidget);
    expect(inFace(0, find.text('priorité +1')), findsOneWidget);
    expect(inFace(3, find.text('priorité -1')), findsOneWidget);
    // One chip per part of each effect, with its value, and one targeting grid per effect.
    expect(inFace(0, find.text('Damage 4')), findsOneWidget);
    expect(inFace(0, find.text('POISON · 2 t.')), findsOneWidget);
    expect(inFace(0, find.text('Heal 2')), findsOneWidget);
    expect(inFace(0, find.byType(TargetGrid)), findsNWidgets(2));
    expect(inFace(4, find.text('POWER -2 · 2 t.')), findsOneWidget);
    expect(inFace(4, find.text('FixedDamage 1')), findsOneWidget);
    expect(inFace(5, find.byType(TargetGrid)), findsNothing);
  });

  testWidgets('DIE-1: the current face is ringed, and only it', (tester) async {
    await open(tester, knight());
    expect(current, findsOneWidget);
    expect(find.descendant(of: current, matching: faceCard(2)), findsOneWidget);
    BoxDecoration? deco(int i) => tester.widget<Container>(faceCard(i)).decoration as BoxDecoration?;
    for (final i in [0, 1, 3, 4, 5]) {
      expect(deco(2), isNot(deco(i)));
      expect(deco(i), deco(0));
    }
  });

  testWidgets('DIE-1: when several faces equal the current one, the first is ringed', (tester) async {
    final faces = sixFaces();
    faces[4] = sixFaces()[1];
    await open(tester, knight(die: faces, face: sixFaces()[1]));
    expect(current, findsOneWidget);
    expect(find.descendant(of: current, matching: faceCard(1)), findsOneWidget);
  });

  testWidgets('DIE-1: a current face that is not on the die rings nothing', (tester) async {
    await open(tester, knight(face: const DieFace('ailleurs', 0, [])));
    expect(current, findsNothing);
  });

  testWidgets('DIE-1: a line recalls that the priority bracket comes before speed', (tester) async {
    await open(tester, knight());
    expect(find.text('La priorité passe avant la vitesse dans l\'ordre de résolution.'), findsOneWidget);
  });

  testWidgets('DIE-1: fits a 640×360 dp landscape screen without overflow', (tester) async {
    await open(tester, knight());
    expect(tester.takeException(), isNull);
    final screen = tester.getRect(find.byType(Scaffold));
    for (var i = 0; i < 6; i++) {
      final card = tester.getRect(faceCard(i));
      expect(card.left, greaterThanOrEqualTo(screen.left));
      expect(card.right, lessThanOrEqualTo(screen.right));
    }
    // The close button stays reachable.
    final close = tester.getRect(find.byKey(const ValueKey('die-view-close')));
    expect(screen.contains(close.center), isTrue);
  });

  testWidgets('DIE-2: tapping Close closes the die view', (tester) async {
    await open(tester, knight());
    await tester.tap(find.byKey(const ValueKey('die-view-close')));
    await tester.pumpAndSettle();
    expect(faceCard(0), findsNothing);
  });

  testWidgets('DIE-2: tapping the darkened background closes the die view', (tester) async {
    await open(tester, knight());
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(faceCard(0), findsNothing);
  });
}
