import 'package:flutter/material.dart';

import '../game/human_match_controller.dart';
import '../net/models.dart';
import '../net/rules.dart';
import '../widgets/dashed_box.dart';
import '../widgets/face_glyph.dart';
import '../widgets/match_bar.dart';

/// PLACE-1, PLACE-2: the player arranges their four characters on their five cells, as often as they like,
/// then confirms. Two taps move a character: first the character, then a cell. The opponent's side is
/// masked until the first round (GAME-7).
class PlacementScreen extends StatelessWidget {
  final HumanMatchController controller;
  const PlacementScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final byId = {for (final c in controller.myTeam) c.id: c};
        return Column(
          children: [
            MatchBar(controller: controller),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          for (var slot = 0; slot < boardSize; slot++)
                            Expanded(child: _cell(context, slot, byId[controller.layout[slot]])),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.visibility_off_outlined, size: 36),
                            const SizedBox(height: 8),
                            const Text('Équipe adverse masquée jusqu\'au premier round', textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            Text(
                              controller.ready
                                  ? 'Annule pour modifier ton placement.'
                                  : 'Touche un personnage, puis une case.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cell(BuildContext context, int slot, CharacterView? character) {
    final theme = Theme.of(context);
    final selected = controller.selectedSlot == slot;
    final number = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: CircleAvatar(radius: 12, child: Text('$slot', style: const TextStyle(fontSize: 12))),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        key: ValueKey('cell-$slot'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => controller.tapCell(slot),
        child: character == null
            ? DashedBox(
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [number, const Text('vide')]),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 2),
                ),
                child: Row(
                  children: [
                    number,
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(character.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                          Text(
                            'PV ${character.maxHp} · vitesse ${character.baseSpeed}',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Wrap(spacing: 2, children: [for (final f in character.baseDie) FaceGlyph(face: f, size: 16)]),
                  ],
                ),
              ),
      ),
    );
  }
}
