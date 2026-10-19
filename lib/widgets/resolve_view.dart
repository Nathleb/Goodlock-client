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
        // The caption sits in the free centre band, between the two columns.
        Positioned(
          left: 0,
          right: 0,
          top: 40,
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.5,
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
          ),
        ),
      ],
    );
  }
}

/// Full-screen landscape frame for a game scene: the board takes the whole screen, a back button
/// top left, the title top centre, [center] (e.g. a result) in the middle and [controls] along
/// the bottom of the free centre band.
class GameScreenFrame extends StatelessWidget {
  final ResolveGame game;
  final String title;
  final Widget? center;
  final List<Widget> controls;
  const GameScreenFrame({super.key, required this.game, required this.title, this.center, this.controls = const []});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: ResolveView(game: game)),
            const Positioned(left: 4, top: 4, child: BackButton()),
            Positioned(
              left: 0,
              right: 0,
              top: 12,
              child: Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge),
            ),
            if (center != null) Center(child: center),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: controls)),
            ),
          ],
        ),
      ),
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
