import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../app/session.dart';
import '../game/resolve_game.dart';
import '../net/bot.dart';
import '../net/models.dart';
import '../widgets/resolve_view.dart';

/// Live: two bots play on the real server; we watch bot A's seat and animate every round
/// from the server's own events (deck choice, team preview, placement, combat).
class LiveMatchScreen extends StatefulWidget {
  final AppSession session;
  const LiveMatchScreen({super.key, required this.session});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  final _game = ResolveGame();
  final _queue = Queue<(List<CharacterView>, List<ResolveStep>)>();
  final _subs = <StreamSubscription<Object?>>[];
  Bot? _a;
  Bot? _b;
  String _status = 'Connexion des bots…';
  GameStateView? _lastState;
  GameOver? _over;
  int _rounds = 0;
  bool _draining = false;

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
      _game.viewerIndex = a.me;

      _subs.add(a.socket.states.listen((gs) {
        _lastState = gs;
        _set(_describe(gs));
      }));
      _subs.add(a.socket.resolved.listen((r) {
        // The state just before this event is this round's KEEP board (shields already reset).
        final start = _lastState?.players.expand((p) => p.team).toList() ?? const <CharacterView>[];
        _rounds++;
        _queue.add((start, r.resolveLog));
        _drain();
      }));
      _subs.add(a.socket.gameOver.listen((o) => setState(() => _over = o)));
      a.socket.startGame();
    } catch (e) {
      _set('Échec : $e');
    }
  }

  String _describe(GameStateView gs) => switch (gs.phase) {
        Phase.selection => 'Team preview : chaque bot garde 5 de ses 7',
        Phase.placement => 'Placement (équipe adverse cachée)',
        Phase.keep => 'Round ${gs.currentRound + 1} — dés (relances : ${gs.rollsLeft})',
        _ => gs.phase.name,
      };

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    while (_queue.isNotEmpty && mounted) {
      final (start, log) = _queue.removeFirst();
      if (start.isEmpty) continue;
      await _game.playRound(start, log);
    }
    _draining = false;
    if (mounted) setState(() {});
  }

  void _set(String s) {
    if (mounted) setState(() => _status = s);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _a?.dispose();
    _b?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final over = _over;
    final finished = over != null && !_draining && _queue.isEmpty;
    final me = _a?.me ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text('Match en direct — rounds : $_rounds')),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(8), child: Text(_status)),
          Expanded(child: ResolveView(game: _game)),
          if (finished)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                over.isDraw ? 'Égalité' : (over.winner == me ? 'Victoire (${over.reason})' : 'Défaite (${over.reason})'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [PlaybackControls(game: _game, onChanged: () => setState(() {}))]),
        ),
      ),
    );
  }
}
