import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart' show HapticFeedback;

import '../net/models.dart';
import '../net/rules.dart';
import 'character_token.dart';
import 'playback.dart';

const _effectColors = {
  'Damage': Color(0xFFFF5A5F),
  'FixedDamage': Color(0xFF9C1F5B), // sacrificed HP: a cost, not an attack
  'Heal': Color(0xFF7CE38B),
  'Shield': Color(0xFF7FB8FF),
  'Swap': Color(0xFFC08BFF),
  'ApplyStat': Color(0xFF8A5CF6), // buff/debuff: not hostile
  'ApplyState': Color(0xFF2EC4B6), // status: not hostile
};

/// Plays the server's resolve log on a landscape board, two facing columns of [boardSize] cells
/// (the viewer on the left, slot 0 on top), with impact, numbers, shakes and haptics.
/// Display only: every number shown comes from the server's `changes`.
class ResolveGame extends FlameGame with HasTimeScale {
  int viewerIndex;
  double speed = 1;
  bool haptics = true;
  final caption = ValueNotifier<String>('');
  final _tokens = <String, CharacterToken>{};
  final _cellFrames = <CellFrame>[];
  bool _busy = false;

  ResolveGame({this.viewerIndex = 0});

  bool get isPlaying => _busy;

  /// Ids of the characters standing on the board now.
  Set<String> get onBoard => _tokens.keys.toSet();

  @override
  Color backgroundColor() => const Color(0xFF14161F);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
  }

  /// A card fills most of its cell height, so the [boardSize] rows always fit.
  Vector2 get cardSize {
    final h = min(size.y / boardSize * 0.88, size.x / 6 * 1.3);
    return Vector2(h / 1.3, h);
  }

  Vector2 cellCenter(Cell c) {
    final mine = c.playerIndex == viewerIndex;
    final x = size.x * (mine ? 0.18 : 0.82);
    final y = (c.slot + 0.5) * size.y / boardSize;
    return Vector2(x, y);
  }

  /// A dashed frame under every cell (LAYOUT-4), so an empty cell, including one a dead
  /// character has just left (DEAD-1), still reads as a cell.
  void _drawCells() {
    for (final f in _cellFrames) {
      f.removeFromParent();
    }
    _cellFrames.clear();
    for (final pi in [0, 1]) {
      for (var slot = 0; slot < boardSize; slot++) {
        final frame = CellFrame(size: cardSize, center: cellCenter(Cell(pi, slot)));
        _cellFrames.add(frame);
        world.add(frame);
      }
    }
  }

  /// Puts characters on the board without animation.
  void setBoard(List<CharacterView> characters) {
    for (final t in _tokens.values) {
      t.removeFromParent();
    }
    _tokens.clear();
    _drawCells();
    for (final c in characters) {
      final token = CharacterToken(c, isMine: c.position.playerIndex == viewerIndex, cardSize: cardSize, center: cellCenter(c.position));
      _tokens[c.id] = token;
      world.add(token);
    }
  }

  Future<void> playRound(List<CharacterView> before, List<ResolveStep> log) async {
    if (_busy) return;
    _busy = true;
    try {
      timeScale = speed;
      setBoard(before);
      await _wait(0.35);
      for (final step in planRound(before, log)) {
        await _playStep(step);
      }
      caption.value = '';
    } finally {
      _busy = false;
    }
  }

  Future<void> _playStep(StepPlan step) async {
    final actor = _tokens[step.actorId];
    if (actor == null) return;
    final labels = step.effects.map((e) => e.effect).toSet().join(' + ');
    caption.value = step.skipped ? '${actor.character.name} ne peut pas agir' : '${actor.character.name} — $labels';

    if (step.skipped) {
      await _fx(actor, MoveByEffect(Vector2(4, 0), EffectController(duration: 0.05, alternate: true, repeatCount: 2)));
      await _wait(0.15);
      return;
    }

    actor.priority = 10;
    await _fx(actor, ScaleEffect.to(Vector2.all(1.12), EffectController(duration: 0.12, curve: Curves.easeOut)));

    // Only 'Damage' is hostile: FixedDamage is a cost paid, so no lunge.
    final hostile = step.effects.any((e) => e.effect == 'Damage' && !e.fizzled);
    // Lunge toward the opposing column.
    final towardFoe = actor.isMine ? 1.0 : -1.0;
    if (hostile) {
      await _fx(actor, MoveByEffect(Vector2(towardFoe * actor.size.x * 0.35, 0), EffectController(duration: 0.09, curve: Curves.easeIn)));
    }

    // Impact rings on every resolved cell.
    for (final e in step.effects) {
      for (final cell in e.targets) {
        _ring(cellCenter(cell), _effectColors[e.effect] ?? const Color(0xFFFFFFFF));
      }
    }

    // All characters touched by this action react together.
    final byCharacter = <String, List<Beat>>{};
    for (final b in step.beats) {
      byCharacter.putIfAbsent(b.characterId, () => []).add(b);
    }
    final reactions = [for (final e in byCharacter.entries) _react(e.key, e.value, step)];
    final bigHit = step.beats.any((b) => b.kind == BeatKind.damage && b.amount >= 4) ||
        step.beats.any((b) => b.kind == BeatKind.death);
    if (bigHit) {
      unawaited(_hitStop());
      _cameraShake();
    }
    await Future.wait(reactions);
    // DEAD-3: the actor died during its own action and has left the board.
    if (!_tokens.containsKey(step.actorId)) return;

    if (hostile) {
      await _fx(actor, MoveByEffect(Vector2(-towardFoe * actor.size.x * 0.35, 0), EffectController(duration: 0.16, curve: Curves.easeOut)));
    }
    await _fx(actor, ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.12)));
    actor.priority = 0;
    await _wait(0.12);
  }

  Future<void> _react(String id, List<Beat> beats, StepPlan step) async {
    final t = _tokens[id];
    if (t == null) return;
    final after = step.after[id] ?? t.character;
    final futures = <Future<void>>[];
    var dy = 0.0;
    for (final b in beats) {
      switch (b.kind) {
        case BeatKind.damage:
          _haptic(b.amount >= 4 ? HapticFeedback.heavyImpact : HapticFeedback.mediumImpact);
          futures.add(_fx(t, SequenceEffect([
            MoveByEffect(Vector2(-7, 0), EffectController(duration: 0.04)),
            MoveByEffect(Vector2(14, 0), EffectController(duration: 0.06)),
            MoveByEffect(Vector2(-10, 0), EffectController(duration: 0.05)),
            MoveByEffect(Vector2(3, 0), EffectController(duration: 0.04)),
          ])));
          t.body.add(ColorEffect(const Color(0xFFFFFFFF), EffectController(duration: 0.06, alternate: true), opacityTo: 0.9));
          futures.add(_floating(t, '-${b.amount}', const Color(0xFFFF6B6B), dy, big: b.amount >= 4));
        case BeatKind.heal:
          _haptic(HapticFeedback.lightImpact);
          t.body.add(ColorEffect(const Color(0xFF7CE38B), EffectController(duration: 0.18, alternate: true), opacityTo: 0.6));
          futures.add(_floating(t, '+${b.amount}', const Color(0xFF7CE38B), dy));
        case BeatKind.shieldGain:
          t.body.add(ColorEffect(const Color(0xFF7FB8FF), EffectController(duration: 0.18, alternate: true), opacityTo: 0.6));
          futures.add(_floating(t, '+${b.amount}🛡', const Color(0xFF9AD0FF), dy));
        case BeatKind.shieldLoss:
          futures.add(_floating(t, '-${b.amount}🛡', const Color(0xFFB8C4D6), dy));
        case BeatKind.move:
          _haptic(HapticFeedback.selectionClick);
          futures.add(_fx(t, MoveToEffect(cellCenter(b.to!), EffectController(duration: 0.35, curve: Curves.easeInOutCubic))));
        case BeatKind.death:
          futures.add(_leaveBoard(id, t));
      }
      dy += t.size.y * 0.18;
    }
    t.sync(after);
    await Future.wait(futures);
  }

  /// DEAD-1, CELL-6: the character dies and leaves its cell at this step; the cell is left empty.
  Future<void> _leaveBoard(String id, CharacterToken t) async {
    _tokens.remove(id);
    _haptic(HapticFeedback.heavyImpact);
    await _wait(0.15);
    t.showKo();
    await _wait(0.5);
    await _fx(t, ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.25, curve: Curves.easeIn)));
    t.removeFromParent();
  }

  Future<void> _floating(CharacterToken t, String text, Color color, double dy, {bool big = false}) {
    final label = TextComponent(
      text: text,
      textRenderer: textPaint(t.size.x * (big ? 0.38 : 0.28), color: color),
      anchor: Anchor.center,
      position: t.position + Vector2(0, -t.size.y * 0.25 - dy),
      priority: 20,
      scale: Vector2.all(0.4),
    );
    world.add(label);
    label.add(ScaleEffect.to(Vector2.all(big ? 1.25 : 1.0), EffectController(duration: 0.16, curve: Curves.easeOutBack)));
    return _fx(label, MoveByEffect(Vector2(0, -t.size.y * 0.45), EffectController(duration: 0.8, curve: Curves.easeOut)))
        .then((_) => label.removeFromParent());
  }

  void _ring(Vector2 at, Color color) {
    final ring = CircleComponent(
      radius: cardSize.x * 0.3,
      anchor: Anchor.center,
      position: at,
      priority: 5,
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color,
    );
    world.add(ring);
    ring.add(ScaleEffect.to(Vector2.all(1.9), EffectController(duration: 0.35, curve: Curves.easeOut)));
    ring.add(OpacityEffect.fadeOut(EffectController(duration: 0.35), onComplete: ring.removeFromParent));
  }

  void _cameraShake() {
    camera.viewfinder.add(SequenceEffect([
      MoveByEffect(Vector2(6, -4), EffectController(duration: 0.04)),
      MoveByEffect(Vector2(-10, 7), EffectController(duration: 0.05)),
      MoveByEffect(Vector2(6, -5), EffectController(duration: 0.05)),
      MoveByEffect(Vector2(-2, 2), EffectController(duration: 0.04)),
    ]));
  }

  /// A few real milliseconds of near-freeze on big hits: the "weight" of the impact.
  Future<void> _hitStop() async {
    timeScale = speed * 0.08;
    await Future<void>.delayed(const Duration(milliseconds: 70));
    timeScale = speed;
  }

  void _haptic(Future<void> Function() f) {
    if (haptics) f();
  }

  Future<void> _fx(Component target, Effect effect) {
    final done = Completer<void>();
    effect.onComplete = () {
      if (!done.isCompleted) done.complete();
    };
    target.add(effect);
    return done.future;
  }

  /// Waits in game time (affected by speed and hit-stop).
  Future<void> _wait(double seconds) {
    final done = Completer<void>();
    world.add(TimerComponent(period: seconds, removeOnFinish: true, onTick: done.complete));
    return done.future;
  }
}

/// An empty cell: a faint dashed rounded frame, drawn under every cell of the board.
class CellFrame extends PositionComponent {
  CellFrame({required Vector2 size, required Vector2 center})
      : super(size: size, position: center, anchor: Anchor.center, priority: -1);

  static const _dash = 6.0;
  static const _gap = 5.0;
  final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = const Color(0x33FFFFFF);

  late final Path _dashes = _dashed(
    Path()..addRRect(RRect.fromRectAndRadius(size.toRect(), Radius.circular(size.x * 0.12))),
  );

  static Path _dashed(Path outline) {
    final dashes = Path();
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        dashes.addPath(metric.extractPath(d, min(d + _dash, metric.length)), Offset.zero);
      }
    }
    return dashes;
  }

  @override
  void render(Canvas canvas) => canvas.drawPath(_dashes, _paint);
}
