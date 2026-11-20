import 'package:flutter/material.dart';

import '../game/human_match_controller.dart';
import '../game/playhead.dart';
import '../game/round_replay.dart';
import '../game/round_timeline.dart';
import '../net/models.dart';
import '../net/rules.dart';
import '../widgets/match_bar.dart';
import '../widgets/match_result.dart';
import 'match_screen.dart';

/// A match watched from one seat, with nothing to play: the bots, or whoever holds the seat, play every phase.
/// Before combat a line says what the players are doing; each round the server resolved is then replayed on the
/// match screen, read-only (FLOW-4, FLOW-5), and stays there until the next one; the result comes over the last
/// round (FLOW-6). The timeline can still be paused, fast forwarded and sought, and a portrait opens its die view.
class SpectatorMatchView extends StatefulWidget {
  final HumanMatchController controller;
  final VoidCallback onLeave;

  /// The time between two notches of the playback; tests use a short one.
  final Duration stepDelay;

  /// How long the end of a played round stays before the next round plays; tests use none.
  final Duration endDwell;
  const SpectatorMatchView({
    super.key,
    required this.controller,
    required this.onLeave,
    this.stepDelay = const Duration(milliseconds: 900),
    this.endDwell = const Duration(milliseconds: 1200),
  });

  @override
  State<SpectatorMatchView> createState() => _SpectatorMatchViewState();
}

class _SpectatorMatchViewState extends State<SpectatorMatchView> {
  late final Playhead _playhead = Playhead(stepDelay: widget.stepDelay);
  late final RoundReplay _replay;

  /// The last round replayed, kept on screen once played.
  PlayableRound? _round;
  RoundTimeline? _timeline;

  HumanMatchController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _replay = RoundReplay(_c, _playhead, endDwell: widget.endDwell)..addListener(_onReplay);
  }

  @override
  void dispose() {
    _replay.dispose();
    _playhead.dispose();
    super.dispose();
  }

  void _onReplay() {
    final timeline = _replay.timeline;
    if (timeline == null) return;
    _round = _replay.round;
    _timeline = timeline;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_c, _replay]),
      builder: (context, _) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _screen(context)),
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

  Widget _screen(BuildContext context) {
    final timeline = _timeline;
    if (timeline != null) {
      return MatchScreen(
        controller: _c,
        playhead: _playhead,
        timeline: timeline,
        resolving: true,
        phaseLabel: 'Round ${_round!.round + 1} · Résolution',
        initiativePlayerIndex: _round!.initiativePlayerIndex,
      );
    }
    return Column(
      children: [
        // A spectator has nothing to confirm: the bar of the Resolve, with no button.
        MatchBar(controller: _c, resolving: true),
        Expanded(
          child: Center(child: Text(_describe(_c.state), textAlign: TextAlign.center)),
        ),
      ],
    );
  }

  String _describe(GameStateView? gs) => switch (gs?.phase) {
    Phase.selection => 'Team preview : chaque bot garde $teamSize de ses $deckSize.',
    Phase.placement => 'Placement (équipe adverse cachée).',
    Phase.keep => 'Les bots choisissent les dés à garder.',
    _ => 'En attente du serveur…',
  };
}
