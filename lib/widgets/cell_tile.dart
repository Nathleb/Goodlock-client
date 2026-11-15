import 'package:flutter/material.dart';

import '../net/models.dart';
import 'face_glyph.dart';
import 'status_chips.dart';

/// A character in its cell. The face is on the lane side, because it is what the player decides on, and the
/// portrait on the edge of the screen, to find one's way (CELL-1). [mine] puts the face on the right; the
/// opponent's cell is its mirror.
class CellTile extends StatelessWidget {
  final CharacterView character;
  final bool mine;

  /// CELL-4: a kept die of mine has a lock mark. The opponent's faces never have one.
  final bool locked;

  /// CELL-5: tapping my face keeps or releases it. Null: not tappable (never for the opponent's).
  final VoidCallback? onFaceTap;
  const CellTile({super.key, required this.character, required this.mine, this.locked = false, this.onFaceTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final portrait = Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
          child: SizedBox(
            width: 150,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: mine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text(character.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                Text('vitesse ${character.baseSpeed}', style: theme.textTheme.labelSmall),
                const SizedBox(height: 2),
                Container(
                  key: ValueKey('hp-${character.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        value: character.maxHp == 0 ? 0 : (character.hp / character.maxHp).clamp(0.0, 1.0),
                        minHeight: 6,
                        color: Colors.lightGreenAccent,
                        backgroundColor: Colors.white12,
                      ),
                      Text(
                        '${character.hp}/${character.maxHp}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                StatusChips(character: character),
              ],
            ),
          ),
        ),
      ),
    );
    final face = Expanded(flex: 2, child: Center(child: _face(context)));
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: mine ? [portrait, face] : [face, portrait]),
    );
  }

  Widget _face(BuildContext context) {
    final tile = Stack(
      clipBehavior: Clip.none,
      children: [
        FaceGlyph(face: character.face, size: 44, kept: locked),
        if (locked)
          Positioned(
            right: -6,
            top: -6,
            child: Icon(Icons.lock, key: ValueKey('lock-${character.id}'), size: 16, color: Colors.amber),
          ),
      ],
    );
    return InkWell(
      key: ValueKey('face-${character.id}'),
      borderRadius: BorderRadius.circular(6),
      onTap: onFaceTap,
      child: Padding(padding: const EdgeInsets.all(6), child: tile),
    );
  }
}
