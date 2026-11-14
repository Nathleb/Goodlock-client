import 'package:flutter/material.dart';

import '../game/human_match_controller.dart';
import '../net/models.dart';
import '../net/rules.dart';
import '../widgets/character_card.dart';
import '../widgets/match_bar.dart';

/// SEL-2: the player keeps [teamSize] characters of their own deck, after seeing both decks (CHAR-1).
/// Mine on the left, the opponent's on the right and read only, like the board (LAYOUT-3).
class SelectionScreen extends StatelessWidget {
  final HumanMatchController controller;
  const SelectionScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selection = controller.state?.selection;
        return Column(
          children: [
            MatchBar(controller: controller),
            Expanded(
              child: selection == null
                  ? const Center(child: Text('En attente du serveur…'))
                  : Row(
                      children: [
                        Expanded(child: _deck(context, 'Ton deck', selection.decks[controller.me], interactive: true)),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _deck(context, 'Deck adverse', selection.decks[1 - controller.me], interactive: false),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _deck(BuildContext context, String title, List<CatalogCharacter> deck, {required bool interactive}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const Spacer(),
              if (interactive) Text('${controller.picks.length}/$teamSize choisis', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 1.15,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final c in deck)
                  CharacterCard(
                    character: c,
                    selected: interactive && controller.picks.contains(c.id),
                    onTap: interactive && !controller.ready ? () => controller.togglePick(c.id) : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
