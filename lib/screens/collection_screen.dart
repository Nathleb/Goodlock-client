import 'package:flutter/material.dart';

import '../app/session.dart';
import '../net/models.dart';
import '../widgets/die_face_tile.dart';

class CollectionScreen extends StatefulWidget {
  final AppSession session;
  const CollectionScreen({super.key, required this.session});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late Future<List<CatalogCharacter>> _future = widget.session.api!.collection();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CatalogCharacter>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _future = widget.session.api!.collection()),
              child: Text('Erreur : ${snap.error}\nRéessayer'),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final chars = snap.data!;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.72, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: chars.length,
          itemBuilder: (context, i) => CharacterCard(character: chars[i], onTap: () => showCharacterSheet(context, chars[i])),
        );
      },
    );
  }
}

class CharacterCard extends StatelessWidget {
  final CatalogCharacter character;
  final VoidCallback? onTap;
  final bool selected;
  const CharacterCard({super.key, required this.character, this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? const Color(0xFF2A9D8F) : const Color(0xFF232634),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Text(character.name[0], style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900)),
                ),
              ),
              Text(character.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Text('❤ ${character.maxHp}'),
                Text('⚡ ${character.baseSpeed}'),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

void showCharacterSheet(BuildContext context, CatalogCharacter c) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text(c.name, style: Theme.of(context).textTheme.headlineSmall),
          Text('PV ${c.maxHp} · vitesse ${c.baseSpeed}'),
          const SizedBox(height: 12),
          for (var i = 0; i < c.baseDie.length; i++) DieFaceTile(face: c.baseDie[i], index: i),
        ],
      ),
    ),
  );
}
