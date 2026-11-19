import 'dart:math';

import 'package:flutter/material.dart';

import '../game/playhead.dart';
import '../game/round_timeline.dart';
import 'face_glyph.dart';

/// The colours of the viewer's team and of the opponent's on the timeline (TL-1).
const myTeamColor = Color(0xFF2A9D8F);
const theirTeamColor = Color(0xFFE76F51);

/// The bottom band of the match screen (LAYOUT-1): play/pause and fast forward, then the round as a row of
/// tokens in resolution order (TL-1), with the playhead on its notch (TL-4). Tapping a token or dragging along
/// the track moves the playhead (TL-6); when the order changes, the tokens slide to their new rank (TL-2).
class TimelineBar extends StatelessWidget {
  final RoundTimeline timeline;
  final Playhead playhead;

  /// The viewer's player index: my tokens and the opponent's have two colours.
  final int me;
  const TimelineBar({super.key, required this.timeline, required this.playhead, required this.me});

  static const height = 68.0;
  static const _maxSlot = 52.0;
  static const _slide = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playhead,
      builder: (context, _) => SizedBox(
        height: height,
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('timeline-play'),
              icon: Icon(playhead.playing ? Icons.pause : Icons.play_arrow),
              onPressed: playhead.togglePlay,
            ),
            IconButton(
              key: const ValueKey('timeline-fast-forward'),
              icon: const Icon(Icons.fast_forward),
              onPressed: playhead.fastForward,
            ),
            Expanded(
              child: Padding(
                // Room for the playhead before the first token and after the last one.
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: LayoutBuilder(builder: (context, constraints) => _track(constraints.maxWidth)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _track(double width) {
    final tokens = timeline.tokens;
    final slot = tokens.isEmpty ? _maxSlot : min(_maxSlot, width / tokens.length);
    final length = slot * tokens.length;
    final names = {for (final c in timeline.boards.first) c.id: c.name};
    final notch = playhead.notch.clamp(0, timeline.notchCount - 1);
    final current = timeline.stepAt(notch);
    final playheadX = notch / (timeline.notchCount - 1) * length;
    void seekAt(double dx) {
      if (length > 0) playhead.seek(dx / length);
    }

    return GestureDetector(
      key: const ValueKey('timeline-track'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) => seekAt(d.localPosition.dx),
      onHorizontalDragUpdate: (d) => seekAt(d.localPosition.dx),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < tokens.length; i++)
            AnimatedPositioned(
              key: ValueKey(tokens[i].characterId),
              duration: _slide,
              curve: Curves.easeInOut,
              left: i * slot,
              top: 0,
              bottom: 0,
              width: slot,
              child: Center(
                child: _Token(
                  token: tokens[i],
                  name: names[tokens[i].characterId] ?? '',
                  team: tokens[i].team == me ? myTeamColor : theirTeamColor,
                  played: i < notch - 1,
                  current: i == current,
                  onTap: () => playhead.seekToNotch(i + 1),
                ),
              ),
            ),
          Positioned(
            key: const ValueKey('timeline-playhead'),
            left: playheadX - 6,
            top: 0,
            bottom: 0,
            width: 12,
            child: const IgnorePointer(child: CustomPaint(painter: _PlayheadPainter())),
          ),
        ],
      ),
    );
  }
}

/// One action of the round (TL-1), with its state (TL-3).
class _Token extends StatelessWidget {
  final TimelineToken token;
  final String name;
  final Color team;
  final bool played;
  final bool current;
  final VoidCallback onTap;
  const _Token({
    required this.token,
    required this.name,
    required this.team,
    required this.played,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final id = token.characterId;
    final stunned = token.status == TokenStatus.stunned;
    final dead = token.status == TokenStatus.dead;
    final opacity = played ? 0.4 : (stunned || dead ? 0.6 : 1.0);
    return GestureDetector(
      key: ValueKey('token-$id'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 60,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: opacity,
                child: Container(
                  decoration: BoxDecoration(
                    color: team.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: team, width: 2),
                  ),
                  foregroundDecoration: dead
                      ? BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8))
                      : null,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaceGlyph(face: token.face, size: 24),
                      const SizedBox(height: 3),
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: team,
                        child: Text(
                          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (current)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: ValueKey('token-current-$id'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ),
            if (stunned)
              Positioned(
                right: -4,
                top: -4,
                child: Icon(Icons.flash_off, key: ValueKey('token-stunned-$id'), size: 16, color: Colors.amber),
              ),
            if (dead)
              Positioned(
                right: -4,
                top: -4,
                child: Icon(Icons.close, key: ValueKey('token-dead-$id'), size: 16, color: Colors.redAccent),
              ),
          ],
        ),
      ),
    );
  }
}

/// The playhead (TL-4): a small triangle above a thin line across the track.
class _PlayheadPainter extends CustomPainter {
  const _PlayheadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.amberAccent;
    final mid = size.width / 2;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(mid, 8)
        ..close(),
      paint,
    );
    canvas.drawRect(Rect.fromLTWH(mid - 1, 0, 2, size.height), paint);
  }

  @override
  bool shouldRepaint(_PlayheadPainter oldDelegate) => false;
}
