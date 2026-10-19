import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../game/playback.dart';
import '../game/resolve_game.dart';
import '../net/models.dart';
import '../widgets/resolve_view.dart';

/// Offline: replays a real match recorded from the backend (assets/demo), no server needed.
class ResolveDemoScreen extends StatefulWidget {
  const ResolveDemoScreen({super.key});

  @override
  State<ResolveDemoScreen> createState() => _ResolveDemoScreenState();
}

class _ResolveDemoScreenState extends State<ResolveDemoScreen> {
  final _game = ResolveGame(viewerIndex: 0);
  List<RoundResolved> _rounds = const [];
  int _round = 1; // round 0 only provides the starting board

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = jsonDecode(await rootBundle.loadString('assets/demo/round_resolved.json')) as List;
    setState(() => _rounds = raw.map((j) => RoundResolved.fromJson(j as Json)).toList());
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _play();
  }

  List<CharacterView> _start(int round) =>
      startOfNextRound(_rounds[round - 1].gameState.players.expand((p) => p.team).toList());

  Future<void> _play() async {
    if (_rounds.length < 2 || _game.isPlaying) return;
    setState(() {});
    await _game.playRound(_start(_round), _rounds[_round].resolveLog);
    if (mounted) setState(() {});
  }

  void _next() {
    if (_game.isPlaying) return;
    setState(() => _round = _round + 1 >= _rounds.length ? 1 : _round + 1);
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final total = _rounds.length - 1;
    if (_rounds.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return GameScreenFrame(
      game: _game,
      title: total > 0 ? 'Démo — round $_round / $total' : 'Démo',
      controls: [
        PlaybackControls(game: _game, onChanged: () => setState(() {})),
        const SizedBox(width: 8),
        IconButton.filledTonal(tooltip: 'Rejouer', icon: const Icon(Icons.replay), onPressed: _game.isPlaying ? null : _play),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _game.isPlaying ? null : _next,
          icon: const Icon(Icons.skip_next),
          label: const Text('Round suivant'),
        ),
      ],
    );
  }
}
