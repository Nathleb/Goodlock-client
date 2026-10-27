import 'package:flutter/material.dart';

import '../net/models.dart';
import '../net/rules.dart';

const effectColors = {
  'Damage': Color(0xFFFF6B6B),
  'FixedDamage': Color(0xFF9C1F5B), // sacrificed HP: a cost, not an attack
  'Heal': Color(0xFF7CE38B),
  'Shield': Color(0xFF7FB8FF),
  'Swap': Color(0xFFC08BFF),
  'ApplyStat': Color(0xFF8A5CF6),
  'ApplyState': Color(0xFF2EC4B6),
};

String _chipText(FaceEffect e) {
  if (e.effect == 'ApplyStat') {
    return '${e.stat} ${e.magnitude >= 0 ? '+' : ''}${e.magnitude} · ${e.duration} t.';
  }
  if (e.effect == 'ApplyState') return '${e.state} · ${e.duration} t.';
  return '${e.effect} ${e.effect == 'Swap' ? '' : e.magnitude}';
}

/// One die face: description, priority bracket, each effect with a mini targeting grid.
class DieFaceTile extends StatelessWidget {
  final DieFace face;
  final int index;
  const DieFaceTile({super.key, required this.face, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 16, child: Text('${index + 1}')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(face.description, style: theme.textTheme.titleSmall),
                  Text('priorité ${face.priority >= 0 ? '+' : ''}${face.priority}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  for (final e in face.effects)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(_chipText(e)),
                            side: BorderSide(color: effectColors[e.effect] ?? Colors.white24),
                          ),
                          const SizedBox(width: 8),
                          TargetGrid(groups: e.targets, color: effectColors[e.effect] ?? Colors.white),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sketch of the cells an effect hits, laid out like the board: two columns of [boardSize] cells,
/// allies on the left, enemies on the right, slot 0 on top. Relative targets are drawn from the
/// middle slot (outlined).
class TargetGrid extends StatelessWidget {
  final List<TargetGroup> groups;
  final Color color;
  const TargetGrid({super.key, required this.groups, required this.color});

  static const actorSlot = 2;

  bool _hit(bool enemyRow, int slot) => groups.any((g) {
        if ((g.side == 'ENEMY') != enemyRow) return false;
        return g.n.any((n) => (g.mode == 'RELATIVE' ? actorSlot + n : n) == slot);
      });

  @override
  Widget build(BuildContext context) {
    final relative = groups.any((g) => g.mode == 'RELATIVE');
    Widget cell(bool enemyRow, int slot) {
      final hit = _hit(enemyRow, slot);
      final isActor = relative && !enemyRow && slot == actorSlot;
      return Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: hit ? color : Colors.white10,
          borderRadius: BorderRadius.circular(2),
          border: isActor ? Border.all(color: Colors.white70) : null,
        ),
      );
    }

    Widget column(bool enemy) =>
        Column(mainAxisSize: MainAxisSize.min, children: [for (var s = 0; s < boardSize; s++) cell(enemy, s)]);
    return Row(mainAxisSize: MainAxisSize.min, children: [column(false), const SizedBox(width: 6), column(true)]);
  }
}
