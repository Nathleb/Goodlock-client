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
///
/// The tokens shrink to fit the width, down to a touch target; past that, the row scrolls and follows the playhead.
/// A playhead loaded with another notch count than [timeline] is drawn clamped to the timeline's notches.
class TimelineBar extends StatefulWidget {
  final RoundTimeline timeline;
  final Playhead playhead;

  /// The viewer's player index: my tokens and the opponent's have two colours.
  final int me;
  const TimelineBar({super.key, required this.timeline, required this.playhead, required this.me});

  static const height = 68.0;

  @override
  State<TimelineBar> createState() => _TimelineBarState();
}

class _TimelineBarState extends State<TimelineBar> {
  static const _maxSlot = 52.0;

  /// The narrowest slot: a token stays a touch target.
  static const _minSlot = 44.0;

  /// Room for the playhead before the first token and after the last one.
  static const _pad = 10.0;
  static const _slide = Duration(milliseconds: 300);

  final _scroll = ScrollController();
  final _rowKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playhead = widget.playhead;
    return ListenableBuilder(
      listenable: playhead,
      builder: (context, _) => SizedBox(
        height: TimelineBar.height,
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('timeline-play'),
              tooltip: playhead.playing ? 'Pause' : 'Lecture',
              icon: Icon(playhead.playing ? Icons.pause : Icons.play_arrow),
              onPressed: playhead.togglePlay,
            ),
            IconButton(
              key: const ValueKey('timeline-fast-forward'),
              tooltip: 'Fin du round',
              icon: const Icon(Icons.fast_forward),
              onPressed: playhead.fastForward,
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) => _track(constraints.maxWidth - 2 * _pad)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _track(double width) {
    final timeline = widget.timeline;
    final playhead = widget.playhead;
    final tokens = timeline.tokens;
    final fit = tokens.isEmpty ? _maxSlot : min(_maxSlot, width / tokens.length);
    final scrolls = fit < _minSlot;
    final slot = scrolls ? _minSlot : fit;
    final length = slot * tokens.length;
    final names = {for (final c in timeline.boards.first) c.id: c.name};
    final notch = playhead.notch.clamp(0, timeline.notchCount - 1);
    final current = timeline.stepAt(notch);
    final playheadX = notch / (timeline.notchCount - 1) * length;
    // From the global position: a drag's local position keeps the offset of the row when it started, and the row
    // may have scrolled since.
    void seekAt(Offset global) {
      final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && length > 0) playhead.seek(box.globalToLocal(global).dx / length);
    }

    final track = GestureDetector(
      key: const ValueKey('timeline-track'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) => seekAt(d.globalPosition),
      onHorizontalDragUpdate: (d) => seekAt(d.globalPosition),
      child: Stack(
        key: _rowKey,
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
                  team: tokens[i].team == widget.me ? myTeamColor : theirTeamColor,
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
    if (!scrolls) return Padding(padding: const EdgeInsets.symmetric(horizontal: _pad), child: track);
    _follow(playheadX + _pad);
    return SingleChildScrollView(
      key: const ValueKey('timeline-scroll'),
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: _pad),
      child: SizedBox(width: length, child: track),
    );
  }

  /// Once the frame is laid out, scrolls the row just enough to keep the playhead ([x], in the scrolled content)
  /// one slot inside the view. Dragging to an edge of the view thus scrolls the row along.
  void _follow(double x) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      final view = position.viewportDimension;
      final offset = position.pixels;
      final target = x < offset + _minSlot
          ? x - _minSlot
          : x > offset + view - _minSlot
          ? x - view + _minSlot
          : offset;
      final clamped = target.clamp(0.0, position.maxScrollExtent);
      if (clamped != offset) _scroll.jumpTo(clamped);
    });
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

  /// What a screen reader says (F20): the character, its face, and the state of its action.
  String get _label {
    final face = token.face;
    final faceText = face.description.isNotEmpty
        ? face.description
        : (face.effects.isEmpty ? 'face vide' : 'valeur ${faceGlyphText(face)}');
    final why = switch (token.status) {
      TokenStatus.stunned => 'étourdi',
      TokenStatus.dead => 'mort',
      TokenStatus.unplayed => 'non joué',
      TokenStatus.plays || TokenStatus.blank => null,
    };
    final progress = current ? 'en cours' : (why != null ? null : (played ? 'joué' : 'à venir'));
    return [name, faceText, ?why, ?progress].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final id = token.characterId;
    final stunned = token.status == TokenStatus.stunned;
    final dead = token.status == TokenStatus.dead;
    final unplayed = token.status == TokenStatus.unplayed;
    final opacity = unplayed ? 0.5 : (played ? 0.4 : (stunned || dead ? 0.6 : 1.0));
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      selected: current,
      label: _label,
      onTap: onTap,
      child: GestureDetector(
        key: ValueKey('token-$id'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: SizedBox(
          width: _TimelineBarState._minSlot,
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
              if (stunned) _mark(Icons.flash_off, 'token-stunned-$id', Colors.amber),
              if (dead) _mark(Icons.close, 'token-dead-$id', Colors.redAccent),
              // The match was decided before this action (END-1).
              if (unplayed) _mark(Icons.flag_outlined, 'token-unplayed-$id', Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mark(IconData icon, String key, Color color) =>
      Positioned(right: -4, top: -4, child: Icon(icon, key: ValueKey(key), size: 16, color: color));
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
