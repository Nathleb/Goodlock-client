import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/material.dart' show Colors, FontWeight, Shadow, TextStyle;

import '../net/models.dart';

const allyColor = Color(0xFF2A9D8F);
const enemyColor = Color(0xFFE76F51);

/// Rounded card body; HasPaint so Color/Opacity effects can flash it.
class CardBody extends PositionComponent with HasPaint {
  final Color base;
  CardBody(this.base, {required super.size}) {
    paint.color = base;
  }

  final _border = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0x40FFFFFF);

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect(), Radius.circular(size.x * 0.12));
    canvas.drawRRect(r, paint);
    canvas.drawRRect(r, _border);
  }
}

class _Bar extends PositionComponent with HasPaint {
  _Bar(Color color, {required super.size, super.position}) {
    paint.color = color;
  }
  @override
  void render(Canvas canvas) =>
      canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), Radius.circular(size.y / 2)), paint);
}

TextPaint textPaint(double size, {Color color = Colors.white, FontWeight weight = FontWeight.w700}) => TextPaint(
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        shadows: const [Shadow(blurRadius: 4, color: Color(0xCC000000))],
      ),
    );

/// A character on the board: card, initial as placeholder art, name, HP bar, shield badge.
class CharacterToken extends PositionComponent {
  CharacterView character;
  final bool isMine;
  late final CardBody body;
  late final _Bar _hpBack;
  late final _Bar _hpFill;
  late final TextComponent _hpText;
  late final TextComponent _shieldText;
  late final TextComponent _initial;
  bool _koShown = false;

  CharacterToken(this.character, {required this.isMine, required Vector2 cardSize, required Vector2 center})
      : super(size: cardSize, position: center, anchor: Anchor.center);

  double get _barWidth => size.x * 0.84;

  @override
  Future<void> onLoad() async {
    body = CardBody(isMine ? allyColor : enemyColor, size: size);
    add(body);
    _initial = TextComponent(
      text: character.name.isEmpty ? '?' : character.name[0],
      textRenderer: textPaint(size.x * 0.5, color: const Color(0xE6FFFFFF), weight: FontWeight.w900),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y * 0.42),
    );
    add(_initial);
    add(TextComponent(
      text: character.name,
      textRenderer: textPaint(size.x * 0.15),
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, size.y * 0.05),
    ));
    final barPos = Vector2((size.x - _barWidth) / 2, size.y * 0.82);
    final barSize = Vector2(_barWidth, size.y * 0.07);
    _hpBack = _Bar(const Color(0x66000000), size: barSize, position: barPos);
    _hpFill = _Bar(const Color(0xFF8BE28B), size: barSize.clone(), position: barPos.clone());
    addAll([_hpBack, _hpFill]);
    _hpText = TextComponent(
      text: '',
      textRenderer: textPaint(size.x * 0.13),
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, size.y * 0.8),
    );
    _shieldText = TextComponent(
      text: '',
      textRenderer: textPaint(size.x * 0.14, color: const Color(0xFF9AD0FF)),
      anchor: Anchor.topRight,
      position: Vector2(size.x * 0.95, size.y * 0.22),
    );
    addAll([_hpText, _shieldText]);
    sync(character, animate: false);
  }

  /// Updates HP/shield display; the bar tweens when [animate].
  void sync(CharacterView c, {bool animate = true, double duration = 0.35}) {
    character = c;
    final ratio = c.maxHp == 0 ? 0.0 : (c.hp.clamp(0, c.maxHp) / c.maxHp);
    final target = Vector2(_barWidth * ratio, _hpFill.size.y);
    if (animate) {
      _hpFill.add(SizeEffect.to(target, EffectController(duration: duration, curve: _easeOut)));
    } else {
      _hpFill.size = target;
    }
    _hpFill.paint.color = ratio > 0.5
        ? const Color(0xFF8BE28B)
        : ratio > 0.25
            ? const Color(0xFFF4C95D)
            : const Color(0xFFE85D5D);
    _hpText.text = '${c.hp.clamp(0, 999)}/${c.maxHp}';
    _shieldText.text = c.shield > 0 ? '🛡${c.shield}' : '';
    if (c.isDead && !animate) showKo(instant: true);
  }

  void showKo({bool instant = false}) {
    if (_koShown) return;
    _koShown = true;
    final greyed = const Color(0xFF5A5A66);
    if (instant) {
      body.paint.color = greyed;
      scale = Vector2.all(0.85);
      angle = 0.1;
    } else {
      body.add(ColorEffect(greyed, EffectController(duration: 0.4), opacityTo: 0.85));
      add(ScaleEffect.to(Vector2.all(0.85), EffectController(duration: 0.4, curve: _easeOut)));
      add(RotateEffect.to(0.1, EffectController(duration: 0.4, curve: _easeOut)));
    }
    add(TextComponent(
      text: 'KO',
      textRenderer: textPaint(size.x * 0.3, color: const Color(0xFFFFE066), weight: FontWeight.w900),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y * 0.42),
    ));
  }
}

const _easeOut = Curves.easeOutCubic;
