import 'dart:async';

import 'package:flutter/material.dart';

import '../game/human_match_controller.dart';
import '../game/playhead.dart';
import '../game/round_timeline.dart';
import '../net/models.dart';
import '../widgets/match_result.dart';
import 'match_screen.dart';
import 'placement_screen.dart';
import 'selection_screen.dart';

/// The match from the player's seat: the screen of each phase, the match screen for the Keep and the Resolve
/// (FLOW-3..5), and the result (FLOW-6). Everything it shows comes from [HumanMatchController]; the playhead of the
/// match screen is its own.
class HumanMatchView extends StatefulWidget {
  final HumanMatchController controller;
  final VoidCallback onLeave;

  /// The time between two notches of the playback; tests use a short one.
  final Duration stepDelay;

  /// How long the end of a played round stays on screen before the match moves on; tests use none.
  final Duration endDwell;
  const HumanMatchView({
    super.key,
    required this.controller,
    required this.onLeave,
    this.stepDelay = const Duration(milliseconds: 900),
    this.endDwell = const Duration(milliseconds: 1200),
  });

  @override
  State<HumanMatchView> createState() => _HumanMatchViewState();
}

class _HumanMatchViewState extends State<HumanMatchView> {
  late final Playhead _playhead = Playhead(stepDelay: widget.stepDelay);
  bool _draining = false;

  /// The round on screen during Resolve, and its timeline; it stays under the result once the match is over.
  PlayableRound? _round;
  RoundTimeline? _resolveTimeline;

  /// The Keep timeline the playhead was loaded with.
  RoundTimeline? _loadedKeep;

  /// Ends the wait for the playhead, when the view goes away mid-round.
  VoidCallback? _stopWaiting;

  HumanMatchController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    _onChange();
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _stopWaiting?.call();
    _playhead.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!_draining && _c.hasRoundToPlay) _drain();
    _loadKeep();
  }

  /// TL-6: a new Keep timeline (a new Roll) puts the playhead back at the beginning, paused.
  void _loadKeep() {
    final timeline = _c.keepTimeline;
    if (_c.isResolving || _resolveTimeline != null || timeline == null || identical(timeline, _loadedKeep)) return;
    _loadedKeep = timeline;
    _playhead.load(timeline.notchCount);
  }

  /// Plays the rounds the server resolved, one after the other, then lets the controller move on.
  Future<void> _drain() async {
    _draining = true;
    await null; // past the build in progress, and the events that came with the resolved round (the game over)
    while (mounted) {
      final round = _c.nextRound();
      if (round == null) break;
      final timeline = RoundTimeline.build(round.start, round.log);
      final lastStep = timeline.notchCount - 2;
      setState(() {
        _round = round;
        _resolveTimeline = timeline;
        _loadedKeep = null;
      });
      // FLOW-4: plays by itself; FLOW-6: stops on the effect that ends the match.
      _playhead.load(timeline.notchCount, autoplay: true, haltAt: _endsMatch && lastStep >= 1 ? lastStep : null);
      await _untilStop(timeline);
      if (!mounted) return;
      await Future<void>.delayed(widget.endDwell);
      if (!mounted) return;
      if (!_endsMatch) setState(() => _resolveTimeline = null);
      _c.roundPlayed();
    }
    _draining = false;
  }

  /// Whether the round on screen is the one the match ended in.
  bool get _endsMatch => _c.over != null && !_c.hasRoundToPlay;

  /// Completes once the playhead reaches the stop notch: the last one (FLOW-5), or the last step when the match
  /// ended in this round (FLOW-6), even when the game over comes once the playback has started. A pause holds it;
  /// a seek or fast forward to the stop notch or past it counts.
  Future<void> _untilStop(RoundTimeline timeline) {
    final reached = Completer<void>();
    final last = timeline.notchCount - 1;
    void check() {
      if (reached.isCompleted) return;
      final stop = _endsMatch && last > 1 ? last - 1 : last;
      if (_playhead.notch < stop) return;
      if (_playhead.notch == stop && stop < last) _playhead.pause();
      _stopWaiting?.call();
    }

    _stopWaiting = () {
      _playhead.removeListener(check);
      _c.removeListener(check);
      _stopWaiting = null;
      if (!reached.isCompleted) reached.complete();
    };
    _playhead.addListener(check);
    _c.addListener(check);
    check();
    return reached.future;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _screen()),
              if (_c.showResult)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: MatchResult(over: _c.over!, viewerIndex: _c.me, onLeave: widget.onLeave),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _screen() {
    final resolving = _resolveTimeline;
    if (resolving != null) {
      return MatchScreen(
        controller: _c,
        playhead: _playhead,
        timeline: resolving,
        resolving: true,
        phaseLabel: 'Round ${_round!.round + 1} · Résolution',
      );
    }
    final keep = _c.keepTimeline;
    return switch (_c.phase) {
      Phase.selection => SelectionScreen(controller: _c),
      Phase.placement => PlacementScreen(controller: _c),
      Phase.keep when keep != null && identical(keep, _loadedKeep) => MatchScreen(
        controller: _c,
        playhead: _playhead,
        timeline: keep,
      ),
      _ => const Center(child: Text('En attente du serveur…')),
    };
  }
}
