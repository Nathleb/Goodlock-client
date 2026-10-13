import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/models.dart';

Map<String, dynamic> face(String d, {int priority = 0}) => {
      'description': d,
      'priority': priority,
      'effects': [
        {
          'effect': 'Damage',
          'magnitude': 3,
          'targets': [
            {'side': 'ENEMY', 'mode': 'RELATIVE', 'n': [0, 1]}
          ]
        }
      ],
    };

Map<String, dynamic> character(String id, {int playerIndex = 0, int slot = 0, int hp = 10}) => {
      'id': id,
      'catalogId': 'alicent',
      'name': 'Alicent',
      'hp': hp,
      'maxHp': 10,
      'shield': 2,
      'baseSpeed': 18,
      'baseDie': List.generate(6, (i) => face('f$i')),
      'face': face('f0', priority: 1),
      'isFaceLocked': true,
      'position': {'playerIndex': playerIndex, 'slot': slot},
    };

void main() {
  test('CharacterView parses identity, stats, die and position', () {
    final c = CharacterView.fromJson(character('c1', playerIndex: 1, slot: 3, hp: 4));
    expect(c.id, 'c1');
    expect(c.catalogId, 'alicent');
    expect(c.hp, 4);
    expect(c.shield, 2);
    expect(c.baseDie, hasLength(6));
    expect(c.face.priority, 1);
    expect(c.face.effects.single.targets.single.n, [0, 1]);
    expect(c.isFaceLocked, isTrue);
    expect(c.position, const Cell(1, 3));
    expect(c.isDead, isFalse);
    expect(CharacterView.fromJson(character('d', hp: 0)).isDead, isTrue);
  });

  test('GameStateView parses a SELECTION view with both decks and my pick', () {
    final catalogChar = {
      'id': 'eve',
      'name': 'Eve',
      'maxHp': 20,
      'baseSpeed': 3,
      'baseDie': List.generate(6, (i) => face('f$i')),
    };
    final gs = GameStateView.fromJson({
      'phase': 'SELECTION_PHASE',
      'currentRound': 0,
      'rollsLeft': 2,
      'playersReady': [true, false],
      'players': [
        {'playerIndex': 0, 'team': []},
        {'playerIndex': 1, 'team': []},
      ],
      'selection': {
        'decks': [List.filled(7, catalogChar), List.filled(7, catalogChar)],
        'myPicks': ['eve', 'eve', 'eve', 'eve', 'eve'],
      },
      'afkClaimInMs': 120000,
    });
    expect(gs.phase, Phase.selection);
    expect(gs.playersReady, [true, false]);
    expect(gs.selection!.decks[1], hasLength(7));
    expect(gs.selection!.decks[0].first.name, 'Eve');
    expect(gs.selection!.myPicks, hasLength(5));
    expect(gs.afkClaimInMs, 120000);
  });

  test('GameStateView parses KEEP with teams and no selection or timer', () {
    final gs = GameStateView.fromJson({
      'phase': 'KEEP_PHASE',
      'currentRound': 2,
      'rollsLeft': 1,
      'playersReady': [false, false],
      'players': [
        {'playerIndex': 0, 'team': [character('a')]},
        {'playerIndex': 1, 'team': [character('b', playerIndex: 1)]},
      ],
    });
    expect(gs.phase, Phase.keep);
    expect(gs.selection, isNull);
    expect(gs.afkClaimInMs, isNull);
    expect(gs.players[1].team.single.id, 'b');
  });

  test('unknown phases are kept as unknown rather than crashing', () {
    expect(Phase.parse('SOMETHING_NEW'), Phase.unknown);
  });

  test('RoomView parses players with owner and deck readiness', () {
    final room = RoomView.fromJson({
      'roomId': 'r1',
      'ownerId': 'p0',
      'isStarted': false,
      'players': [
        {'playerId': 'p0', 'isOwner': true, 'hasDeck': true},
        {'playerId': 'p1', 'isOwner': false, 'hasDeck': false},
      ],
    });
    expect(room.roomId, 'r1');
    expect(room.players.map((p) => p.hasDeck), [true, false]);
    expect(room.players.first.isOwner, isTrue);
  });

  test('RoundResolved parses steps with resolved cells and changes', () {
    final r = RoundResolved.fromJson({
      'gameState': {
        'phase': 'RESULT_PHASE',
        'currentRound': 1,
        'rollsLeft': 0,
        'playersReady': [false, false],
        'players': [
          {'playerIndex': 0, 'team': [character('a')]},
          {'playerIndex': 1, 'team': [character('b', playerIndex: 1, hp: 7)]},
        ],
      },
      'resolveLog': [
        {
          'characterId': 'a',
          'skipped': false,
          'effects': [
            {
              'effect': 'Damage',
              'targets': [
                {'playerIndex': 1, 'slot': 0}
              ]
            },
            {'effect': 'Heal', 'targets': []},
          ],
          'changes': [
            {'characterId': 'b', 'after': character('b', playerIndex: 1, hp: 7)}
          ],
        }
      ],
    });
    final step = r.resolveLog.single;
    expect(step.characterId, 'a');
    expect(step.skipped, isFalse);
    expect(step.effects.first.targets.single, const Cell(1, 0));
    expect(step.effects.last.fizzled, isTrue);
    expect(step.changes.single.after.hp, 7);
    expect(r.gameState.phase, Phase.result);
  });

  test('GameOver accepts a player index or a draw', () {
    expect(GameOver.fromJson({'winner': 1, 'reason': 'elimination'}).winner, 1);
    expect(GameOver.fromJson({'winner': 'draw', 'reason': 'elimination'}).isDraw, isTrue);
  });

  test('parses real roundResolved payloads recorded from the backend', () {
    final raw = jsonDecode(File('test/fixtures/round_resolved.json').readAsStringSync()) as List;
    expect(raw, isNotEmpty);
    for (final j in raw) {
      final r = RoundResolved.fromJson(j as Json);
      expect(r.resolveLog, isNotEmpty);
      expect(r.gameState.players.map((p) => p.team.length), [5, 5]);
      expect(r.gameState.players.expand((p) => p.team).every((c) => c.catalogId.isNotEmpty), isTrue);
    }
  });
}
