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
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.style_outlined), selectedIcon: Icon(Icons.style), label: 'Collection'),
          NavigationDestination(icon: Icon(Icons.layers_outlined), selectedIcon: Icon(Icons.layers), label: 'Decks'),
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports), label: 'Jouer'),
        ],
      ),
    );
  }
}
