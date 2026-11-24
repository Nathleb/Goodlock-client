import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/human_match_controller.dart';
import 'package:goodlock_app/game/playhead.dart';
import 'package:goodlock_app/game/round_replay.dart';
import 'package:goodlock_app/net/models.dart';

import '../helpers/builders.dart';
import '../helpers/fake_link.dart';
import '../helpers/rounds.dart';

const step = Duration(milliseconds: 10);
const dwell = Duration(seconds: 1);

void main() {
  late FakeLink link;
  late HumanMatchController controller;
  late Playhead playhead;
  late RoundReplay replay;
  late bool replayDisposed;

  /// Runs [body] with a replay of a fresh match; everything is disposed at the end.
  void withReplay(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      link = FakeLink();
      controller = HumanMatchController(link, me: 0, now: () => DateTime(2026));
      playhead = Playhead(stepDelay: step);
      replay = RoundReplay(controller, playhead, endDwell: dwell);
      replayDisposed = false;
      body(async);
      if (!replayDisposed) replay.dispose();
      playhead.dispose();
      controller.dispose();
    });
  }

  /// The round of [lateRound] comes, with what follows it ([then]), and starts playing.
  void resolve(FakeAsync async, RoundResolved round, {void Function()? then}) {
    link.serverResolved(round);
    then?.call();
    async.flushMicrotasks();
  }

  group('FLOW-6: where the replay of a decided match stops', () {
    test('END-2: an elimination in the last action halts the replay on it, and the round stays', () {
      withReplay((async) {
        resolve(async, lateRound(), then: () => link.serverOver(const GameOver(0, EndReason.elimination)));
        expect(playhead.stopNotch, 3);
        async.elapse(step * 20);
        expect(playhead.notch, 3);
        async.elapse(dwell);
        expect(controller.isResolving, isFalse);
        expect(replay.timeline, isNotNull, reason: 'the round the match ended in stays under the result');
      });
    });

    test('TL-6: a fast forward past the action that ended the match ends the round as well', () {
      withReplay((async) {
        resolve(async, lateRound(), then: () => link.serverOver(const GameOver(0, EndReason.elimination)));
        async.elapse(step);
        playhead.fastForward();
        async.elapse(dwell);
        expect(controller.isResolving, isFalse);
        expect(controller.showResult, isTrue);
      });
    });

    test('END-1: unplayed actions halt the replay on the last one played, before any game over', () {
      withReplay((async) {
        resolve(async, lateRound(unplayed: true));
        expect(playhead.notchCount, 6);
        async.elapse(step * 20);
        expect(playhead.notch, 3);
        expect(playhead.playing, isFalse);
        async.elapse(dwell);
        expect(controller.isResolving, isFalse);
        expect(replay.timeline, isNotNull, reason: 'the round the match ended in stays until the game over comes');
      });
    });

    for (final reason in [EndReason.concede, EndReason.clock, EndReason.reconnection]) {
      test('a loss by ${reason.name} during the replay does not halt it: it plays to the last notch', () {
        withReplay((async) {
          resolve(async, lateRound());
          async.elapse(step);
          link.serverOver(GameOver(1, reason));
          async.elapse(step * 20);
          expect(playhead.notch, playhead.notchCount - 1);
          async.elapse(dwell);
          expect(controller.showResult, isTrue);
          expect(replay.timeline, isNotNull);
        });
      });
    }

    test('a game over by elimination that comes once the playback started still halts on the last action', () {
      withReplay((async) {
        resolve(async, lateRound());
        async.elapse(step);
        link.serverOver(const GameOver(0, EndReason.elimination));
        async.elapse(step * 20);
        expect(playhead.notch, 3);
      });
    });

    test('a game over by elimination that comes as the playhead stands on the last action halts it there', () {
      withReplay((async) {
        resolve(async, lateRound());
        async.elapse(step * 3);
        expect(playhead.playing, isTrue);
        link.serverOver(const GameOver(0, EndReason.elimination));
        async.elapse(step * 20);
        expect(playhead.notch, 3);
      });
    });

    test('a game over that comes once the playhead is past the last action is ignored', () {
      withReplay((async) {
        resolve(async, lateRound());
        async.elapse(step * 4);
        expect(playhead.notch, 4);
        link.serverOver(const GameOver(0, EndReason.elimination));
        async.elapse(dwell);
        expect(controller.isResolving, isFalse);
        expect(playhead.notch, 4);
      });
    });

    test('STATE-7: an elimination at the next Upkeep (no player with 2 dead on the board) does not halt early', () {
      withReplay((async) {
        resolve(async, lateRound(kills: false), then: () => link.serverOver(const GameOver(0, EndReason.elimination)));
        async.elapse(step * 20);
        expect(playhead.notch, playhead.notchCount - 1);
      });
    });

    test('END-2: deaths count per player: one dead on each side is no elimination', () {
      withReplay((async) {
        // m1 is the only one to fall: player 0 has one dead, player 1 still one (t3, earlier).
        final round = lateRound(kills: false);
        final log = [
          ...round.resolveLog.take(1),
          ResolveStep('t1', false, const [], [ResolveChange('m1', round.startOfResolve.players[0].team[1].copyWith(hp: 0))],
              unplayed: false),
          ...round.resolveLog.skip(2),
        ];
        resolve(async, RoundResolved(round.gameState, log, round.startOfResolve),
            then: () => link.serverOver(const GameOver(0, EndReason.elimination)));
        async.elapse(step * 20);
        expect(playhead.notch, playhead.notchCount - 1);
      });
    });
  });

  group('KEEP-3: skipping to the next Keep', () {
    test('is offered once the next Keep has come during the replay, and not when the match is over', () {
      withReplay((async) {
        resolve(async, lateRound(kills: false));
        expect(replay.canSkipToKeep, isFalse);
        link.server(keepAfterLateRound());
        expect(replay.canSkipToKeep, isTrue);
        link.serverOver(const GameOver(1, EndReason.concede));
        expect(replay.canSkipToKeep, isFalse);
      });
    });

    test('a Keep of the round being replayed is not the next one', () {
      withReplay((async) {
        resolve(async, lateRound(kills: false));
        link.server(keepAfterLateRound(round: 4));
        expect(replay.canSkipToKeep, isFalse);
      });
    });

    test('a state of the next round that is not its Keep has nothing to skip to', () {
      withReplay((async) {
        resolve(async, lateRound(kills: false));
        link.server(stateOf(Phase.roll, round: 5));
        expect(replay.canSkipToKeep, isFalse);
      });
    });

    test('puts the playhead on the last notch and moves on at once, without the end dwell, even paused', () {
      withReplay((async) {
        resolve(async, lateRound(kills: false), then: () => link.server(keepAfterLateRound()));
        async.elapse(step);
        playhead.pause();
        replay.skip();
        expect(playhead.notch, playhead.notchCount - 1);
        async.flushMicrotasks();
        expect(controller.isResolving, isFalse);
        expect(replay.timeline, isNull);
        expect(replay.canSkipToKeep, isFalse);
      });
    });

    test('during the end dwell, ends it at once', () {
      withReplay((async) {
        resolve(async, lateRound(kills: false), then: () => link.server(keepAfterLateRound()));
        async.elapse(step * 4);
        expect(controller.isResolving, isTrue, reason: 'the end of the round stays on screen');
        expect(replay.canSkipToKeep, isTrue);
        replay.skip();
        async.flushMicrotasks();
        expect(controller.isResolving, isFalse);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('with no round playing, does nothing', () {
      withReplay((async) {
        replay.skip();
        expect(playhead.notchCount, 0);
      });
    });
  });

  group('dispose', () {
    test('while a paused replay waits: no error, no timer left, the round never ends', () {
      withReplay((async) {
        resolve(async, lateRound(kills: false));
        async.elapse(step);
        playhead.pause();
        replay.dispose();
        replayDisposed = true;
        async.flushMicrotasks();
        expect(async.pendingTimers, isEmpty);
        expect(controller.isResolving, isTrue);
      });
    });

    test('during the end dwell: no error, no timer left, the round never ends', () {
      withReplay((async) {
        resolve(async, lateRound(kills: false));
        async.elapse(step * 4);
        expect(async.pendingTimers, hasLength(1), reason: 'the end dwell');
        replay.dispose();
        replayDisposed = true;
        expect(async.pendingTimers, isEmpty);
        async.elapse(dwell * 2);
        expect(controller.isResolving, isTrue);
      });
    });
  });
}
