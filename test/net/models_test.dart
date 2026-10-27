import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/net/rules.dart';

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
        'decks': [List.filled(6, catalogChar), List.filled(6, catalogChar)],
        'myPicks': ['eve', 'eve', 'eve', 'eve'],
      },
      'afkClaimInMs': 120000,
    });
    expect(gs.phase, Phase.selection);
    expect(gs.playersReady, [true, false]);
    expect(gs.selection!.decks[1], hasLength(6));
    expect(gs.selection!.decks[0].first.name, 'Eve');
    expect(gs.selection!.myPicks, hasLength(4));
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

  test('GameStateView parses initiativePlayerIndex and defaults it to 0', () {
    final base = {
      'phase': 'ROLL_PHASE',
      'currentRound': 0,
      'rollsLeft': 2,
      'playersReady': [false, false],
      'players': [
        {'playerIndex': 0, 'team': []},
        {'playerIndex': 1, 'team': []},
      ],
    };
    expect(GameStateView.fromJson({...base, 'initiativePlayerIndex': 1}).initiativePlayerIndex, 1);
    expect(GameStateView.fromJson(base).initiativePlayerIndex, 0);
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
      expect(r.gameState.players.map((p) => p.team.length), [teamSize, teamSize]);
      for (final p in r.gameState.players) {
        // One cell per side stays empty: the team occupies teamSize distinct slots of the board.
        expect(p.team.map((c) => c.position.slot).toSet(), hasLength(teamSize));
        expect(p.team.every((c) => c.position.slot >= 0 && c.position.slot < boardSize), isTrue);
      }
      expect(r.gameState.players.expand((p) => p.team).every((c) => c.catalogId.isNotEmpty), isTrue);
    }
  });

  test('CharacterView parses modifiers and stats and defaults them to empty', () {
    final withStats = CharacterView.fromJson({
      ...character('a'),
      'modifiers': [
        {'stat': 'POWER', 'value': -2, 'roundsLeft': 1}
      ],
      'stats': {'POWER': -2},
    });
    expect(withStats.modifiers.single.stat, 'POWER');
    expect(withStats.modifiers.single.value, -2);
    expect(withStats.modifiers.single.roundsLeft, 1);
    expect(withStats.stats, {'POWER': -2});

    final without = CharacterView.fromJson(character('a'));
    expect(without.modifiers, isEmpty);
    expect(without.stats, isEmpty);
  });

  test('FaceEffect parses stat and duration, null when absent', () {
    final applyStat = FaceEffect.fromJson({
      'effect': 'ApplyStat',
      'magnitude': -2,
      'stat': 'POWER',
      'duration': 2,
      'targets': [],
    });
    expect(applyStat.stat, 'POWER');
    expect(applyStat.duration, 2);
    final plain = FaceEffect.fromJson({'effect': 'Damage', 'magnitude': 3, 'targets': []});
    expect(plain.stat, isNull);
    expect(plain.duration, isNull);
  });

  test('FaceEffect parses state and keeps duration, null when absent', () {
    final applyState = FaceEffect.fromJson({
      'effect': 'ApplyState',
      'magnitude': 0,
      'state': 'STUN',
      'duration': 1,
      'targets': [],
    });
    expect(applyState.state, 'STUN');
    expect(applyState.duration, 1);
    final plain = FaceEffect.fromJson({'effect': 'Damage', 'magnitude': 3, 'targets': []});
    expect(plain.state, isNull);
  });

  test('CharacterView parses states and defaults them to empty', () {
    final withStates = CharacterView.fromJson({
      ...character('a'),
      'states': {'SPEED': 2, 'VITALITY': -1, 'STUN': 1, 'ROOT': 0, 'DIVINE_SHIELD': 0},
    });
    expect(withStates.states['SPEED'], 2);
    expect(withStates.states['VITALITY'], -1);
    expect(withStates.states['STUN'], 1);
    expect(withStates.copyWith(hp: 1).states, withStates.states);

    expect(CharacterView.fromJson(character('a')).states, isEmpty);
  });
}
