import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/widgets/match_result.dart';

void main() {
  test('END-3: says why the match was won or lost, from the viewer\'s side', () {
    expect(endReasonText(EndReason.elimination, won: true), 'Deux personnages adverses sont morts.');
    expect(endReasonText(EndReason.elimination, won: false), 'Deux de tes personnages sont morts.');
    expect(endReasonText(EndReason.clock, won: true), "Le temps de l'adversaire est écoulé.");
    expect(endReasonText(EndReason.clock, won: false), 'Ton temps est écoulé.');
    expect(endReasonText(EndReason.reconnection, won: true), "L'adversaire ne s'est pas reconnecté à temps.");
    expect(endReasonText(EndReason.reconnection, won: false), "Tu ne t'es pas reconnecté à temps.");
    expect(endReasonText(EndReason.concede, won: true), "L'adversaire a abandonné.");
    expect(endReasonText(EndReason.concede, won: false), 'Tu as abandonné.');
    expect(endReasonText(EndReason.unknown, won: true), isEmpty);
  });

  test('END-3: says why the match is a draw: both clocks or both reconnection times ran out at once', () {
    expect(drawReasonText(EndReason.clock), "Ton temps et celui de l'adversaire sont écoulés en même temps.");
    expect(drawReasonText(EndReason.reconnection), "Ni toi ni l'adversaire ne vous êtes reconnectés à temps.");
    expect(drawReasonText(EndReason.elimination), isEmpty);
    expect(drawReasonText(EndReason.concede), isEmpty);
    expect(drawReasonText(EndReason.unknown), isEmpty);
  });

  testWidgets('FLOW-6, END-3: shows the draw and why, for either seat', (tester) async {
    for (final seat in [0, 1]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MatchResult(over: const GameOver.draw(EndReason.clock), viewerIndex: seat, onLeave: () {}),
        ),
      ));

      expect(find.text('Égalité'), findsOneWidget);
      expect(find.text('Victoire'), findsNothing);
      expect(find.text('Défaite'), findsNothing);
      expect(find.text("Ton temps et celui de l'adversaire sont écoulés en même temps."), findsOneWidget);
    }
  });

  testWidgets('FLOW-6: shows the victory and why, from the winner\'s side', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MatchResult(over: const GameOver(0, EndReason.reconnection), viewerIndex: 0, onLeave: () {}),
      ),
    ));

    expect(find.text('Victoire'), findsOneWidget);
    expect(find.text("L'adversaire ne s'est pas reconnecté à temps."), findsOneWidget);
  });

  testWidgets('FLOW-6: shows the winner and why, and leads back out of the match (ROOM-6)', (tester) async {
    var left = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MatchResult(over: const GameOver(1, EndReason.clock), viewerIndex: 0, onLeave: () => left = true),
      ),
    ));

    expect(find.text('Défaite'), findsOneWidget);
    expect(find.text('Ton temps est écoulé.'), findsOneWidget);

    await tester.tap(find.text('Retour'));
    expect(left, isTrue);
  });
}
