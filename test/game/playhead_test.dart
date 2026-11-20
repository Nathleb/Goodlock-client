import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/playhead.dart';

const step = Duration(milliseconds: 900);

/// Counts the notifications of [p].
int Function() listen(Playhead p) {
  var count = 0;
  p.addListener(() => count++);
  return () => count;
}

void main() {
  group('load', () {
    test('an unloaded playhead has no notch and does not play', () {
      final p = Playhead();
      expect(p.notchCount, 0);
      expect(p.notch, 0);
      expect(p.playing, isFalse);
      expect(p.atEnd, isFalse);
    });

    test('TL-6: a new timeline puts the playhead back at the beginning, paused', () {
      fakeAsync((async) {
        final p = Playhead()..load(5);
        p.seekToNotch(3);
        p.load(5);
        expect(p.notch, 0);
        expect(p.notchCount, 5);
        expect(p.playing, isFalse);

        p.play();
        async.elapse(step);
        p.load(6);
        expect(p.notch, 0);
        expect(p.playing, isFalse);
        async.elapse(step * 3);
        expect(p.notch, 0, reason: 'the playback of the previous timeline is cancelled');
      });
    });

    test('loading notifies once', () {
      final p = Playhead();
      final count = listen(p);
      p.load(4);
      expect(count(), 1);
    });

    test('a timeline has at least two notches (before and after the round)', () {
      expect(() => Playhead().load(1), throwsArgumentError);
      expect(() => Playhead().load(0), throwsArgumentError);
    });

    test('haltAt is a notch after the first one', () {
      expect(() => Playhead().load(4, haltAt: 0), throwsArgumentError);
      expect(() => Playhead().load(4, haltAt: 4), throwsArgumentError);
    });

    test('a timeline of two notches loads and plays to its end', () {
      fakeAsync((async) {
        final p = Playhead()..load(2);
        expect(p.notchCount, 2);
        p.play();
        async.elapse(step);
        expect(p.notch, 1);
        expect(p.atEnd, isTrue);
        expect(p.playing, isFalse);
      });
    });

    test('FLOW-6: haltAt can be the first notch after the start', () {
      fakeAsync((async) {
        final p = Playhead()..load(3, autoplay: true, haltAt: 1);
        async.elapse(step * 3);
        expect(p.notch, 1);
        expect(p.playing, isFalse);
      });
    });

    test('FLOW-6: a load without haltAt forgets the haltAt of the previous load', () {
      fakeAsync((async) {
        final p = Playhead()..load(6, haltAt: 2);
        p.load(6, autoplay: true);
        async.elapse(step * 5);
        expect(p.notch, 5, reason: 'the playback goes to the last notch, not the stale haltAt');
        expect(p.atEnd, isTrue);
      });
    });

    test('FLOW-4: autoplay starts the playback at once', () {
      fakeAsync((async) {
        final p = Playhead();
        final count = listen(p);
        p.load(4, autoplay: true);
        expect(p.playing, isTrue);
        expect(p.notch, 0);
        expect(count(), 1, reason: 'loading and starting the playback is one change');
        async.elapse(step);
        expect(p.notch, 1);
      });
    });
  });

  group('play', () {
    test('TL-6: play moves the playhead one notch per step delay', () {
      fakeAsync((async) {
        final p = Playhead()..load(4);
        p.play();
        expect(p.playing, isTrue);
        expect(p.notch, 0);
        async.elapse(step - const Duration(milliseconds: 1));
        expect(p.notch, 0);
        async.elapse(const Duration(milliseconds: 1));
        expect(p.notch, 1);
        async.elapse(step);
        expect(p.notch, 2);
      });
    });

    test('TL-6, FLOW-5: the playback stops on the last notch', () {
      fakeAsync((async) {
        final p = Playhead()..load(4);
        p.play();
        async.elapse(step * 3);
        expect(p.notch, 3);
        expect(p.atEnd, isTrue);
        expect(p.playing, isFalse);
        async.elapse(step * 5);
        expect(p.notch, 3);
      });
    });

    test('FLOW-6: the playback stops on the haltAt notch, not on the last one', () {
      fakeAsync((async) {
        final p = Playhead()..load(6, autoplay: true, haltAt: 2);
        async.elapse(step * 2);
        expect(p.notch, 2);
        expect(p.playing, isFalse);
        expect(p.atEnd, isFalse);
        async.elapse(step * 5);
        expect(p.notch, 2);
      });
    });

    test('FLOW-6: playing again after the halt starts from the beginning and halts there again', () {
      fakeAsync((async) {
        final p = Playhead()..load(6, autoplay: true, haltAt: 2);
        async.elapse(step * 2);
        p.play();
        expect(p.notch, 0);
        expect(p.playing, isTrue);
        async.elapse(step * 5);
        expect(p.notch, 2);
        expect(p.playing, isFalse);
      });
    });

    test('FLOW-6: playing from before haltAt stops on haltAt', () {
      fakeAsync((async) {
        final p = Playhead()..load(6, haltAt: 3);
        p.seekToNotch(1);
        p.play();
        async.elapse(step * 5);
        expect(p.notch, 3);
      });
    });

    test('TL-6: play from the end starts again from the beginning', () {
      fakeAsync((async) {
        final p = Playhead()..load(4);
        p.fastForward();
        final count = listen(p);
        p.play();
        expect(p.notch, 0);
        expect(p.playing, isTrue);
        expect(count(), 1);
        async.elapse(step);
        expect(p.notch, 1);
      });
    });

    test('TL-6: play from the middle goes on from there', () {
      fakeAsync((async) {
        final p = Playhead()..load(5);
        p.seekToNotch(2);
        p.play();
        expect(p.notch, 2);
        async.elapse(step);
        expect(p.notch, 3);
      });
    });

    test('every move of the playback notifies once', () {
      fakeAsync((async) {
        final p = Playhead()..load(4);
        final count = listen(p);
        p.play();
        expect(count(), 1);
        async.elapse(step);
        expect(count(), 2);
        async.elapse(step * 2);
        expect(count(), 4, reason: 'two moves, the last one also stops the playback');
        async.elapse(step * 3);
        expect(count(), 4);
      });
    });

    test('play while playing changes nothing', () {
      fakeAsync((async) {
        final p = Playhead()..load(4);
        p.play();
        async.elapse(step ~/ 2);
        final count = listen(p);
        p.play();
        expect(count(), 0);
        async.elapse(step ~/ 2);
        expect(p.notch, 1, reason: 'the step in progress is not restarted');
      });
    });

    test('play on an unloaded playhead is a no-op', () {
      fakeAsync((async) {
        final p = Playhead();
        final count = listen(p);
        p.play();
        p.togglePlay();
        expect(p.playing, isFalse);
        expect(count(), 0);
        async.elapse(step * 3);
        expect(p.notch, 0);
      });
    });

    test('the step delay is configurable, and a change applies to the playback in progress (x2)', () {
      fakeAsync((async) {
        final p = Playhead(stepDelay: const Duration(milliseconds: 500))..load(10);
        p.play();
        async.elapse(const Duration(milliseconds: 500));
        expect(p.notch, 1);
        p.stepDelay = const Duration(milliseconds: 200);
        expect(p.stepDelay, const Duration(milliseconds: 200));
        async.elapse(const Duration(milliseconds: 200));
        expect(p.notch, 2);
        async.elapse(const Duration(milliseconds: 400));
        expect(p.notch, 4);
      });
    });

    test('changing the step delay notifies once; setting the same one does not', () {
      final p = Playhead()..load(4);
      final count = listen(p);
      p.stepDelay = const Duration(milliseconds: 450);
      expect(count(), 1);
      p.stepDelay = const Duration(milliseconds: 450);
      expect(count(), 1);
    });

    test('changing the step delay while paused does not start the playback', () {
      fakeAsync((async) {
        final p = Playhead()..load(4);
        p.stepDelay = const Duration(milliseconds: 200);
        expect(p.playing, isFalse);
        async.elapse(step * 3);
        expect(p.notch, 0);
      });
    });

    test('the default step delay is 900 ms', () {
      expect(Playhead().stepDelay, step);
    });
  });

  group('pause', () {
    test('TL-6: the same button pauses and plays', () {
      fakeAsync((async) {
        final p = Playhead()..load(5);
        final count = listen(p);
        p.togglePlay();
        expect(p.playing, isTrue);
        async.elapse(step);
        p.togglePlay();
        expect(p.playing, isFalse);
        expect(count(), 3);
        async.elapse(step * 3);
        expect(p.notch, 1);
        p.togglePlay();
        expect(p.playing, isTrue);
        async.elapse(step);
        expect(p.notch, 2);
      });
    });

    test('pause when not playing changes nothing', () {
      final p = Playhead()..load(4);
      final count = listen(p);
      p.pause();
      expect(count(), 0);
    });

    test('TL-6: opening the die view stops the playback', () {
      fakeAsync((async) {
        final p = Playhead()..load(5, autoplay: true);
        async.elapse(step);
        final count = listen(p);
        p.stop();
        expect(p.playing, isFalse);
        expect(p.notch, 1);
        expect(count(), 1);
        async.elapse(step * 3);
        expect(p.notch, 1);
        p.stop();
        expect(count(), 1);
      });
    });
  });

  group('fast forward', () {
    test('TL-6: fast forward puts the playhead on the last notch and stops the playback', () {
      fakeAsync((async) {
        final p = Playhead()..load(5, autoplay: true);
        async.elapse(step);
        final count = listen(p);
        p.fastForward();
        expect(p.notch, 4);
        expect(p.atEnd, isTrue);
        expect(p.playing, isFalse);
        expect(count(), 1);
        async.elapse(step * 3);
        expect(p.notch, 4);
      });
    });

    test('TL-6: fast forward goes to the last notch even past haltAt', () {
      final p = Playhead()..load(5, haltAt: 2);
      p.fastForward();
      expect(p.notch, 4);
    });

    test('fast forward on the last notch, paused, changes nothing', () {
      final p = Playhead()..load(4);
      p.fastForward();
      final count = listen(p);
      p.fastForward();
      expect(count(), 0);
    });

    test('fast forward on an unloaded playhead is a no-op', () {
      final p = Playhead();
      final count = listen(p);
      p.fastForward();
      expect(p.notch, 0);
      expect(count(), 0);
    });
  });

  group('seek', () {
    test('TL-6: dragging snaps the playhead to the nearest notch', () {
      final p = Playhead()..load(5); // notches at 0, .25, .5, .75, 1
      p.seek(0.6);
      expect(p.notch, 2);
      p.seek(0.63);
      expect(p.notch, 3);
      p.seek(1);
      expect(p.notch, 4);
      p.seek(0);
      expect(p.notch, 0);
      p.seek(0.12);
      expect(p.notch, 0);
    });

    test('dragging beyond either end clamps to the first or last notch', () {
      final p = Playhead()..load(5);
      p.seek(1.5);
      expect(p.notch, 4);
      p.seek(-0.5);
      expect(p.notch, 0);
    });

    test('a NaN fraction is ignored: no move, no notification, the playback goes on', () {
      fakeAsync((async) {
        final p = Playhead()..load(5, autoplay: true);
        final count = listen(p);
        p.seek(double.nan);
        expect(p.notch, 0);
        expect(p.playing, isTrue);
        expect(count(), 0);
        async.elapse(step);
        expect(p.notch, 1);
      });
    });

    test('TL-6: dragging stops the playback', () {
      fakeAsync((async) {
        final p = Playhead()..load(5, autoplay: true);
        final count = listen(p);
        p.seek(0.5);
        expect(p.notch, 2);
        expect(p.playing, isFalse);
        expect(count(), 1);
        async.elapse(step * 3);
        expect(p.notch, 2);
      });
    });

    test('dragging to the current notch, paused, changes nothing', () {
      final p = Playhead()..load(5);
      p.seek(0.5);
      final count = listen(p);
      p.seek(0.55);
      expect(count(), 0);
    });

    test('TL-6: tapping a notch moves the playhead there and stops the playback', () {
      fakeAsync((async) {
        final p = Playhead()..load(5, autoplay: true);
        final count = listen(p);
        p.seekToNotch(3);
        expect(p.notch, 3);
        expect(p.playing, isFalse);
        expect(count(), 1);
        async.elapse(step * 3);
        expect(p.notch, 3);
      });
    });

    test('tapping a notch out of range clamps it', () {
      final p = Playhead()..load(5);
      p.seekToNotch(9);
      expect(p.notch, 4);
      p.seekToNotch(-1);
      expect(p.notch, 0);
    });

    test('tapping the current notch, while playing, stops the playback and notifies once', () {
      fakeAsync((async) {
        final p = Playhead()..load(5, autoplay: true);
        final count = listen(p);
        p.seekToNotch(0);
        expect(p.playing, isFalse);
        expect(count(), 1);
      });
    });

    test('seeking an unloaded playhead is a no-op', () {
      final p = Playhead();
      final count = listen(p);
      p.seek(0.5);
      p.seekToNotch(2);
      expect(p.notch, 0);
      expect(count(), 0);
    });
  });

  test('dispose cancels the playback', () {
    fakeAsync((async) {
      final p = Playhead()..load(5, autoplay: true);
      p.dispose();
      async.elapse(step * 3);
      expect(p.notch, 0);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
