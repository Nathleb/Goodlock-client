import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/round_timeline.dart';
import 'package:goodlock_app/net/models.dart';

import '../helpers/builders.dart';

const hit = DieFace('hit', 1, [
  FaceEffect(
    [
      TargetGroup('ENEMY', 'RELATIVE', [0]),
    ],
    [FacePart('Damage', 5)],
  ),
]);

ResolveStep step(String actor, List<CharacterView> after, {bool skipped = false}) =>
    ResolveStep(actor, skipped, const [], [for (final c in after) ResolveChange(c.id, c)], unplayed: false);

/// A step the decided match never reached: skipped, with no effects and no changes.
ResolveStep unplayed(String actor) => ResolveStep(actor, true, const [], const [], unplayed: true);

List<(String, int, int, Cell)> summary(List<CharacterView> board) => [
  for (final c in board) (c.id, c.hp, c.shield, c.position),
];

void main() {
  group('TL-1: tokens', () {
    test('TL-1: one token per step of the log, in log order, with the face and team of the actor at the start', () {
      final a = character('a', side: 0, slot: 0, face: hit);
      final b = character('b', side: 1, slot: 0);
      final timeline = RoundTimeline.build([a, b], [step('b', const []), step('a', const [])]);

      expect(timeline.tokens.map((t) => (t.characterId, t.face, t.team)), [('b', blankFace, 1), ('a', hit, 0)]);
    });
  });

  group('TL-3: token status', () {
    test('TL-3: an action that is not skipped plays when its face has effects, is blank otherwise', () {
      final a = character('a', side: 0, slot: 0, face: hit);
      final b = character('b', side: 1, slot: 0);
      final timeline = RoundTimeline.build([a, b], [step('a', const []), step('b', const [])]);

      expect(timeline.tokens.map((t) => t.status), [TokenStatus.plays, TokenStatus.blank]);
    });

    test('TL-3: a skipped action of a living character is stunned, even with a blank face', () {
      final a = character('a', side: 0, slot: 0, face: hit);
      final b = character('b', side: 1, slot: 0);
      final timeline = RoundTimeline.build(
        [a, b],
        [step('a', const [], skipped: true), step('b', const [], skipped: true)],
      );

      expect(timeline.tokens.map((t) => t.status), [TokenStatus.stunned, TokenStatus.stunned]);
    });

    test('TL-3: the skipped action of a character killed earlier in the round is dead', () {
      final a = character('a', side: 0, slot: 0, face: hit);
      final b = character('b', side: 1, slot: 0, hp: 3, face: hit);
      final timeline = RoundTimeline.build(
        [a, b],
        [
          step('a', [character('b', side: 1, slot: 0, hp: 0, face: hit)]),
          step('b', const [], skipped: true),
        ],
      );

      expect(timeline.tokens.map((t) => t.status), [TokenStatus.plays, TokenStatus.dead]);
    });

    test('TL-3: a character is judged on the state before its own step, not after it', () {
      final a = character('a', side: 0, slot: 0, face: hit);
      final timeline = RoundTimeline.build(
        [a],
        [
          step('a', [character('a', side: 0, slot: 0, hp: 0, face: hit)], skipped: true),
        ],
      );

      expect(timeline.tokens.single.status, TokenStatus.stunned);
    });

    test('TL-3, END-1: a step the decided match never reached is unplayed, whether its actor lives or not', () {
      final a = character('a', side: 0, slot: 0, face: hit);
      final b = character('b', side: 1, slot: 0, hp: 3, face: hit);
      final timeline = RoundTimeline.build(
        [a, b],
        [
          step('a', [character('b', side: 1, slot: 0, hp: 0, face: hit)]),
          unplayed('b'),
          unplayed('a'),
        ],
      );

      expect(timeline.tokens.map((t) => t.status), [TokenStatus.plays, TokenStatus.unplayed, TokenStatus.unplayed]);
    });
  });

  group('TL-4: boards', () {
    final a = character('a', side: 0, slot: 0, face: hit);
    final b = character('b', side: 1, slot: 0, hp: 10, shield: 4);
    final c = character('c', side: 1, slot: 1);
    final log = [
      step('a', [character('b', side: 1, slot: 0, hp: 9, shield: 0)]),
      step('c', [character('c', side: 1, slot: 0), character('b', side: 1, slot: 1, hp: 9, shield: 2)]),
    ];
    late final timeline = RoundTimeline.build([a, b, c], log);

    test('TL-4: one notch before any action, one per action, one for the end of the round', () {
      expect(timeline.notchCount, 4);
      expect(timeline.boards.length, timeline.notchCount);
    });

    test('TL-4: the first board is the start board', () {
      expect(summary(timeline.boardAt(0)), summary([a, b, c]));
    });

    test('TL-4: each board applies the changes of its step over the previous one, ordered as the start board', () {
      expect(summary(timeline.boardAt(1)), [
        ('a', 20, 0, const Cell(0, 0)),
        ('b', 9, 0, const Cell(1, 0)),
        ('c', 20, 0, const Cell(1, 1)),
      ]);
      expect(summary(timeline.boardAt(2)), [
        ('a', 20, 0, const Cell(0, 0)),
        ('b', 9, 2, const Cell(1, 1)),
        ('c', 20, 0, const Cell(1, 0)),
      ]);
    });

    test('TL-4: the last board is the board after the last action, shields kept', () {
      expect(summary(timeline.boardAt(3)), [
        ('a', 20, 0, const Cell(0, 0)),
        ('b', 9, 2, const Cell(1, 1)),
        ('c', 20, 0, const Cell(1, 0)),
      ]);
    });

    test('TL-4: an empty log gives a start notch and an end notch that shows the start board', () {
      final empty = RoundTimeline.build([b], const []);
      expect(empty.notchCount, 2);
      expect(summary(empty.boardAt(1)), [('b', 10, 4, const Cell(1, 0))]);
    });

    test('TL-4: an unplayed step leaves the board as it was', () {
      final decided = RoundTimeline.build([a, b], [log.first, unplayed('b')]);
      expect(decided.notchCount, 4);
      expect(summary(decided.boardAt(2)), summary(decided.boardAt(1)));
      expect(summary(decided.boardAt(3)), summary(decided.boardAt(1)));
    });

    test('TL-4: the start and end notches play no step, the others play the step before them', () {
      expect([for (var n = 0; n < timeline.notchCount; n++) timeline.stepAt(n)], [null, 0, 1, null]);
    });

    test('TL-4: a character killed stays on the boards that follow, with 0 hp, at the cell of its last change', () {
      final killed = RoundTimeline.build(
        [a, b, c],
        [
          step('c', [character('c', side: 1, slot: 0), character('b', side: 1, slot: 1, shield: 4)]),
          step('a', [character('b', side: 1, slot: 1, hp: -3)]),
        ],
      );
      expect(summary(killed.boardAt(2)), [
        ('a', 20, 0, const Cell(0, 0)),
        ('b', 0, 0, const Cell(1, 1)),
        ('c', 20, 0, const Cell(1, 0)),
      ]);
      expect(summary(killed.boardAt(3)), summary(killed.boardAt(2)));
    });

    test('a step whose actor is not on the start board is refused', () {
      expect(() => RoundTimeline.build([a], [step('b', const [])]), throwsArgumentError);
    });

    test('a change on a character that is not on the start board is ignored', () {
      final ignored = RoundTimeline.build(
        [a],
        [
          step('a', [character('x', side: 1, slot: 0, hp: 1), character('a', side: 0, slot: 0, hp: 7)]),
        ],
      );
      expect(summary(ignored.boardAt(1)), [('a', 7, 0, const Cell(0, 0))]);
      expect(summary(ignored.boardAt(2)), [('a', 7, 0, const Cell(0, 0))]);
    });
  });

  test('TL-1, TL-4: a recorded round gives one token per logged action and ends on the recorded state', () {
    final rounds = (jsonDecode(File('test/fixtures/round_resolved.json').readAsStringSync()) as List)
        .cast<Json>()
        .map(RoundResolved.fromJson)
        .toList();

    for (var i = 0; i < rounds.length; i++) {
      // The board the Resolve plays from, as the match controller takes it.
      final start = rounds[i].startOfResolve.players.expand((p) => p.team).toList();
      final log = rounds[i].resolveLog;
      final timeline = RoundTimeline.build(start, log);

      expect(timeline.tokens.map((t) => t.characterId), log.map((s) => s.characterId), reason: 'round ${i + 1}');
      final last = timeline.boardAt(timeline.notchCount - 1);
      expect(summary(last), summary(timeline.boardAt(timeline.notchCount - 2)), reason: 'round ${i + 1}');
      final atEnd = {for (final c in last) c.id: (c.hp, c.shield, c.position)};
      for (final c in rounds[i].gameState.players.expand((p) => p.team)) {
        expect(atEnd[c.id], (c.hp, c.shield, c.position), reason: '${c.name} after round ${i + 1}');
      }
    }
  });
}
