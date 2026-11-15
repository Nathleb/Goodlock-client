import 'package:flutter/material.dart';

import '../net/models.dart';

/// A status of a character as a short label, and whether it hurts or helps.
class StatusLabel {
  final String text;
  final bool harmful;
  const StatusLabel(this.text, {required this.harmful});
}

/// CELL-2: one label per active status with its value, the shield included: the shield, the states
/// (Haste, Slow, Regen, Poison, Stun, Root, Divine Shield) and the net stats (Power, Armor).
List<StatusLabel> statusLabels(CharacterView c) {
  final labels = <StatusLabel>[];
  if (c.shield > 0) labels.add(StatusLabel('Bouclier ${c.shield}', harmful: false));
  c.states.forEach((axis, value) {
    if (value == 0) return;
    switch (axis) {
      case 'SPEED':
        labels.add(
          value > 0 ? StatusLabel('Haste $value', harmful: false) : StatusLabel('Slow ${-value}', harmful: true),
        );
      case 'VITALITY':
        labels.add(
          value > 0 ? StatusLabel('Regen $value', harmful: false) : StatusLabel('Poison ${-value}', harmful: true),
        );
      case 'STUN':
        labels.add(StatusLabel('Stun $value', harmful: true));
      case 'ROOT':
        labels.add(StatusLabel('Root $value', harmful: true));
      case 'DIVINE_SHIELD':
        labels.add(const StatusLabel('Divine Shield', harmful: false));
    }
  });
  c.stats.forEach((stat, value) {
    if (value == 0) return;
    final name = stat == 'POWER'
        ? 'Power'
        : stat == 'ARMOR'
        ? 'Armor'
        : stat;
    labels.add(StatusLabel('$name ${value > 0 ? '+' : ''}$value', harmful: value < 0));
  });
  return labels;
}

/// The chips of [statusLabels]: harmful and helpful statuses have different colours.
class StatusChips extends StatelessWidget {
  final CharacterView character;
  const StatusChips({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 3,
      runSpacing: 2,
      children: [
        for (final l in statusLabels(character))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: (l.harmful ? Colors.redAccent : Colors.lightGreenAccent).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: l.harmful ? Colors.redAccent : Colors.lightGreenAccent, width: 0.8),
            ),
            child: Text(l.text, style: Theme.of(context).textTheme.labelSmall),
          ),
      ],
    );
  }
}
