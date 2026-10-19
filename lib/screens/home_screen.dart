import 'package:flutter/material.dart';

import '../app/session.dart';
import 'collection_screen.dart';
import 'decks_screen.dart';
import 'login_screen.dart';
import 'play_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppSession session;
  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 2;

  @override
  Widget build(BuildContext context) {
    final pages = [
      CollectionScreen(session: widget.session),
      DecksScreen(session: widget.session),
      PlayScreen(session: widget.session),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(['Collection', 'Decks', 'Jouer'][_tab]),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout),
            onPressed: () {
              widget.session.signOut();
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen(session: widget.session)));
            },
          ),
        ],
      ),
      // Landscape: the navigation sits on the side, the height goes to the content.
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.style_outlined), selectedIcon: Icon(Icons.style), label: Text('Collection')),
              NavigationRailDestination(icon: Icon(Icons.layers_outlined), selectedIcon: Icon(Icons.layers), label: Text('Decks')),
              NavigationRailDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports), label: Text('Jouer')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: IndexedStack(index: _tab, children: pages)),
        ],
      ),
    );
  }
}
