import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/screens/deck_choice_dialog.dart';

void main() {
  const first = Deck('d1', 'Rouge', ['a', 'b', 'c', 'd', 'e', 'f']);
  const second = Deck('d2', 'Bleu', ['a', 'b', 'c', 'd', 'e', 'f']);

  Future<Deck?> open(WidgetTester tester, List<Deck> decks) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    Deck? chosen;
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            chosen = await chooseDeck(context, decks);
            done = true;
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    if (decks.length > 1) return null;
    await tester.pump();
    expect(done, isTrue);
    return chosen;
  }

  testWidgets('with a single deck it is chosen without asking', (tester) async {
    expect(await open(tester, [first]), first);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('with several decks it asks, and answers the deck tapped', (tester) async {
    await open(tester, [first, second]);
    expect(find.text('Rouge'), findsOneWidget);
    expect(find.text('Bleu'), findsOneWidget);
    await tester.tap(find.text('Bleu'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('with no deck it answers nothing', (tester) async {
    expect(await open(tester, []), isNull);
  });
}
