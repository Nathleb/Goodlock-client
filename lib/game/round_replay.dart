// The replay of the rounds the server resolved (FLOW-4..6), shared by the player's match and the spectator's.
// No widget: the screen listens to it and shows [RoundReplay.timeline] at the notch of [RoundReplay.playhead].

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'human_match_controller.dart';
import 'playhead.dart';
import 'round_timeline.dart';

/// Plays the rounds of [controller], one after the other, on [playhead], then lets the controller move on.
///
/// Each round autoplays from its first notch (FLOW-4) and stops on its last one (FLOW-5), which stays on screen for
/// [endDwell]; the round the match ended in stops on its last step instead (FLOW-6) and stays. A pause holds the
/// round; a seek or fast forward to the stop notch or past it ends it.
class RoundReplay extends ChangeNotifier {
  final HumanMatchController controller;
  final Playhead playhead;
  final Duration endDwell;
  RoundReplay(this.controller, this.playhead, {required this.endDwell}) {
    controller.addListener(_onChange);
    _onChange();
  }

  PlayableRound? _round;
  RoundTimeline? _timeline;
  bool _draining = false;
  bool _disposed = false;

  /// Ends the wait for the playhead, when the replay goes away mid-round.
  VoidCallback? _stopWaiting;

  /// The round on screen, and its timeline; null between two rounds. The round the match ended in stays.
  PlayableRound? get round => _round;
  RoundTimeline? get timeline => _timeline;

  void _onChange() {
    if (!_draining && controller.hasRoundToPlay) _drain();
  }

  Future<void> _drain() async {
    _draining = true;
    await null; // past the build in progress, and the events that came with the resolved round (the game over)
    while (!_disposed) {
      final round = controller.nextRound();
      if (round == null) break;
      final timeline = RoundTimeline.build(round.start, round.log);
      final lastStep = timeline.notchCount - 2;
      _round = round;
      _timeline = timeline;
      notifyListeners();
      // FLOW-4: plays by itself; FLOW-6: stops on the effect that ends the match.
      playhead.load(timeline.notchCount, autoplay: true, haltAt: _endsMatch && lastStep >= 1 ? lastStep : null);
      await _untilStop(timeline);
      if (_disposed) return;
      await Future<void>.delayed(endDwell);
      if (_disposed) return;
      if (!_endsMatch) {
        _timeline = null;
        notifyListeners();
      }
      controller.roundPlayed();
    }
    _draining = false;
  }

  /// Whether the round on screen is the one the match ended in.
  bool get _endsMatch => controller.over != null && !controller.hasRoundToPlay;

  /// Completes once the playhead reaches the stop notch: the last one (FLOW-5), or the last step when the match
  /// ended in this round (FLOW-6), even when the game over comes once the playback has started. A pause holds it;
  /// a seek or fast forward to the stop notch or past it counts.
  Future<void> _untilStop(RoundTimeline timeline) {
    final reached = Completer<void>();
    final last = timeline.notchCount - 1;
    void check() {
      if (reached.isCompleted) return;
      final stop = _endsMatch && last > 1 ? last - 1 : last;
      if (playhead.notch < stop) return;
      if (playhead.notch == stop && stop < last) playhead.pause();
      _stopWaiting?.call();
    }

    _stopWaiting = () {
      playhead.removeListener(check);
      controller.removeListener(check);
      _stopWaiting = null;
      if (!reached.isCompleted) reached.complete();
    };
    playhead.addListener(check);
    controller.addListener(check);
    check();
    return reached.future;
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_onChange);
    _stopWaiting?.call();
    super.dispose();
  }
}
