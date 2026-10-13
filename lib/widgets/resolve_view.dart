import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/resolve_game.dart';

/// The Flame board with the current action caption on top.
class ResolveView extends StatelessWidget {
  final ResolveGame game;
  const ResolveView({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: GameWidget(game: game)),
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: ValueListenableBuilder<String>(
            valueListenable: game.caption,
            builder: (context, text, _) => AnimatedOpacity(
              opacity: text.isEmpty ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Speed and haptics toggles shared by the demo and live screens.
class PlaybackControls extends StatelessWidget {
  final ResolveGame game;
  final VoidCallback onChanged;
  const PlaybackControls({super.key, required this.game, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<double>(
          segments: const [ButtonSegment(value: 1, label: Text('×1')), ButtonSegment(value: 2, label: Text('×2'))],
          selected: {game.speed},
          onSelectionChanged: (s) {
            game.speed = s.first;
            game.timeScale = s.first;
            onChanged();
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Vibrations',
          icon: Icon(game.haptics ? Icons.vibration : Icons.mobile_off),
          onPressed: () {
            game.haptics = !game.haptics;
            onChanged();
          },
        ),
      ],
    );
  }
}
