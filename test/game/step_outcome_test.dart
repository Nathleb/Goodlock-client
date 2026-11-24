import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/round_timeline.dart';
import 'package:goodlock_app/game/step_outcome.dart';
import 'package:goodlock_app/net/models.dart';

import '../helpers/builders.dart';

const inFront = [
  TargetGroup('ENEMY', 'RELATIVE', [0]),
];

DieFace faceOf(List<FaceEffect> effects) => DieFace('f', 1, effects);

/// What the server logs for a face effect that reached [cells].
ResolvedEffect resolved(FaceEffect effect, List<Cell> cells) =>
    ResolvedEffect([for (final p in effect.parts) p.part], cells);

ResolveStep acts(String actor, List<ResolvedEffect> effects, List<CharacterView> after) =>
    ResolveStep(actor, false, effects, [for (final c in after) ResolveChange(c.id, c)], unplayed: false);

ResolveStep skips(String actor) => ResolveStep(actor, true, const [], const [], unplayed: false);

/// The outcome of the only step of a one-step round.
StepOutcome onlyStep(List<CharacterView> start, ResolveStep step) =>
    stepOutcome(RoundTimeline.build(start, [step]), 1, resolving: true);

/// The label of the one cell [effect] reached, hitting `b` (enemy slot 0) and leaving it as [after].
String labelOn(CharacterView b, CharacterView after, FaceEffect effect) {
  final a = character('a', side: 0, slot: 0, face: faceOf([effect]));
  final outcome = onlyStep(
    [a, b],
    acts(
      'a',
      [
        resolved(effect, [b.position]),
      ],
      [after],
    ),
  );
  return outcome.cells.single.label;
}

/// The caption of the one step of a round where `a` (own slot 2) plays [face] with the logged [effects].
String captionOf(DieFace face, List<ResolvedEffect> effects, {List<CharacterView> others = const []}) {
  final a = character('a', side: 0, slot: 2, face: face);
  return onlyStep([a, ...others], acts('a', effects, const [])).caption;
}

void main() {
  test('a timeline keeps its log: steps[i] is the action of tokens[i]', () {
    final a = character('a', side: 0, slot: 0);
    final log = [skips('a'), acts('a', const [], const [])];
    expect(RoundTimeline.build([a], log).steps, log);
  });

  group('STEP-5: start and end notches', () {
    final a = character('a', side: 0, slot: 0);
    final timeline = RoundTimeline.build([a], [acts('a', const [], const [])]);

    test('STEP-5: the start notch has no actor and no cell, and opens the round', () {
      final outcome = stepOutcome(timeline, 0, resolving: false);
      expect(outcome.actorId, isNull);
      expect(outcome.skipped, isFalse);
      expect(outcome.cells, isEmpty);
      expect(outcome.caption, 'Début du round.');
    });

    test('STEP-5: the last notch reads "if nobody rerolls" during a Keep, not during Resolve', () {
      final keep = stepOutcome(timeline, 2, resolving: false);
      final resolve = stepOutcome(timeline, 2, resolving: true);
      expect(keep.actorId, isNull);
      expect(keep.cells, isEmpty);
      expect(keep.caption, 'Fin du round si personne ne relance.');
      expect(resolve.caption, 'Fin du round.');
    });
  });

  group('STEP-2: what the effect really did on each target cell', () {
    const damage = FaceEffect(inFront, [FacePart('Damage', 15)]);

    test('STEP-2: a hit shows the HP really lost, not the value of the face, in the color of its first part', () {
      final b = character('b', side: 1, slot: 0, hp: 20, shield: 4);
      final a = character('a', side: 0, slot: 0, face: faceOf([damage]));
      final outcome = onlyStep(
        [a, b],
        acts(
          'a',
          [
            resolved(damage, [b.position]),
          ],
          [character('b', side: 1, slot: 0, hp: 9)],
        ),
      );
      expect(outcome.actorId, 'a');
      expect(outcome.skipped, isFalse);
      final cell = outcome.cells.single;
      expect((cell.cell, cell.characterId, cell.part, cell.label), (const Cell(1, 0), 'b', 'Damage', '−11'));
    });

    test('STEP-2: a hit the shield takes whole reads "bloqué"', () {
      final b = character('b', side: 1, slot: 0, shield: 20);
      expect(labelOn(b, character('b', side: 1, slot: 0, shield: 5), damage), 'bloqué');
    });

    test('STEP-2: a hit that spends a Divine Shield and takes no HP reads "bloqué"', () {
      final b = character('b', side: 1, slot: 0, states: {'DIVINE_SHIELD': 1});
      expect(labelOn(b, character('b', side: 1, slot: 0, states: {'DIVINE_SHIELD': 0}), damage), 'bloqué');
    });

    test('STEP-2: a heal shows the HP really gained, a shield the points gained', () {
      const heal = FaceEffect(inFront, [FacePart('Heal', 9), FacePart('Shield', 4)]);
      final b = character('b', side: 1, slot: 0, hp: 15);
      expect(labelOn(b, character('b', side: 1, slot: 0, hp: 20, shield: 4), heal), '+5 · +4 de bouclier');
    });

    test('STEP-2: a stat given shows its change of net value', () {
      const buff = FaceEffect(inFront, [FacePart('ApplyStat', 2, stat: 'POWER', duration: 2)]);
      final b = character('b', side: 1, slot: 0, stats: {'ARMOR': 1});
      expect(
        labelOn(b, character('b', side: 1, slot: 0, stats: {'ARMOR': -1, 'POWER': 2}), buff),
        'Armure −2 · Puissance +2',
      );
    });

    test('STEP-2: a state given shows the state the counter now holds and its duration', () {
      const states = FaceEffect(inFront, [FacePart('ApplyState', 0, state: 'STUN', duration: 1)]);
      final b = character('b', side: 1, slot: 0, states: {'SPEED': 1});
      expect(
        labelOn(b, character('b', side: 1, slot: 0, states: {'SPEED': -2, 'STUN': 1}), states),
        'Lenteur · 2 t. · Étourdi · 1 t.',
      );
    });

    test('STEP-2: a state an opposite one brings back to 0 reads as removed', () {
      const slow = FaceEffect(inFront, [FacePart('ApplyState', 0, state: 'SLOW', duration: 1)]);
      final b = character('b', side: 1, slot: 0, states: {'SPEED': 1});
      expect(labelOn(b, character('b', side: 1, slot: 0, states: {'SPEED': 0}), slow), 'Hâte retirée');
    });

    test('STEP-2: a hit that also stuns shows both', () {
      const stunning = FaceEffect(inFront, [
        FacePart('Damage', 9),
        FacePart('ApplyState', 0, state: 'STUN', duration: 1),
      ]);
      final b = character('b', side: 1, slot: 0);
      expect(
        labelOn(b, character('b', side: 1, slot: 0, hp: 11, states: {'STUN': 1}), stunning),
        '−9 · Étourdi · 1 t.',
      );
    });

    test('STEP-2: a living target the effect did not change reads "sans effet"', () {
      final b = character('b', side: 1, slot: 0);
      expect(labelOn(b, b, damage), 'sans effet');
    });

    test('STEP-2: a cell two effects of the action reach gets one outcome, with the part of the first', () {
      const stun = FaceEffect(inFront, [FacePart('ApplyState', 0, state: 'STUN', duration: 1)]);
      final a = character('a', side: 0, slot: 0, face: faceOf([damage, stun]));
      final b = character('b', side: 1, slot: 0);
      final outcome = onlyStep(
        [a, b],
        acts(
          'a',
          [
            resolved(damage, [b.position]),
            resolved(stun, [b.position]),
          ],
          [
            character('b', side: 1, slot: 0, hp: 5, states: {'STUN': 1}),
          ],
        ),
      );
      expect(outcome.cells.map((c) => (c.cell, c.part, c.label)), [
        (const Cell(1, 0), 'Damage', '−15 · Étourdi · 1 t.'),
      ]);
    });

    test('STEP-2: the cells of every effect are listed in the order of the log', () {
      const guard = FaceEffect(
        [
          TargetGroup('ALLY', 'RELATIVE', [0]),
        ],
        [FacePart('Shield', 3)],
      );
      final a = character('a', side: 0, slot: 0, face: faceOf([damage, guard]));
      final b = character('b', side: 1, slot: 0);
      final outcome = onlyStep(
        [a, b],
        acts(
          'a',
          [
            resolved(damage, [b.position]),
            resolved(guard, [a.position]),
          ],
          [character('b', side: 1, slot: 0, hp: 5), character('a', side: 0, slot: 0, shield: 3)],
        ),
      );
      expect(outcome.cells.map((c) => (c.characterId, c.part, c.label)), [
        ('b', 'Damage', '−15'),
        ('a', 'Shield', '+3 de bouclier'),
      ]);
    });

    test('STEP-2: a Swap moves both characters, and one moving into an empty cell is not a miss', () {
      const swap = FaceEffect(
        [
          TargetGroup('ALLY', 'RELATIVE', [0, 1]),
        ],
        [FacePart('Swap', 0)],
      );
      final a = character('a', side: 0, slot: 0, face: faceOf([swap]));
      final b = character('b', side: 0, slot: 1);
      final swapped = onlyStep(
        [a, b],
        acts(
          'a',
          [
            resolved(swap, [const Cell(0, 0), const Cell(0, 1)]),
          ],
          [character('a', side: 0, slot: 1), character('b', side: 0, slot: 0)],
        ),
      );
      expect(swapped.cells.map((c) => (c.characterId, c.label)), [('a', 'déplacé'), ('b', 'déplacé')]);

      final intoEmpty = onlyStep(
        [a],
        acts(
          'a',
          [
            resolved(swap, [const Cell(0, 0), const Cell(0, 1)]),
          ],
          [character('a', side: 0, slot: 1)],
        ),
      );
      expect(intoEmpty.cells.map((c) => (c.characterId, c.label)), [('a', 'déplacé'), (null, 'déplacé')]);
    });

    String stateLabel(String axis, int prev, int next) {
      const anyState = FaceEffect(inFront, [FacePart('ApplyState', 0, state: 'STUN', duration: 1)]);
      final b = character('b', side: 1, slot: 0, states: {axis: prev});
      return labelOn(b, character('b', side: 1, slot: 0, states: {axis: next}), anyState);
    }

    test('STEP-2, STATE-1: each axis names the state its counter now holds, with its duration', () {
      expect(stateLabel('SPEED', 0, 2), 'Hâte · 2 t.');
      expect(stateLabel('SPEED', 0, -1), 'Lenteur · 1 t.');
      expect(stateLabel('SPEED', 1, -1), 'Lenteur · 1 t.');
      expect(stateLabel('VITALITY', 0, 3), 'Régénération · 3 t.');
      expect(stateLabel('VITALITY', 0, -2), 'Poison · 2 t.');
      expect(stateLabel('VITALITY', -2, 1), 'Régénération · 1 t.');
      expect(stateLabel('STUN', 0, 1), 'Étourdi · 1 t.');
      expect(stateLabel('ROOT', 0, 2), 'Enraciné · 2 t.');
      expect(stateLabel('DIVINE_SHIELD', 0, 1), 'Bouclier divin · 1 t.');
      expect(stateLabel('OTHER', 0, 1), 'OTHER · 1 t.');
    });

    test('STEP-2, STATE-1: a counter brought back to 0 names the state that is gone', () {
      expect(stateLabel('SPEED', 1, 0), 'Hâte retirée');
      expect(stateLabel('SPEED', -2, 0), 'Lenteur retirée');
      expect(stateLabel('VITALITY', 2, 0), 'Régénération retirée');
      expect(stateLabel('VITALITY', -1, 0), 'Poison retiré');
      expect(stateLabel('STUN', 1, 0), 'Étourdi retiré');
      expect(stateLabel('ROOT', 1, 0), 'Enraciné retiré');
      expect(stateLabel('OTHER', 1, 0), 'OTHER retiré');
    });

    test('STEP-2, STAT-2: a stat given shows its change of net value and the duration of the change', () {
      const buff = FaceEffect(inFront, [FacePart('ApplyStat', 3, stat: 'POWER', duration: 2)]);
      final b = character('b', side: 1, slot: 0, stats: {'POWER': 3}, modifiers: const [StatInstance('POWER', 3, 4)]);
      final after = character(
        'b',
        side: 1,
        slot: 0,
        stats: {'POWER': 6, 'ARMOR': -1, 'SPEED': 1},
        modifiers: const [
          StatInstance('POWER', 3, 4),
          StatInstance('ARMOR', -1, 3),
          StatInstance('POWER', 3, 2),
          StatInstance('POWER', 3, 1),
        ],
      );
      expect(labelOn(b, after, buff), 'Armure −1 · 3 t. · Puissance +3 · 2 t. · SPEED +1');
    });
  });

  group('STEP-3: an empty target cell', () {
    const damage = FaceEffect(
      [
        TargetGroup('ENEMY', 'RELATIVE', [-1, 0, 1]),
      ],
      [FacePart('Damage', 7)],
    );

    test('STEP-3: a target cell holding no character, or a dead one, reads "raté"', () {
      final a = character('a', side: 0, slot: 1, face: faceOf([damage]));
      final b = character('b', side: 1, slot: 0, hp: 0);
      final c = character('c', side: 1, slot: 2);
      final outcome = onlyStep(
        [a, b, c],
        acts(
          'a',
          [
            resolved(damage, [const Cell(1, 0), const Cell(1, 1), const Cell(1, 2)]),
          ],
          [character('c', side: 1, slot: 2, hp: 13)],
        ),
      );
      expect(outcome.cells.map((o) => (o.cell, o.characterId, o.part, o.label)), [
        (const Cell(1, 0), null, 'Damage', 'raté'),
        (const Cell(1, 1), null, 'Damage', 'raté'),
        (const Cell(1, 2), 'c', 'Damage', '−7'),
      ]);
    });
  });

  group('STEP-4: a skipped action', () {
    test('STEP-4: a stunned character\'s action is cancelled, with no target cell', () {
      final a = character('a', side: 0, slot: 0, states: {'STUN': 1});
      final b = character('b', side: 1, slot: 0);
      final timeline = RoundTimeline.build([a, b], [acts('b', const [], const []), skips('a')]);
      final outcome = stepOutcome(timeline, 2, resolving: false);
      expect(outcome.actorId, 'a');
      expect(outcome.skipped, isTrue);
      expect(outcome.cells, isEmpty);
      expect(outcome.caption, '2. Name a : action annulée (étourdi).');
    });

    test('STEP-4: a character killed earlier in the round never acts', () {
      const damage = FaceEffect(inFront, [FacePart('Damage', 30)]);
      final a = character('a', side: 0, slot: 0, face: faceOf([damage]));
      final b = character('b', side: 1, slot: 0);
      final timeline = RoundTimeline.build(
        [a, b],
        [
          acts(
            'a',
            [
              resolved(damage, [b.position]),
            ],
            [character('b', side: 1, slot: 0, hp: -10)],
          ),
          skips('b'),
        ],
      );
      final outcome = stepOutcome(timeline, 2, resolving: true);
      expect(outcome.skipped, isTrue);
      expect(outcome.cells, isEmpty);
      expect(outcome.caption, '2. Name b : mort avant son tour.');
    });

    test('STEP-4, END-1: an action the decided match never reached says so, with no target cell', () {
      final a = character(
        'a',
        side: 0,
        slot: 0,
        face: faceOf([
          const FaceEffect(inFront, [FacePart('Damage', 5)]),
        ]),
      );
      final b = character('b', side: 1, slot: 0);
      final timeline = RoundTimeline.build(
        [a, b],
        [acts('b', const [], const []), const ResolveStep('a', true, [], [], unplayed: true)],
      );
      final outcome = stepOutcome(timeline, 2, resolving: true);
      expect(outcome.actorId, 'a');
      expect(outcome.skipped, isTrue);
      expect(outcome.cells, isEmpty);
      expect(outcome.caption, '2. Name a : pas jouée, le match est décidé.');
    });
  });

  group('STEP-5: the caption of an action', () {
    test('STEP-5: number, actor, parts of the face, targeting, and the characters on the target cells', () {
      const damage = FaceEffect(
        [
          TargetGroup('ENEMY', 'RELATIVE', [-1, 0, 1]),
        ],
        [FacePart('Damage', 7)],
      );
      final b = character('b', side: 1, slot: 1);
      final c = character('c', side: 1, slot: 3);
      expect(
        captionOf(
          faceOf([damage]),
          [
            resolved(damage, [const Cell(1, 1), const Cell(1, 2), const Cell(1, 3)]),
          ],
          others: [b, c],
        ),
        '1. Name a : 7 dégâts, en face et voisins → Name b, cellule vide, Name c.',
      );
    });

    test('STEP-5: the number is the rank of the action in the round', () {
      final a = character('a', side: 0, slot: 0);
      final timeline = RoundTimeline.build([a], [for (var i = 0; i < 5; i++) skips('a')]);
      expect(stepOutcome(timeline, 5, resolving: true).caption, startsWith('5. Name a : '));
    });

    test('STEP-5: each part of the face is worded with its value, in the order of the face', () {
      const parts = [
        FacePart('Damage', 9),
        FacePart('FixedDamage', 3),
        FacePart('Heal', 4),
        FacePart('Shield', 5),
        FacePart('ApplyStat', -2, stat: 'ARMOR', duration: 2),
        FacePart('ApplyState', 0, state: 'POISON', duration: 3),
        FacePart('Swap', 0),
      ];
      const effect = FaceEffect(inFront, parts);
      expect(
        captionOf(faceOf([effect]), [resolved(effect, const [])]),
        '1. Name a : 9 dégâts + 3 dégâts fixes + 4 de soin + 5 de bouclier + Armure −2 · 2 t. + Poison · 3 t. + '
        'échange, en face → aucune cellule.',
      );
    });

    test('STEP-5: the effects of a face are separated, each with its own targets', () {
      const hit = FaceEffect(inFront, [FacePart('Damage', 5)]);
      const guard = FaceEffect(
        [
          TargetGroup('ALLY', 'RELATIVE', [0]),
        ],
        [FacePart('Shield', 3)],
      );
      final b = character('b', side: 1, slot: 2);
      expect(
        captionOf(
          faceOf([hit, guard]),
          [
            resolved(hit, [const Cell(1, 2)]),
            resolved(guard, [const Cell(0, 2)]),
          ],
          others: [b],
        ),
        '1. Name a : 5 dégâts, en face → Name b ; 3 de bouclier, soi → Name a.',
      );
    });

    test('STEP-5: an action stopped before the end of its face only tells the effects that played', () {
      const hit = FaceEffect(inFront, [FacePart('Damage', 5)]);
      final b = character('b', side: 1, slot: 2);
      expect(
        captionOf(
          faceOf([hit, hit]),
          [
            resolved(hit, [const Cell(1, 2)]),
          ],
          others: [b],
        ),
        '1. Name a : 5 dégâts, en face → Name b.',
      );
    });

    test('STEP-5: an effect that does not match the face of the start board is worded from the log alone', () {
      const heal = FaceEffect(inFront, [FacePart('Heal', 4)]);
      const logged = FaceEffect(inFront, [FacePart('Damage', 5), FacePart('ApplyState', 0, state: 'STUN')]);
      final b = character('b', side: 1, slot: 2);
      expect(
        captionOf(
          faceOf([heal]),
          [
            resolved(logged, [const Cell(1, 2)]),
            resolved(heal, const []),
          ],
          others: [b],
        ),
        '1. Name a : dégâts + état → Name b ; soin → aucune cellule.',
      );
    });

    test('STEP-5: a blank face says so', () {
      expect(captionOf(blankFace, const []), '1. Name a : face vide.');
    });

    String targeting(List<TargetGroup> targets) {
      final effect = FaceEffect(targets, const [FacePart('Damage', 1)]);
      final caption = captionOf(faceOf([effect]), [resolved(effect, const [])]);
      return caption.substring('1. Name a : 1 dégât, '.length, caption.length - ' → aucune cellule.'.length);
    }

    test('STEP-5: the targeting is worded from the target groups of the face', () {
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'RELATIVE', [0]),
        ]),
        'en face',
      );
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'RELATIVE', [-1, 1]),
        ]),
        'voisins',
      );
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'RELATIVE', [1]),
        ]),
        'voisin',
      );
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'RELATIVE', [0, -1]),
        ]),
        'en face et voisin',
      );
      expect(
        targeting(const [
          TargetGroup('ALLY', 'RELATIVE', [0]),
        ]),
        'soi',
      );
      expect(
        targeting(const [
          TargetGroup('ALLY', 'RELATIVE', [-1, 1]),
        ]),
        'alliés voisins',
      );
      expect(
        targeting(const [
          TargetGroup('ALLY', 'RELATIVE', [-1, 0, 1]),
        ]),
        'soi et alliés voisins',
      );
      expect(
        targeting(const [
          TargetGroup('ALLY', 'RELATIVE', [1]),
        ]),
        'allié voisin',
      );
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'RELATIVE', [2]),
        ]),
        'ennemis',
      );
      expect(
        targeting(const [
          TargetGroup('ALLY', 'RELATIVE', [0, -2]),
        ]),
        'soi et alliés',
      );
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'ABSOLUTE', [2]),
        ]),
        'cellule ennemie 2',
      );
      expect(
        targeting(const [
          TargetGroup('ALLY', 'ABSOLUTE', [0, 3]),
        ]),
        'cellules alliées 0, 3',
      );
      expect(
        targeting(const [
          TargetGroup('ALLY', 'ABSOLUTE', [0, 1, 2, 3, 4]),
        ]),
        'tous les alliés',
      );
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'ABSOLUTE', [4, 3, 2, 1, 0]),
        ]),
        'tous les ennemis',
      );
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'RELATIVE', [0]),
          TargetGroup('ALLY', 'RELATIVE', [0]),
        ]),
        'en face et soi',
      );
    });

    test('STEP-5: more phrases of the targeting', () {
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'RELATIVE', [-1, 0, 1]),
        ]),
        'en face et voisins',
      );
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'RELATIVE', [0, 2]),
        ]),
        'en face et ennemis',
      );
      expect(
        targeting(const [
          TargetGroup('ALLY', 'RELATIVE', [-2]),
        ]),
        'alliés',
      );
      expect(
        targeting(const [
          TargetGroup('ALLY', 'ABSOLUTE', [3]),
        ]),
        'cellule alliée 3',
      );
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'ABSOLUTE', [2, 1]),
        ]),
        'cellules ennemies 1, 2',
      );
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'ABSOLUTE', [2, 2]),
        ]),
        'cellule ennemie 2',
      );
      expect(
        targeting(const [
          TargetGroup('ENEMY', 'ABSOLUTE', [0, 1, 2, 3, 5]),
        ]),
        'cellules ennemies 0, 1, 2, 3, 5',
      );
      expect(
        targeting(const [
          TargetGroup('ALLY', 'ABSOLUTE', [-1, 0, 1, 2, 3]),
        ]),
        'cellules alliées -1, 0, 1, 2, 3',
      );
    });

    /// The words of [part] in the caption of a face that holds it alone.
    String partText(FacePart part) {
      final effect = FaceEffect(inFront, [part]);
      final caption = captionOf(faceOf([effect]), [resolved(effect, const [])]);
      return caption.substring('1. Name a : '.length, caption.length - ', en face → aucune cellule.'.length);
    }

    test('STEP-5: a quantity reads value first, in the singular below 2', () {
      expect(partText(const FacePart('Damage', 1)), '1 dégât');
      expect(partText(const FacePart('Damage', 2)), '2 dégâts');
      expect(partText(const FacePart('FixedDamage', 1)), '1 dégât fixe');
      expect(partText(const FacePart('FixedDamage', 2)), '2 dégâts fixes');
      expect(partText(const FacePart('Heal', 1)), '1 de soin');
      expect(partText(const FacePart('Shield', 1)), '1 de bouclier');
      expect(partText(const FacePart('Swap', 0)), 'échange');
      expect(partText(const FacePart('Other', 2)), 'Other 2');
    });

    test('STEP-5: a stat reads its name, its signed value and its duration', () {
      expect(partText(const FacePart('ApplyStat', 3, stat: 'POWER', duration: 2)), 'Puissance +3 · 2 t.');
      expect(partText(const FacePart('ApplyStat', -1, stat: 'ARMOR', duration: 1)), 'Armure −1 · 1 t.');
      expect(partText(const FacePart('ApplyStat', 1, stat: 'OTHER')), 'OTHER +1');
    });

    test('STEP-5: a state reads its name and its duration', () {
      String state(String name) => partText(FacePart('ApplyState', 0, state: name, duration: 2));
      expect(state('HASTE'), 'Hâte · 2 t.');
      expect(state('SLOW'), 'Lenteur · 2 t.');
      expect(state('REGEN'), 'Régénération · 2 t.');
      expect(state('POISON'), 'Poison · 2 t.');
      expect(state('STUN'), 'Étourdi · 2 t.');
      expect(state('ROOT'), 'Enraciné · 2 t.');
      expect(state('DIVINE_SHIELD'), 'Bouclier divin · 2 t.');
      expect(state('OTHER'), 'OTHER · 2 t.');
      expect(partText(const FacePart('ApplyState', 0, state: 'STUN')), 'Étourdi');
    });

    test('STEP-5: worded from the log alone, each part has its own word', () {
      String word(String part) => captionOf(blankFace, [
        ResolvedEffect([part], const []),
      ]).substring('1. Name a : '.length);
      expect(word('Damage'), 'dégâts → aucune cellule.');
      expect(word('FixedDamage'), 'dégâts fixes → aucune cellule.');
      expect(word('Heal'), 'soin → aucune cellule.');
      expect(word('Shield'), 'bouclier → aucune cellule.');
      expect(word('Swap'), 'échange → aucune cellule.');
      expect(word('ApplyStat'), 'stat → aucune cellule.');
      expect(word('ApplyState'), 'état → aucune cellule.');
      expect(word('Other'), 'Other → aucune cellule.');
    });
  });

  group('STEP-1..5: recorded rounds', () {
    List<Json> load(String name) =>
        (jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as List).cast<Json>();
    final keeps = load('round_start').map(GameStateView.fromJson).toList();
    final rounds = load('round_resolved').map(RoundResolved.fromJson).toList();
    List<CharacterView> boardOf(GameStateView state) => state.players.expand((p) => p.team).toList();

    // The timelines of the production paths: the first Keep board with its preview, and the Resolve board with
    // its log.
    final keepTimelines = [for (final k in keeps) RoundTimeline.build(boardOf(k), k.preview)];
    final resolveTimelines = [for (final r in rounds) RoundTimeline.build(boardOf(r.startOfResolve), r.resolveLog)];

    test('STEP-1..5: every notch of a recorded round gives a caption, in Keep and in Resolve', () {
      for (final (timelines, resolving) in [(keepTimelines, false), (resolveTimelines, true)]) {
        for (var i = 0; i < timelines.length; i++) {
          final timeline = timelines[i];
          for (var n = 0; n < timeline.notchCount; n++) {
            final outcome = stepOutcome(timeline, n, resolving: resolving);
            final reason = '${resolving ? 'Resolve' : 'Keep'} ${i + 1}, notch $n';
            expect(outcome.caption, isNotEmpty, reason: reason);
            expect(outcome.caption, isNot(contains('null')), reason: reason);
            expect(outcome.cells.every((c) => c.label.isNotEmpty), isTrue, reason: reason);
          }
        }
      }
    });

    test('STEP-5: a recorded action is worded from its face, with the values and the targeting it carries', () {
      var damages = 0;
      for (final (timelines, resolving) in [(keepTimelines, false), (resolveTimelines, true)]) {
        for (var i = 0; i < timelines.length; i++) {
          final timeline = timelines[i];
          for (var s = 0; s < timeline.steps.length; s++) {
            final step = timeline.steps[s];
            if (step.skipped || step.effects.isEmpty) continue;
            final face = timeline.tokens[s].face;
            final caption = stepOutcome(timeline, s + 1, resolving: resolving).caption;
            final reason = '${resolving ? 'Resolve' : 'Keep'} ${i + 1}, step ${s + 1}: $caption';
            final clauses = caption.split(' ; ');
            expect(clauses.length, step.effects.length, reason: reason);
            for (var e = 0; e < step.effects.length; e++) {
              final parts = face.effects[e].parts;
              expect(parts.map((p) => p.part), step.effects[e].parts, reason: reason);
              // The fallback wording, from the log alone, has no targeting before the arrow.
              expect(clauses[e].split(' → ').first, contains(', '), reason: reason);
              for (final p in parts.where((p) => p.part == 'Damage')) {
                expect(clauses[e], contains('${p.magnitude} dégâts'), reason: reason);
                damages++;
              }
            }
          }
        }
      }
      expect(damages, greaterThan(10), reason: 'the recorded rounds play Damage faces');
    });
  });
}
