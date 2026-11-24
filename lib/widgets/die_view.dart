import 'package:flutter/material.dart';

import '../net/models.dart';
import 'die_face_tile.dart';

/// Opens the die view of [character] over the board (DIE-1). Close or the darkened background closes it (DIE-2).
///
/// The view shows [character] as it was when it was opened: its ring stays on that face. Faces change only at a
/// roll, and the match screen reloads then.
Future<void> showDieView(BuildContext context, CharacterView character) =>
    showDialog<void>(context: context, builder: (_) => DieView(character: character));

/// The six faces of a character side by side, with its name and base speed, the current face ringed (DIE-1).
///
/// The current face is the card at [CharacterView.faceIndex]: a die can hold identical faces, so only that card is
/// ringed. Faces too tall for the screen scroll, with the scrollbar always shown.
class DieView extends StatefulWidget {
  final CharacterView character;
  const DieView({super.key, required this.character});

  static const priorityReminder = 'La priorité passe avant la vitesse dans l\'ordre de résolution.';

  @override
  State<DieView> createState() => _DieViewState();
}

class _DieViewState extends State<DieView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final character = widget.character;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: 'Dé de ${character.name}',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(character.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 12),
                          Text('vitesse ${character.baseSpeed}', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('die-view-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
                Flexible(
                  // One scrollbar, ours, always shown: the platform's would double it on desktop.
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: Scrollbar(
                      controller: _scroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.only(right: 10),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < character.baseDie.length; i++) ...[
                                if (i > 0) const SizedBox(width: 5),
                                Expanded(child: _card(i, current: i == character.faceIndex)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(DieView.priorityReminder, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(int i, {required bool current}) {
    final card = _FaceCard(face: widget.character.baseDie[i], index: i, current: current);
    return current ? KeyedSubtree(key: const ValueKey('die-face-current'), child: card) : card;
  }
}

/// One face as a narrow vertical card: number and priority bracket, description, then each effect with one chip
/// per part and its targeting grid. The description is cut after four lines; a long press shows it whole.
class _FaceCard extends StatelessWidget {
  final DieFace face;
  final int index;
  final bool current;
  const _FaceCard({required this.face, required this.index, required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = 'Face ${index + 1}: ${face.description}, ${priorityText(face)}${current ? ', face courante' : ''}';
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      child: Tooltip(
        message: face.description,
        triggerMode: TooltipTriggerMode.longPress,
        excludeFromSemantics: true,
        child: Container(
          key: ValueKey('die-face-$index'),
          padding: const EdgeInsets.fromLTRB(6, 2, 4, 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: current ? Border.all(color: Colors.amber, width: 2.5) : Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Number and priority on one line when they fit, the priority under the number otherwise.
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${index + 1}', style: theme.textTheme.labelLarge),
                    Text(priorityText(face), style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              Text(face.description, style: theme.textTheme.bodySmall, maxLines: 4, overflow: TextOverflow.ellipsis),
              for (final e in face.effects) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [for (final part in e.parts) _PartChip(part: part)],
                ),
                const SizedBox(height: 3),
                TargetGrid(groups: e.targets, color: effectColors[e.parts.first.part] ?? Colors.white, cellSize: 8),
              ],
            ],
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: effectColors[part.part] ?? Colors.white24),
        ),
        child: Text(partChipText(part), style: Theme.of(context).textTheme.labelSmall),
      );
}
