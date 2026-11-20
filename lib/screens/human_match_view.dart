import 'package:flutter/material.dart';

import '../game/human_match_controller.dart';
import '../game/playhead.dart';
import '../game/round_replay.dart';
import '../game/round_timeline.dart';
import '../net/models.dart';
import '../widgets/match_result.dart';
import 'match_screen.dart';
import 'placement_screen.dart';
import 'selection_screen.dart';

/// The match from the player's seat: the screen of each phase, the match screen for the Keep and the Resolve
/// (FLOW-3..5), and the result (FLOW-6). Everything it shows comes from [HumanMatchController]; the playhead of the
/// match screen is its own, shared by the Keep preview and the [RoundReplay].
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
  late final RoundReplay _replay;

  /// The Keep timeline the playhead was loaded with.
  RoundTimeline? _loadedKeep;

  HumanMatchController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _replay = RoundReplay(_c, _playhead, endDwell: widget.endDwell)..addListener(_onReplay);
    _c.addListener(_loadKeep);
    _loadKeep();
  }

  @override
  void dispose() {
    _c.removeListener(_loadKeep);
    _replay.dispose();
    _playhead.dispose();
    super.dispose();
  }

  /// A round to play takes the playhead: the Keep that follows loads it again.
  void _onReplay() {
    if (_replay.timeline != null) _loadedKeep = null;
  }

  /// TL-6: a new Keep timeline (a new Roll) puts the playhead back at the beginning, paused.
  void _loadKeep() {
    final timeline = _c.keepTimeline;
    if (_c.isResolving || _replay.timeline != null || timeline == null || identical(timeline, _loadedKeep)) return;
    _loadedKeep = timeline;
    _playhead.load(timeline.notchCount);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_c, _replay]),
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
    final resolving = _replay.timeline;
    if (resolving != null) {
      return MatchScreen(
        controller: _c,
        playhead: _playhead,
        timeline: resolving,
        resolving: true,
        phaseLabel: 'Round ${_replay.round!.round + 1} · Résolution',
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
