import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/match_clocks.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/widgets/match_clocks_bar.dart';

void main() {
  testWidgets('shows both clocks, counts my own down, keeps the opponent static and shows their reconnection time',
      (tester) async {
    var now = DateTime(2026, 11, 9, 12);
    final clocks = MatchClocks(0)
      ..onState(
        const GameStateView(
          phase: Phase.keep,
          currentRound: 0,
          initiativePlayerIndex: 0,
          rollsLeft: 2,
          clocks: [
            PlayerClock(remainingMs: 65000, reconnectionMs: 180000, running: true, connected: true),
            PlayerClock(remainingMs: 300000, reconnectionMs: 120000, running: false, connected: false),
          ],
          players: [PlayerView(0, []), PlayerView(1, [])],
        ),
        now,
      );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MatchClocksBar(clocks: clocks, now: () => now))));

    expect(find.text('Moi 1:05'), findsOneWidget);
    expect(find.text('Adversaire 5:00'), findsOneWidget);
    expect(find.text('Reconnexion 2:00'), findsOneWidget);

    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Moi 0:55'), findsOneWidget);
    expect(find.text('Adversaire 5:00'), findsOneWidget);
    expect(find.text('Reconnexion 1:50'), findsOneWidget);

    clocks.onPresence(const PresenceChanged(1, true, 110000), now);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Reconnexion'), findsNothing);
  });
}
