// The replay of the rounds the server resolved (FLOW-4..6), shared by the player's match and the spectator's.
// No widget: the screen listens to it and shows [RoundReplay.timeline] at the notch of [RoundReplay.playhead].

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../net/models.dart';
import '../net/rules.dart';
import 'human_match_controller.dart';
import 'playhead.dart';
import 'round_timeline.dart';

/// Plays the rounds of [controller], one after the other, on [playhead], then lets the controller move on.
///
/// Each round autoplays from its first notch (FLOW-4) and stops on the playhead's stop notch: its last one, which
/// stays on screen for [endDwell] (FLOW-5), or, in the round the match ended in, the action that ended it (FLOW-6).
/// A pause holds the round; a seek or fast forward to the stop notch or past it ends it, and [skip] ends it at once.
/// The round the match ended in, or the last one once the match is over, stays on screen.
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
  bool _skipped = false;

  /// Ends the wait for the playhead; null when no round waits for it.
  VoidCallback? _stopWaiting;

  /// The end dwell in progress, and its timer; null outside it.
  Completer<void>? _dwell;
  Timer? _dwellTimer;

  /// The round on screen, and its timeline; null between two rounds. The round the match ended in stays.
  PlayableRound? get round => _round;
  RoundTimeline? get timeline => _timeline;

  /// KEEP-3: the next round's Keep has come, and its clock runs, while this round still plays: [skip] reaches it.
  bool get canSkipToKeep {
    final round = _round;
    final state = controller.state;
    return (_stopWaiting != null || _dwell != null) &&
        round != null &&
        controller.over == null &&
        state != null &&
        state.phase == Phase.keep &&
        state.currentRound > round.round;
  }

  /// Ends the round on screen at once: the playhead on its last notch, no end dwell, and the match moves on.
  void skip() {
    if (_stopWaiting == null && _dwell == null) return;
    _skipped = true;
    playhead.fastForward();
    _endDwell();
  }

  void _onChange() {
    _haltWhereTheMatchEnded();
    if (!_draining && controller.hasRoundToPlay) _drain();
  }

  Future<void> _drain() async {
    _draining = true;
    await null; // past the build in progress, and the events that came with the resolved round (the game over)
    while (!_disposed) {
      final round = controller.nextRound();
      if (round == null) break;
      final timeline = RoundTimeline.build(round.start, round.log);
      _round = round;
      _timeline = timeline;
      _skipped = false;
      notifyListeners();
      // FLOW-4: plays by itself; FLOW-6: stops on the action that ends the match.
      playhead.load(timeline.notchCount, autoplay: true, haltAt: _matchEndNotch(round, timeline));
      await _untilStop();
      if (_disposed) return;
      if (!_skipped) await _endOfRound();
      if (_disposed) return;
      if (!_staysOnScreen) {
        _timeline = null;
        notifyListeners();
      }
      controller.roundPlayed();
    }
    _draining = false;
  }

  /// Whether the round just played stays on screen: the match ended in it, or is over with no round left to play.
  bool get _staysOnScreen => playhead.haltAt != null || (controller.over != null && !controller.hasRoundToPlay);

  /// FLOW-6, for a game over that comes once the playback has started.
  void _haltWhereTheMatchEnded() {
    final round = _round;
    final timeline = _timeline;
    if (_stopWaiting == null || round == null || timeline == null || playhead.haltAt != null) return;
    final notch = _matchEndNotch(round, timeline);
    if (notch != null) playhead.haltAt = notch;
  }

  /// The notch of the action that ended the match, when it ended in this round (FLOW-6); null otherwise.
  ///
  /// It ended in this round when actions were left unplayed (END-1), or when it ended by elimination and a player
  /// has [deathsToLose] dead once the last action has played (END-2). A match lost on time, on reconnection or by a
  /// concession during the replay did not end in it; nor did an elimination at the next Upkeep (a poison death),
  /// which leaves no player with that many dead after the last action.
  int? _matchEndNotch(PlayableRound round, RoundTimeline timeline) {
    final lastPlayed = timeline.tokens.lastIndexWhere((t) => t.status != TokenStatus.unplayed);
    if (lastPlayed < 0) return null;
    final notch = lastPlayed + 1;
    if (lastPlayed < timeline.tokens.length - 1) return notch;
    if (controller.over?.reason != EndReason.elimination) return null;
    final board = timeline.boardAt(notch);
    bool eliminated(int player) =>
        round.fallen[player] + board.where((c) => c.position.playerIndex == player && c.isDead).length >=
        deathsToLose;
    return eliminated(0) || eliminated(1) ? notch : null;
  }

  /// Completes once the playback is over on the playhead's stop notch or past it (a seek or a fast forward counts).
  /// A pause holds it.
  Future<void> _untilStop() {
    final reached = Completer<void>();
    void check() {
      if (!playhead.playing && playhead.notch >= playhead.stopNotch) _stopWaiting?.call();
    }

    _stopWaiting = () {
      playhead.removeListener(check);
      _stopWaiting = null;
      reached.complete();
    };
    playhead.addListener(check);
    check();
    return reached.future;
  }

  /// FLOW-5: the end of the round stays on screen for [endDwell].
  Future<void> _endOfRound() {
    final dwell = _dwell = Completer<void>();
    _dwellTimer = Timer(endDwell, _endDwell);
    return dwell.future;
  }

  void _endDwell() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    final dwell = _dwell;
    _dwell = null;
    dwell?.complete();
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_onChange);
    _stopWaiting?.call();
    _endDwell();
    super.dispose();
  }
}
