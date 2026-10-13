import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/playback.dart';
import 'package:goodlock_app/net/models.dart';

const _face = DieFace('f', 0, []);

CharacterView ch(String id, {int hp = 10, int shield = 0, int pi = 0, int slot = 0}) => CharacterView(
      id: id,
      catalogId: id,
      name: id,
      hp: hp,
      maxHp: 10,
      shield: shield,
      baseSpeed: 1,
      baseDie: const [_face, _face, _face, _face, _face, _face],
      face: _face,
      isFaceLocked: false,
      position: Cell(pi, slot),
    );

ResolveStep step(String actor, List<CharacterView> after, {bool skipped = false, List<ResolvedEffect> effects = const []}) =>
    ResolveStep(actor, skipped, effects, [for (final c in after) ResolveChange(c.id, c)]);

void main() {
  final a = ch('a');
  final b = ch('b', pi: 1, hp: 10, shield: 3);

  test('damage that breaks a shield yields shield loss then hp damage', () {
    final plan = planRound([a, b], [step('a', [ch('b', pi: 1, hp: 6, shield: 0)])]);
    final beats = plan.single.beats;
    expect(plan.single.actorId, 'a');
    expect(beats.map((x) => x.kind), [BeatKind.shieldLoss, BeatKind.damage]);
    expect(beats.map((x) => x.amount), [3, 4]);
    expect(beats.every((x) => x.characterId == 'b'), isTrue);
  });

  test('heal and shield gain', () {
    final hurt = ch('a', hp: 4);
    final plan = planRound([hurt], [step('a', [ch('a', hp: 7, shield: 2)])]);
    expect(plan.single.beats.map((x) => (x.kind, x.amount)), [(BeatKind.heal, 3), (BeatKind.shieldGain, 2)]);
  });

  test('a swap moves both characters to their new cells', () {
    final x = ch('x', slot: 0), y = ch('y', slot: 1);
    final plan = planRound([x, y], [step('x', [ch('x', slot: 1), ch('y', slot: 0)])]);
    expect(plan.single.beats.map((b) => (b.kind, b.characterId, b.to)), [
      (BeatKind.move, 'x', const Cell(0, 1)),
      (BeatKind.move, 'y', const Cell(0, 0)),
    ]);
  });

  test('a lethal hit adds a death beat after the damage', () {
    final plan = planRound([a, ch('b', pi: 1, hp: 2)], [step('a', [ch('b', pi: 1, hp: 0)])]);
    expect(plan.single.beats.map((x) => x.kind), [BeatKind.damage, BeatKind.death]);
  });

  test('skipped steps are kept, flagged, with no beats', () {
    final plan = planRound([a], [step('a', const [], skipped: true)]);
    expect(plan.single.skipped, isTrue);
    expect(plan.single.beats, isEmpty);
  });

  test('state carries over between steps', () {
    final plan = planRound([a, b], [
      step('a', [ch('b', pi: 1, hp: 10, shield: 1)]),
      step('a', [ch('b', pi: 1, hp: 8, shield: 0)]),
    ]);
    expect(plan[1].beats.map((x) => (x.kind, x.amount)), [(BeatKind.shieldLoss, 1), (BeatKind.damage, 2)]);
  });

  test('replaying a recorded round from the previous state lands on the recorded end state', () {
    final raw = (jsonDecode(File('test/fixtures/round_resolved.json').readAsStringSync()) as List)
        .map((j) => RoundResolved.fromJson(j as Json))
        .toList();
    for (var i = 1; i < raw.length; i++) {
      // Between rounds the server only rerolls dice, so the previous end state is this round's start.
      final before = raw[i - 1].gameState.players.expand((p) => p.team).toList();
      final end = replayHp(before, raw[i].resolveLog);
      for (final c in raw[i].gameState.players.expand((p) => p.team)) {
        expect(end[c.id], (c.hp, c.shield), reason: '${c.name} after round ${i + 1}');
      }
    }
  });
}
