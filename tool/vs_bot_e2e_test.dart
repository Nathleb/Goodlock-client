// Plays a whole match against a bot on a running backend, through HumanMatchController, with no screen:
//   flutter test tool/vs_bot_e2e_test.dart --dart-define=E2E_SERVER=http://localhost:3000
// Without E2E_SERVER the test is skipped. It registers a fresh account on that server.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/app/session.dart';
import 'package:goodlock_app/game/human_match_controller.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/net/vs_bot.dart';

const _server = String.fromEnvironment('E2E_SERVER');

void main() {
  test(
    'a human plays a full match against a bot',
    () async {
      final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      final session = AppSession(_server);
      await session.signIn('e2e_$stamp', 'password123', register: true);
      final deck = (await session.api!.decks()).first;

      final match = await seatVsBot(session, deck.id);
      final c = HumanMatchController(match.socket, me: match.me);
      final done = Completer<void>();
      final seen = <Phase>{};
      var rounds = 0;
      var placed = false;
      String? lastKeep;

      void act() {
        final s = c.state;
        if (s == null) return;
        seen.add(s.phase);
        while (c.nextRound() != null) {
          rounds++;
          c.roundPlayed();
        }
        if (c.over != null && !done.isCompleted) done.complete();
        if (c.over != null || c.isResolving || c.ready) return;
        switch (s.phase) {
          case Phase.selection:
            if (c.picks.isEmpty) {
              for (final ch in s.selection!.decks[c.me].take(4)) {
                c.togglePick(ch.id);
              }
              c.confirm();
            }
          case Phase.placement:
            if (!placed) {
              placed = true;
              c.tapCell(0);
              c.tapCell(4); // move a character to the empty cell, like a player would
              c.confirm();
            }
          case Phase.keep:
            final key = '${s.currentRound}/${s.rollsLeft}';
            if (key != lastKeep) {
              lastKeep = key;
              if (s.players[c.me].team.isNotEmpty) c.toggleLock(s.players[c.me].team.first.id);
              c.confirm();
            }
          default:
        }
      }

      c.addListener(act);
      try {
        await done.future.timeout(const Duration(seconds: 120));
        expect(c.error, isNull, reason: 'the server refused a command');
        expect(seen, containsAll([Phase.selection, Phase.placement, Phase.keep]));
        expect(rounds, greaterThan(0));
        expect(c.over, isNotNull);
        // ignore: avoid_print
        print('match over after $rounds rounds: winner ${c.over!.winner}, reason ${c.over!.reason}');
      } finally {
        c.dispose();
        match.dispose();
      }
    },
    skip: _server.isEmpty ? 'set --dart-define=E2E_SERVER' : false,
    timeout: const Timeout(Duration(seconds: 150)),
  );
}
