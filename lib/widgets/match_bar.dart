import 'package:flutter/material.dart';

import '../game/human_match_controller.dart';
import '../net/models.dart';
import 'match_clocks_bar.dart';

/// The status bar of the match screens (LAYOUT-2): the phase and the round, who holds the initiative, the
/// caption of the step on display (STEP-5), both clocks, concede (not for a spectator), and the Confirm button, which reads Cancel
/// once confirmed (GAME-8). During Resolve, and for a spectator, there is nothing to confirm: no button, unless the
/// next Keep is already there, when the button skips to it ([onSkipToKeep]).
class MatchBar extends StatelessWidget {
  final HumanMatchController controller;

  /// The step on display, in one line between the title and the clocks (a tap shows it whole); null: no caption.
  final String? caption;

  /// Replaces the title of the phase, e.g. during Resolve, when the controller may already hold the next Keep.
  final String? phaseLabel;
  final bool resolving;

  /// Replaces who holds the initiative, e.g. during Resolve: the round on display's, not the next Keep's.
  final int? initiativePlayerIndex;

  /// KEEP-3: shown during Resolve once the next Keep has come, where Confirm would be; null: no such button.
  final VoidCallback? onSkipToKeep;

  /// Whether the concede button shows; a spectator has no match to concede.
  final bool canConcede;
  const MatchBar({
    super.key,
    required this.controller,
    this.caption,
    this.phaseLabel,
    this.resolving = false,
    this.initiativePlayerIndex,
    this.onSkipToKeep,
    this.canConcede = true,
  });

  String _title(GameStateView? s) => switch (s?.phase) {
    Phase.selection => 'Choix de l\'équipe',
    Phase.placement => 'Placement',
    Phase.keep => 'Round ${s!.currentRound + 1} · relances : ${s.rollsLeft}',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final initiative = initiativePlayerIndex ?? s?.initiativePlayerIndex;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const BackButton(),
            Text(phaseLabel ?? _title(s), style: theme.textTheme.titleSmall),
            if (initiative != null)
              Tooltip(
                message: initiative == controller.me ? 'Initiative : toi' : 'Initiative : adversaire',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.bolt,
                    size: 20,
                    color: initiative == controller.me ? Colors.amber : Colors.white38,
                  ),
                ),
              ),
            if (caption != null)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Tooltip(
                    // STEP-5: one line; a tap shows it whole.
                    triggerMode: TooltipTriggerMode.tap,
                    message: caption,
                    child: Text(
                      caption!,
                      key: const ValueKey('step-caption'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(width: caption == null ? 640 : 440, child: MatchClocksBar(clocks: controller.clocks)),
              ),
            ),
            if (canConcede)
              IconButton(
                tooltip: 'Abandonner',
                icon: const Icon(Icons.flag_outlined),
                onPressed: () => _confirmConcede(context),
              ),
            const SizedBox(width: 4),
            if (onSkipToKeep != null)
              FilledButton(
                key: const ValueKey('skip-to-keep'),
                onPressed: onSkipToKeep,
                // Compact, to leave the round's title its room on a small phone.
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: theme.textTheme.labelMedium,
                ),
                child: const Text('Passer au Keep'),
              )
            else if (resolving)
              const SizedBox.shrink()
            else if (controller.canCancel)
              OutlinedButton(key: const ValueKey('cancel'), onPressed: controller.cancel, child: const Text('Annuler'))
            else
              FilledButton(
                key: const ValueKey('confirm'),
                onPressed: controller.canConfirm ? controller.confirm : null,
                child: const Text('Confirmer'),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  /// AWAY-1: conceding loses at once, so it asks first.
  Future<void> _confirmConcede(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner le match ?'),
        content: const Text('Tu perds immédiatement.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Continuer')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Abandonner')),
        ],
      ),
    );
    if (sure == true) controller.concede();
  }
}
