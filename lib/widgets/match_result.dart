import 'package:flutter/material.dart';

import '../net/models.dart';

/// Why the match ended, seen from the viewer's side (END-3).
String endReasonText(EndReason reason, {required bool won}) => switch (reason) {
      EndReason.elimination => won ? 'Deux personnages adverses sont morts.' : 'Deux de tes personnages sont morts.',
      EndReason.clock => won ? "Le temps de l'adversaire est écoulé." : 'Ton temps est écoulé.',
      EndReason.reconnection =>
        won ? "L'adversaire ne s'est pas reconnecté à temps." : "Tu ne t'es pas reconnecté à temps.",
      EndReason.concede => won ? "L'adversaire a abandonné." : 'Tu as abandonné.',
      EndReason.unknown => '',
    };

/// The end of the match (FLOW-6): the winner, why (END-3), and the way out. The server has already
/// closed the room (ROOM-6).
class MatchResult extends StatelessWidget {
  final GameOver over;
  final int viewerIndex;
  final VoidCallback onLeave;
  const MatchResult({super.key, required this.over, required this.viewerIndex, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    final won = over.winner == viewerIndex;
    final why = endReasonText(over.reason, won: won);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(won ? 'Victoire' : 'Défaite', style: Theme.of(context).textTheme.headlineSmall),
          if (why.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(why)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onLeave, child: const Text('Retour')),
        ],
      ),
    );
  }
}
