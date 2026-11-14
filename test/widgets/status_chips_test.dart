import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/widgets/status_chips.dart';

import '../helpers/builders.dart';

void main() {
  List<(String, bool)> labels(CharacterView c) => [for (final l in statusLabels(c)) (l.text, l.harmful)];

  test('CELL-2: a character with no status has no chip', () {
    expect(statusLabels(character('a', side: 0, slot: 0)), isEmpty);
  });

  test('CELL-2: the shield is a helpful chip with its value', () {
    expect(labels(character('a', side: 0, slot: 0, shield: 5)), [('Bouclier 5', false)]);
  });

  test('CELL-2: states carry their sign: Haste and Regen help, Slow and Poison harm, Stun and Root harm', () {
    final c = character(
      'a',
      side: 0,
      slot: 0,
      states: {'SPEED': 2, 'VITALITY': -3, 'STUN': 1, 'ROOT': 1, 'DIVINE_SHIELD': 1},
    );
    expect(
      labels(c),
      containsAll([
        ('Haste 2', false),
        ('Poison 3', true),
        ('Stun 1', true),
        ('Root 1', true),
        ('Divine Shield', false),
      ]),
    );
    expect(
      labels(character('b', side: 0, slot: 0, states: {'SPEED': -1, 'VITALITY': 2})),
      containsAll([('Slow 1', true), ('Regen 2', false)]),
    );
  });

  test('CELL-2: stats show their net value, harmful when negative', () {
    final base = character('a', side: 0, slot: 0);
    final c = CharacterView(
      id: base.id,
      catalogId: base.catalogId,
      name: base.name,
      hp: 20,
      maxHp: 20,
      shield: 0,
      baseSpeed: 3,
      baseDie: base.baseDie,
      face: base.face,
      isFaceLocked: false,
      position: base.position,
      stats: const {'POWER': 3, 'ARMOR': -1, 'SPEED': 0},
    );
    expect(labels(c), containsAll([('Power +3', false), ('Armor -1', true)]));
    expect(labels(c).any((l) => l.$1.contains('SPEED')), isFalse);
  });
}
