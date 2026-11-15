import 'package:flutter/material.dart';

import '../net/models.dart';

/// Which deck to bring to a match: the only one without asking, a short list when there are several,
/// nothing when the player has none.
Future<Deck?> chooseDeck(BuildContext context, List<Deck> decks) async {
  if (decks.isEmpty) return null;
  if (decks.length == 1) return decks.first;
  return showDialog<Deck>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Avec quel deck ?'),
      children: [
        for (final deck in decks)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(deck),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(deck.name)),
          ),
      ],
    ),
  );
}
