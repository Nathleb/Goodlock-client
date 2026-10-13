import 'package:flutter/material.dart';

import '../app/session.dart';
import 'live_match_screen.dart';
import 'resolve_demo_screen.dart';

class PlayScreen extends StatelessWidget {
  final AppSession session;
  const PlayScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    Widget entry(IconData icon, String title, String subtitle, Widget Function() page) => Card(
          child: ListTile(
            minVerticalPadding: 20,
            leading: Icon(icon, size: 36),
            title: Text(title),
            subtitle: Text(subtitle),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page())),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        entry(Icons.smart_toy_outlined, 'Match en direct (2 bots)', 'Deux bots jouent sur le serveur ; tu regardes les rounds animés en temps réel.',
            () => LiveMatchScreen(session: session)),
        entry(Icons.movie_outlined, 'Démo Resolve hors ligne', 'Rejoue un vrai match enregistré, sans serveur.', () => const ResolveDemoScreen()),
      ],
    );
  }
}
