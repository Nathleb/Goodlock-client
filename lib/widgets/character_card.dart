import 'package:flutter/material.dart';

import '../net/models.dart';
import 'face_glyph.dart';

/// A character of a deck (CHAR-1): its name, max HP, base speed and its six faces in miniature.
/// Tappable when [onTap] is given; [selected] draws it as kept.
class CharacterCard extends StatelessWidget {
  final CatalogCharacter character;
  final bool selected;
  final VoidCallback? onTap;
  const CharacterCard({super.key, required this.character, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(character.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                  ),
                  if (selected) Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
                ],
              ),
              Text('PV ${character.maxHp} · vitesse ${character.baseSpeed}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [for (final f in character.baseDie) FaceGlyph(face: f, size: 20)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
