import 'package:flutter/material.dart';

import '../app/session.dart';
import '../net/api.dart';
import '../net/models.dart';
import 'collection_screen.dart';

const deckSize = 7;

class DecksScreen extends StatefulWidget {
  final AppSession session;
  const DecksScreen({super.key, required this.session});

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  List<Deck>? _decks;
  List<CatalogCharacter> _collection = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final api = widget.session.api!;
      final results = await Future.wait([api.decks(), api.collection()]);
      setState(() {
        _decks = results[0] as List<Deck>;
        _collection = results[1] as List<CatalogCharacter>;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _edit([Deck? deck]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DeckEditorScreen(session: widget.session, collection: _collection, deck: deck),
    ));
    if (saved == true) _reload();
  }

  Future<void> _delete(Deck deck) async {
    try {
      await widget.session.api!.deleteDeck(deck.id);
      _reload();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: TextButton(onPressed: _reload, child: Text('Erreur : $_error\nRéessayer')));
    final decks = _decks;
    if (decks == null) return const Center(child: CircularProgressIndicator());
    final names = {for (final c in _collection) c.id: c.name};
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau deck'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            for (final d in decks)
              Card(
                child: ListTile(
                  minVerticalPadding: 14,
                  title: Text(d.name),
                  subtitle: Text(d.characterIds.map((id) => names[id] ?? id).join(' · ')),
                  onTap: () => _edit(d),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(d)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DeckEditorScreen extends StatefulWidget {
  final AppSession session;
  final List<CatalogCharacter> collection;
  final Deck? deck;
  const DeckEditorScreen({super.key, required this.session, required this.collection, this.deck});

  @override
  State<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _DeckEditorScreenState extends State<DeckEditorScreen> {
  late final _name = TextEditingController(text: widget.deck?.name ?? 'Mon deck');
  late final _picked = <String>[...?widget.deck?.characterIds];
  bool _saving = false;

  void _toggle(String id) => setState(() {
        if (_picked.contains(id)) {
          _picked.remove(id);
        } else if (_picked.length < deckSize) {
          _picked.add(id);
        }
      });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = widget.session.api!;
      if (widget.deck == null) {
        await api.createDeck(_name.text, _picked);
      } else {
        await api.updateDeck(widget.deck!.id, _name.text, _picked);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // The server is the judge of deck rules; show its reasons as-is.
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final full = _picked.length == deckSize;
    return Scaffold(
      appBar: AppBar(title: Text(widget.deck == null ? 'Nouveau deck' : 'Modifier le deck')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom'), maxLength: 30),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(value: _picked.length / deckSize, minHeight: 6, borderRadius: BorderRadius.circular(3)),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('${_picked.length} / $deckSize personnages${full ? '' : ' — touche pour ajouter'}'),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.72, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: widget.collection.length,
              itemBuilder: (context, i) {
                final c = widget.collection[i];
                return GestureDetector(
                  onLongPress: () => showCharacterSheet(context, c),
                  child: CharacterCard(character: c, selected: _picked.contains(c.id), onTap: () => _toggle(c.id)),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: full && !_saving ? _save : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Enregistrer'),
          ),
        ),
      ),
    );
  }
}
