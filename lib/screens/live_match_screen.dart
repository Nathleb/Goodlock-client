import 'package:flutter/material.dart';

import '../app/session.dart';
import '../game/human_match_controller.dart';
import '../net/bot.dart';
import 'spectator_match_view.dart';

/// Live: two bots play on the real server; we watch bot A's seat. The bots play deck choice, team preview and
/// placement; every round is replayed from the server's own events on the match screen ([SpectatorMatchView]).
class LiveMatchScreen extends StatefulWidget {
  final AppSession session;
  const LiveMatchScreen({super.key, required this.session});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  Bot? _a;
  Bot? _b;
  HumanMatchController? _controller;
  String _status = 'Connexion des bots…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final server = widget.session.serverUrl;
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    try {
      final a = _a = Bot('liveA_$stamp', server);
      final b = _b = Bot('liveB_$stamp', server);
      await a.setUp();
      await b.setUp();
      _set('Room et choix des decks…');
      await seatBots(a, b);
      if (!mounted) return;
      setState(() => _controller = HumanMatchController(a.socket, me: a.me));
      a.socket.startGame();
    } catch (e) {
      _set('Échec : $e');
    }
  }

  void _set(String s) {
    if (mounted) setState(() => _status = s);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _a?.dispose();
    _b?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      body: controller == null
          ? SafeArea(
              child: Stack(
                children: [
                  const Positioned(left: 4, top: 4, child: BackButton()),
                  Center(child: Text(_status)),
                ],
              ),
            )
          : SpectatorMatchView(controller: controller, onLeave: () => Navigator.of(context).pop()),
    );
  }
}
