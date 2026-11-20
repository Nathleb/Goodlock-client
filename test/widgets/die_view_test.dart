import 'dart:convert';
import 'dart:io';

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

CharacterView knight({List<DieFace>? die, int faceIndex = 2, String name = 'Chevalier'}) {
  final faces = die ?? sixFaces();
  return CharacterView(
    id: 'k1',
    catalogId: 'knight',
    name: name,
    hp: 20,
    maxHp: 20,
    shield: 0,
    baseSpeed: 7,
    baseDie: faces,
    face: faceIndex >= 0 && faceIndex < faces.length ? faces[faceIndex] : const DieFace('ailleurs', 0, []),
    faceIndex: faceIndex,
    isFaceLocked: false,
    position: const Cell(0, 0),
  );
}

/// One character of each name in the recorded round starts: the whole catalog, with its real faces.
List<CharacterView> recordedCharacters() {
  final starts = jsonDecode(File('test/fixtures/round_start.json').readAsStringSync()) as List;
  final byName = <String, CharacterView>{};
  for (final j in starts) {
    for (final p in GameStateView.fromJson(j as Json).players) {
      for (final c in [...p.team, ...p.fallen]) {
        byName.putIfAbsent(c.name, () => c);
      }
    }
  }
  return byName.values.toList();
}

Finder faceCard(int i) => find.byKey(ValueKey('die-face-$i'));
final current = find.byKey(const ValueKey('die-face-current'));
final close = find.byKey(const ValueKey('die-view-close'));
Finder inFace(int i, Finder f) => find.descendant(of: faceCard(i), matching: f);
Finder inView(Finder f) => find.descendant(of: find.byType(DieView), matching: f);

void main() {
  /// By default the smallest landscape phone the app targets: 640×360 dp.
  Future<void> open(WidgetTester tester, CharacterView character, {Size screen = const Size(640, 360)}) async {
    tester.view.physicalSize = screen * 2;
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

  /// The vertical scroll of the faces.
  ScrollPosition faceScroll(WidgetTester tester) => tester.state<ScrollableState>(inView(find.byType(Scrollable))).position;
  final scrollbar = inView(find.byType(Scrollbar));
  Rect viewportOf(WidgetTester tester) => tester.getRect(inView(find.byType(SingleChildScrollView)));

  /// A scrollbar thumb: a narrow upright bar, shorter than the viewport, painted right of the last face (in the
  /// scrollbar's own coordinates); not a card, a grid cell or the track.
  PaintPattern thumbPainted(WidgetTester tester) {
    final origin = tester.getTopLeft(scrollbar);
    final lastCardRight = tester.getRect(faceCard(5)).right - origin.dx;
    final viewportHeight = viewportOf(tester).height;
    return paints
      ..something((method, args) {
        final shape = args.isEmpty ? null : args.first;
        final r = method == #drawRect && shape is Rect
            ? shape
            : method == #drawRRect && shape is RRect
                ? shape.outerRect
                : null;
        return r != null && r.left >= lastCardRight - 0.5 && r.height > 2 * r.width && r.height < viewportHeight - 0.5;
      });
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
    expect(inFace(0, find.text('Coup de taille dans les rangs ennemis')), findsOneWidget);
    final priorities = ['priorité +1', 'priorité +0', 'priorité +2', 'priorité -1', 'priorité +0', 'priorité +0'];
    for (var i = 0; i < 6; i++) {
      expect(inFace(i, find.text('${i + 1}')), findsOneWidget, reason: 'the number of face $i');
      expect(inFace(i, find.text(priorities[i])), findsOneWidget, reason: 'the priority of face $i');
    }
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

  testWidgets('DIE-1: only the card at faceIndex is ringed, even if an earlier face is identical', (tester) async {
    final faces = sixFaces();
    faces[4] = sixFaces()[1];
    await open(tester, knight(die: faces, faceIndex: 4));
    expect(current, findsOneWidget);
    expect(find.descendant(of: current, matching: faceCard(4)), findsOneWidget);
    expect(find.descendant(of: current, matching: faceCard(1)), findsNothing);
  });

  for (final outside in [-1, 6]) {
    testWidgets('DIE-1: a faceIndex outside the die ($outside) rings nothing', (tester) async {
      await open(tester, knight(faceIndex: outside));
      expect(tester.takeException(), isNull);
      expect(faceCard(5), findsOneWidget);
      expect(current, findsNothing);
    });
  }

  testWidgets('DIE-1: a line under the faces recalls that the priority bracket comes before speed', (tester) async {
    await open(tester, knight());
    final reminder = inView(find.text('La priorité passe avant la vitesse dans l\'ordre de résolution.'));
    expect(reminder, findsOneWidget);
    final line = tester.getRect(reminder);
    expect(line.top, greaterThanOrEqualTo(viewportOf(tester).bottom));
    expect(line.bottom, lessThanOrEqualTo(360));
  });

  testWidgets('DIE-1: a long description is cut after four lines and shown whole on a long press', (tester) async {
    final long = List.filled(30, 'mot').join(' ');
    final faces = sixFaces();
    faces[0] = DieFace(long, 1, const []);
    await open(tester, knight(die: faces));
    final oneLine = tester.getSize(inFace(1, find.text('Soin'))).height;
    expect(tester.getSize(inFace(0, find.text(long))).height, lessThanOrEqualTo(4 * oneLine + 0.5));
    expect(find.text(long), findsOneWidget);

    await tester.longPress(faceCard(0));
    await tester.pumpAndSettle();
    expect(find.text(long), findsNWidgets(2));
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
    expect(screen.contains(tester.getRect(close).center), isTrue);
  });

  testWidgets('DIE-1: faces taller than the screen scroll, and the scrollbar shows it untouched', (tester) async {
    final tall = DieFace('Grand', 0, [
      for (var e = 0; e < 5; e++) const FaceEffect([TargetGroup('ENEMY', 'RELATIVE', [0])], [FacePart('Damage', 1)]),
    ]);
    await open(tester, knight(die: [tall, ...sixFaces().skip(1)]));
    expect(tester.takeException(), isNull);
    expect(faceScroll(tester).maxScrollExtent, greaterThan(0));
    expect(scrollbar, thumbPainted(tester));
    expect(tester.getRect(close).bottom, lessThanOrEqualTo(360));
  });

  testWidgets('DIE-1: six faces of two effects, the most a catalog face has, fit a 640×360 screen', (tester) async {
    const two = DieFace('Coup', 0, [
      FaceEffect([TargetGroup('ENEMY', 'RELATIVE', [0])], [FacePart('Damage', 8)]),
      FaceEffect([TargetGroup('ALLY', 'RELATIVE', [0])], [FacePart('Heal', 8)]),
    ]);
    await open(tester, knight(die: List.filled(6, two)));
    expect(tester.takeException(), isNull);
    expect(faceScroll(tester).maxScrollExtent, 0);
    expect(scrollbar, isNot(thumbPainted(tester)));
  });

  testWidgets('DIE-1: the die view leaves only a thin margin around it', (tester) async {
    final tall = DieFace('Grand', 0, [
      for (var e = 0; e < 5; e++) const FaceEffect([TargetGroup('ENEMY', 'RELATIVE', [0])], [FacePart('Damage', 1)]),
    ]);
    await open(tester, knight(die: [tall, ...sixFaces().skip(1)]));
    final dialog = tester.getRect(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first);
    expect(dialog.left, lessThanOrEqualTo(12));
    expect(dialog.right, greaterThanOrEqualTo(640 - 12));
    expect(dialog.top, lessThanOrEqualTo(8));
    expect(dialog.bottom, greaterThanOrEqualTo(360 - 8));
  });

  testWidgets('DIE-1: the faces have one scrollbar on every platform', (tester) async {
    await open(tester, knight());
    expect(scrollbar, findsOneWidget);
  }, variant: TargetPlatformVariant.all());

  for (final screen in const [Size(800, 360), Size(640, 360)]) {
    final size = '${screen.width.toInt()}×${screen.height.toInt()}';
    testWidgets('DIE-1: every recorded character fits a $size screen, with Close on it', (tester) async {
      final characters = recordedCharacters();
      expect(characters.map((c) => c.name), containsAll(['Ysolde', 'Garran', 'Vespera']));
      expect(characters.expand((c) => c.baseDie).any((f) => f.effects.length == 2), isTrue);
      final fitted = <String>[];
      for (final c in characters) {
        await open(tester, c, screen: screen);
        expect(tester.takeException(), isNull, reason: c.name);
        expect((Offset.zero & screen).contains(tester.getRect(close).center), isTrue, reason: c.name);
        final viewport = viewportOf(tester);
        expect(viewport.bottom, lessThanOrEqualTo(screen.height), reason: c.name);
        if (faceScroll(tester).maxScrollExtent == 0) {
          fitted.add(c.name);
          for (var i = 0; i < 6; i++) {
            expect(tester.getRect(faceCard(i)).height, lessThanOrEqualTo(viewport.height + 0.5), reason: '${c.name} face $i');
          }
          expect(scrollbar, isNot(thumbPainted(tester)), reason: c.name);
        } else {
          expect(scrollbar, thumbPainted(tester), reason: '${c.name}: the faces scroll, the scrollbar shows it');
        }
        await tester.tap(close);
        await tester.pumpAndSettle();
      }
      // The test font is wider than the real one, so some dice scroll here that fit on a phone; the faces with one
      // effect still fit, which keeps both branches above in use.
      expect(fitted, isNotEmpty);
    });
  }

  testWidgets('DIE-2: Close sits at the right edge of the header, even beside a long name', (tester) async {
    for (final name in ['Chevalier', List.filled(20, 'Chevalier').join(' ')]) {
      await open(tester, knight(name: name));
      expect(tester.takeException(), isNull, reason: name);
      final button = tester.getRect(close);
      expect(button.right, greaterThanOrEqualTo(tester.getRect(faceCard(5)).right), reason: name);
      expect(button.right, lessThanOrEqualTo(640), reason: name);
      await tester.tap(close);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the die view, its faces and Close are labelled for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, knight());
    expect(find.bySemanticsLabel('Dé de Chevalier'), findsOneWidget);
    // It names the dialog's route, as the title of a dialog does.
    expect(tester.getSemantics(find.bySemanticsLabel('Dé de Chevalier')), isSemantics(namesRoute: true));
    expect(find.bySemanticsLabel('Face 1: Coup de taille dans les rangs ennemis, priorité +1'), findsOneWidget);
    expect(find.bySemanticsLabel('Face 3: Garde, priorité +2, face courante'), findsOneWidget);
    expect(find.bySemanticsLabel('Face 4: Échange, priorité -1'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('face courante')), findsOneWidget);
    expect(tester.getSemantics(close), isSemantics(label: 'Fermer', isButton: true, hasTapAction: true));
    semantics.dispose();
  });

  testWidgets('DIE-2: tapping Close closes the die view', (tester) async {
    await open(tester, knight());
    await tester.tap(close);
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
