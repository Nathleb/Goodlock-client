import 'package:flutter/material.dart';

import '../game/human_match_controller.dart';
import '../game/resolve_game.dart';
import '../net/models.dart';
import '../widgets/match_clocks_bar.dart';
import '../widgets/match_result.dart';
import '../widgets/resolve_view.dart';
import 'keep_screen.dart';
import 'placement_screen.dart';
import 'selection_screen.dart';

/// The match from the player's seat: the screen of each phase, the Flame scene for Resolve (FLOW-4) and the
/// result (FLOW-6). Everything it shows comes from [HumanMatchController]. The Flame scene stays mounted,
/// out of sight, so it has its size when a round has to be played.
class HumanMatchView extends StatefulWidget {
  final HumanMatchController controller;
  final VoidCallback onLeave;

  /// Playback speed of the Resolve scene, and whether it vibrates; tests use a fast, silent one.
  final double speed;
  final bool haptics;
  const HumanMatchView({
    super.key,
    required this.controller,
    required this.onLeave,
    this.speed = 1,
    this.haptics = true,
  });

  @override
  State<HumanMatchView> createState() => _HumanMatchViewState();
}

class _HumanMatchViewState extends State<HumanMatchView> {
  late final ResolveGame _game;
  bool _draining = false;

  HumanMatchController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _game = ResolveGame(viewerIndex: _c.me)
      ..speed = widget.speed
      ..haptics = widget.haptics;
    _c.addListener(_onChange);
    _onChange();
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!_draining && _c.hasRoundToPlay) _drain();
  }

  /// Plays the rounds the server resolved, one after the other, then lets the controller move on.
  Future<void> _drain() async {
    _draining = true;
    while (mounted) {
      final round = _c.nextRound();
      if (round == null) break;
      await WidgetsBinding.instance.endOfFrame; // the scene is on screen now
      if (!mounted) break;
      await _game.playRound(round.start, round.log);
      if (mounted) _c.roundPlayed();
    }
    _draining = false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final resolving = _c.isResolving;
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Offstage(
                  offstage: !resolving,
                  child: GameScreenFrame(
                    game: _game,
                    title: 'Résolution',
                    status: MatchClocksBar(clocks: _c.clocks),
                    controls: [PlaybackControls(game: _game, onChanged: () => setState(() {}))],
                  ),
                ),
              ),
              if (!resolving) Positioned.fill(child: _phase()),
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

  Widget _phase() => switch (_c.phase) {
    Phase.selection => SelectionScreen(controller: _c),
    Phase.placement => PlacementScreen(controller: _c),
    Phase.keep => KeepScreen(controller: _c),
    _ => const Center(child: Text('En attente du serveur…')),
  };
}
