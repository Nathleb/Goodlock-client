import 'package:flutter/material.dart';

import '../app/session.dart';
import 'deck_choice_dialog.dart';
import 'human_match_screen.dart';
import 'live_match_screen.dart';

class PlayScreen extends StatelessWidget {
  final AppSession session;
  const PlayScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    Widget entry(
      IconData icon,
      String title,
      String subtitle,
      Widget Function() page,
    ) => Card(
      child: ListTile(
        minVerticalPadding: 20,
        leading: Icon(icon, size: 36),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => page())),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            minVerticalPadding: 20,
            leading: const Icon(Icons.person_outline, size: 36),
            title: const Text('Jouer contre un bot'),
            subtitle: const Text(
              'Tu joues un vrai match sur le serveur ; un bot joue en face.',
            ),
            onTap: () => _playVsBot(context),
          ),
        ),
        entry(
          Icons.smart_toy_outlined,
          'Match en direct (2 bots)',
          'Deux bots jouent sur le serveur ; tu regardes les rounds animés en temps réel.',
          () => LiveMatchScreen(session: session),
        ),
      ],
    );
  }

  Future<void> _playVsBot(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final decks = await session.api!.decks();
      if (!context.mounted) return;
      final deck = await chooseDeck(context, decks);
      if (deck == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Crée d\'abord un deck.')),
        );
        return;
      }
      navigator.push(
        MaterialPageRoute(
          builder: (_) => HumanMatchScreen(session: session, deckId: deck.id),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Échec : $e')));
    }
  }
}
