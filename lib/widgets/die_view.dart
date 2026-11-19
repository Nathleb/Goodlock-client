import 'package:flutter/material.dart';

import '../net/models.dart';
import 'die_face_tile.dart';

/// Opens the die view of [character] over the board (DIE-1). Close or the darkened background closes it (DIE-2).
Future<void> showDieView(BuildContext context, CharacterView character) =>
    showDialog<void>(context: context, builder: (_) => DieView(character: character));

/// The six faces of a character side by side, with its name and base speed, the current face ringed (DIE-1).
class DieView extends StatelessWidget {
  final CharacterView character;
  const DieView({super.key, required this.character});

  static const priorityReminder = 'La priorité passe avant la vitesse dans l\'ordre de résolution.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Faces are compared by value: when several equal the current one, the first is ringed.
    final current = character.baseDie.indexOf(character.face);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(character.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 12),
                  Text('vitesse ${character.baseSpeed}', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey('die-view-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 8),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < character.baseDie.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(child: _ringed(i == current, _FaceCard(face: character.baseDie[i], index: i, current: i == current))),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(priorityReminder, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _ringed(bool current, Widget card) =>
      current ? KeyedSubtree(key: const ValueKey('die-face-current'), child: card) : card;
}

/// One face as a narrow vertical card: number, description, priority bracket, then each effect with one chip per
/// part and its targeting grid.
class _FaceCard extends StatelessWidget {
  final DieFace face;
  final int index;
  final bool current;
  const _FaceCard({required this.face, required this.index, required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('die-face-$index'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: current ? Border.all(color: Colors.amber, width: 2.5) : Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${index + 1}', style: theme.textTheme.labelLarge),
          Text(face.description, style: theme.textTheme.bodySmall),
          Text(priorityText(face), style: theme.textTheme.labelSmall),
          for (final e in face.effects) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [for (final part in e.parts) _PartChip(part: part)],
            ),
            const SizedBox(height: 4),
            TargetGrid(groups: e.targets, color: effectColors[e.parts.first.part] ?? Colors.white),
          ],
        ],
      ),
    );
  }
}

/// A compact chip for one part, outlined in the part's colour.
class _PartChip extends StatelessWidget {
  final FacePart part;
  const _PartChip({required this.part});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: effectColors[part.part] ?? Colors.white24),
        ),
        child: Text(partChipText(part), style: Theme.of(context).textTheme.labelSmall),
      );
}
