import 'package:flutter/material.dart';

import '../game/human_match_controller.dart';
import '../game/playhead.dart';
import '../game/round_timeline.dart';
import '../game/step_outcome.dart';
import '../widgets/die_view.dart';
import '../widgets/match_bar.dart';
import '../widgets/match_board.dart';
import '../widgets/timeline_bar.dart';

/// The screen of a round, for the Keep and the Resolve alike (LAYOUT-1): the status bar on top, with the caption
/// of the step on display (LAYOUT-2, STEP-5), the board in the middle at the notch of the [playhead] (STEP-1), and
/// the [timeline] at the bottom.
///
/// In a Keep ([resolving] false) the timeline is the preview of the round (UX-1) and tapping one of my faces keeps
/// or releases it, wherever the playhead stands (CELL-5). In Resolve the faces cannot be tapped (FLOW-4). Tapping a
/// portrait, on either side, stops the playback and opens the die view (CELL-5, TL-6).
class MatchScreen extends StatelessWidget {
  final HumanMatchController controller;
  final Playhead playhead;
  final RoundTimeline timeline;
  final bool resolving;

  /// Replaces the title of the phase in the status bar (see [MatchBar.phaseLabel]).
  final String? phaseLabel;

  /// Who held the initiative in the round on display, in Resolve (see [MatchBar.initiativePlayerIndex]).
  final int? initiativePlayerIndex;

  /// See [MatchBar.onSkipToKeep].
  final VoidCallback? onSkipToKeep;

  /// See [MatchBar.canConcede].
  final bool canConcede;
  const MatchScreen({
    super.key,
    required this.controller,
    required this.playhead,
    required this.timeline,
    this.resolving = false,
    this.phaseLabel,
    this.initiativePlayerIndex,
    this.onSkipToKeep,
    this.canConcede = true,
  });

  @override
  Widget build(BuildContext context) {
    final roundStartHp = {for (final c in timeline.boards.first) c.id: c.hp};
    return ListenableBuilder(
      listenable: Listenable.merge([controller, playhead]),
      builder: (context, _) {
        final notch = playhead.notch.clamp(0, timeline.notchCount - 1);
        final outcome = stepOutcome(timeline, notch, resolving: resolving);
        final canTapFaces = !resolving && !controller.ready;
        return Column(
          children: [
            MatchBar(
              controller: controller,
              caption: outcome.caption,
              phaseLabel: phaseLabel,
              resolving: resolving,
              initiativePlayerIndex: initiativePlayerIndex,
              onSkipToKeep: onSkipToKeep,
              canConcede: canConcede,
            ),
            Expanded(
              child: MatchBoard(
                players: playersFromBoard(timeline.boardAt(notch)),
                me: controller.me,
                locks: resolving ? const {} : controller.locks,
                outcome: outcome,
                roundStartHp: roundStartHp,
                onFaceTap: canTapFaces ? controller.toggleLock : null,
                onPortraitTap: (character) {
                  playhead.stop();
                  showDieView(context, character);
                },
              ),
            ),
            TimelineBar(timeline: timeline, playhead: playhead, me: controller.me),
          ],
        );
      },
    );
  }
}
