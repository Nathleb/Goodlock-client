import 'package:flutter/material.dart';

import '../game/human_match_controller.dart';
import '../net/models.dart';
import 'match_clocks_bar.dart';

/// The status bar of the decision screens (LAYOUT-2): the phase and the round, who holds the initiative,
/// both clocks, concede, and the Confirm button, which reads Cancel once confirmed (GAME-8).
class MatchBar extends StatelessWidget {
  final HumanMatchController controller;
  const MatchBar({super.key, required this.controller});

  String _title(GameStateView? s) => switch (s?.phase) {
    Phase.selection => 'Choix de l\'équipe',
    Phase.placement => 'Placement',
    Phase.keep => 'Round ${s!.currentRound + 1} · relances : ${s.rollsLeft}',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const BackButton(),
            Text(_title(s), style: theme.textTheme.titleSmall),
            if (s != null)
              Tooltip(
                message: s.initiativePlayerIndex == controller.me ? 'Initiative : toi' : 'Initiative : adversaire',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.bolt,
                    size: 20,
                    color: s.initiativePlayerIndex == controller.me ? Colors.amber : Colors.white38,
                  ),
                ),
              ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(width: 640, child: MatchClocksBar(clocks: controller.clocks)),
              ),
            ),
            IconButton(
              tooltip: 'Abandonner',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => _confirmConcede(context),
            ),
            const SizedBox(width: 4),
            if (controller.canCancel)
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
