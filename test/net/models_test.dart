import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/net/rules.dart';

import '../protocol/schema.dart';

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
  group('hand-written payloads match the backend schema', () {
    test('face() is a DieFaceDTO', () {
      expectValid('DieFaceDTO', face('f0', priority: 1));
    });

    test('a character as the server sends it is a CharacterDTO', () {
      expectValid('CharacterDTO', {
        ...character('c1', playerIndex: 1, slot: 3, hp: 4),
        'modifiers': <Object>[],
        'stats': {'POWER': 0, 'ARMOR': 0},
        'states': {'SPEED': 0, 'VITALITY': 0, 'STUN': 0, 'ROOT': 0, 'DIVINE_SHIELD': 0},
      });
    });

    test('character() alone is not a CharacterDTO: the tests that omit modifiers, stats and states are about client defaults', () {
      expect(schemaFor('CharacterDTO').validate(character('c1')).isValid, isFalse);
    });
  });

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
      'myReady': true,
      'players': [
        {'playerIndex': 0, 'team': []},
        {'playerIndex': 1, 'team': []},
      ],
      'selection': {
        'decks': [List.filled(6, catalogChar), List.filled(6, catalogChar)],
        'myPicks': ['eve', 'eve', 'eve', 'eve'],
      },
    });
    expect(gs.phase, Phase.selection);
    expect(gs.myReady, isTrue);
    expect(gs.selection!.decks[1], hasLength(6));
    expect(gs.selection!.decks[0].first.name, 'Eve');
    expect(gs.selection!.myPicks, hasLength(4));
  });

  test('GameStateView parses KEEP with teams and no selection', () {
    final gs = GameStateView.fromJson({
      'phase': 'KEEP_PHASE',
      'currentRound': 2,
      'rollsLeft': 1,
      'players': [
        {'playerIndex': 0, 'team': [character('a')]},
        {'playerIndex': 1, 'team': [character('b', playerIndex: 1)]},
      ],
    });
    expect(gs.phase, Phase.keep);
    expect(gs.myReady, isFalse, reason: 'a state sent to both players carries no confirmation (GAME-9)');
    expect(gs.selection, isNull);
    expect(gs.players[1].team.single.id, 'b');
  });

  test('GameStateView parses initiativePlayerIndex and defaults it to 0', () {
    final base = {
      'phase': 'ROLL_PHASE',
      'currentRound': 0,
      'rollsLeft': 2,
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

  test('GameOver parses the winner, a player index', () {
    final over = {'winner': 1, 'reason': 'elimination'};

    expectValid('GameOverDTO', over);
    expect(GameOver.fromJson(over).winner, 1);
    expect(GameOver.fromJson(over).isDraw, isFalse);
    expect(schemaFor('GameOverDTO').validate({...over, 'winner': 2}).isValid, isFalse);
  });

  test('END-1, END-3: GameOver parses a draw, a simultaneous loss on clock or reconnection time', () {
    for (final (wire, reason) in [('clock', EndReason.clock), ('reconnection', EndReason.reconnection)]) {
      final over = {'winner': 'draw', 'reason': wire};
      expectValid('GameOverDTO', over);
      final parsed = GameOver.fromJson(over);
      expect(parsed.isDraw, isTrue);
      expect(parsed.winner, isNull);
      expect(parsed.reason, reason);
    }
  });

  test('END-3: GameOver parses why the match ended: 2 dead characters, clock, reconnection time or concession', () {
    const reasons = {
      'elimination': EndReason.elimination,
      'clock': EndReason.clock,
      'reconnection': EndReason.reconnection,
      'concede': EndReason.concede,
    };
    reasons.forEach((wire, reason) {
      final over = {'winner': 0, 'reason': wire};
      expectValid('GameOverDTO', over);
      expect(GameOver.fromJson(over).reason, reason);
    });
  });

  test('the old forfeit and afk reasons are gone from the protocol, and an unknown reason does not crash', () {
    expect(schemaFor('GameOverDTO').validate({'winner': 0, 'reason': 'forfeit'}).isValid, isFalse);
    expect(schemaFor('GameOverDTO').validate({'winner': 0, 'reason': 'afk'}).isValid, isFalse);
    expect(GameOver.fromJson({'winner': 0, 'reason': 'SOMETHING_NEW'}).reason, EndReason.unknown);
  });

  test('GameStateView parses both clocks, indexed by player (GAME-7)', () {
    final clocks = [
      {'remainingMs': 512000, 'reconnectionMs': 180000, 'running': true, 'connected': true},
      {'remainingMs': 498500, 'reconnectionMs': 92000, 'running': false, 'connected': false},
    ];
    for (final c in clocks) {
      expectValid('PlayerClockDTO', c);
    }

    final gs = GameStateView.fromJson({
      'phase': 'KEEP_PHASE',
      'currentRound': 1,
      'rollsLeft': 1,
      'clocks': clocks,
      'players': [
        {'playerIndex': 0, 'team': []},
        {'playerIndex': 1, 'team': []},
      ],
    });

    expect(gs.clocks, hasLength(2));
    expect(gs.clocks[0].remainingMs, 512000);
    expect(gs.clocks[0].reconnectionMs, 180000);
    expect(gs.clocks[0].running, isTrue);
    expect(gs.clocks[0].connected, isTrue);
    expect(gs.clocks[1].remainingMs, 498500);
    expect(gs.clocks[1].reconnectionMs, 92000);
    expect(gs.clocks[1].running, isFalse);
    expect(gs.clocks[1].connected, isFalse);
  });

  test('a game state without clocks is no GameStateDTO, and parses to no clocks', () {
    final noClocks = {
      'phase': 'KEEP_PHASE',
      'currentRound': 0,
      'initiativePlayerIndex': 0,
      'rollsLeft': 2,
      'players': [
        {'playerIndex': 0, 'team': [], 'fallen': []},
        {'playerIndex': 1, 'team': [], 'fallen': []},
      ],
    };

    expect(schemaFor('GameStateDTO').validate(noClocks).isValid, isFalse);
    expect(GameStateView.fromJson(noClocks).clocks, isEmpty);
  });

  test('PresenceChanged parses who is connected and their reconnection time left (AWAY-2)', () {
    final away = {'playerIndex': 1, 'connected': false, 'reconnectionMs': 175400};

    expectValid('PresenceChangedDTO', away);
    final p = PresenceChanged.fromJson(away);
    expect(p.playerIndex, 1);
    expect(p.connected, isFalse);
    expect(p.reconnectionMs, 175400);
    expect(schemaFor('PresenceChangedDTO').validate({...away, 'claimInMs': null}).isValid, isFalse);
  });

  test('every recorded start board carries both clocks', () {
    final raw = jsonDecode(File('test/fixtures/round_start.json').readAsStringSync()) as List;
    expect(raw, isNotEmpty);
    for (final j in raw) {
      final gs = GameStateView.fromJson(j as Json);
      expect(gs.clocks, hasLength(2));
      expect(gs.clocks.every((c) => c.running && c.connected), isTrue, reason: 'a KEEP board sent to both');
    }
  });

  test('PlayerView parses the fallen, off the board, apart from the team on the board', () {
    final full = {
      'modifiers': <Object>[],
      'stats': {'POWER': 0, 'ARMOR': 0},
      'states': {'SPEED': 0, 'VITALITY': 0, 'STUN': 0, 'ROOT': 0, 'DIVINE_SHIELD': 0},
    };
    final player = {
      'playerIndex': 1,
      'team': [
        {...character('b', playerIndex: 1, slot: 2), ...full},
        {...character('c', playerIndex: 1, slot: 4), ...full},
      ],
      'fallen': [
        {...character('d', playerIndex: 1, slot: 0, hp: 0), ...full},
        {...character('e', playerIndex: 1, slot: 3, hp: 0), ...full},
      ],
    };

    expectValid('PlayerGameStateDTO', player);
    final p = PlayerView.fromJson(player);
    expect(p.team.map((c) => c.id), ['b', 'c']);
    expect(p.fallen.map((c) => c.id), ['d', 'e']);
    expect(p.fallen.every((c) => c.isDead), isTrue);
  });

  test('the hidden opponent (SELECTION, PLACEMENT) parses to no team and no fallen', () {
    final p = PlayerView.fromJson({'playerIndex': 0, 'team': [], 'fallen': []});
    expect(p.team, isEmpty);
    expect(p.fallen, isEmpty);
  });

  test('parses real roundResolved payloads recorded from the backend', () {
    final raw = jsonDecode(File('test/fixtures/round_resolved.json').readAsStringSync()) as List;
    expect(raw, isNotEmpty);
    for (final j in raw) {
      final r = RoundResolved.fromJson(j as Json);
      expect(r.resolveLog, isNotEmpty);
      for (final p in r.gameState.players) {
        // DEAD-1: the dead have left the board for `fallen`.
        expect(p.team.length + p.fallen.length, teamSize);
        expect(p.team.any((c) => c.isDead), isFalse);
        expect(p.fallen.every((c) => c.isDead), isTrue);
        // At least one cell per side stays empty: each character on the board has its own slot.
        expect(p.team.map((c) => c.position.slot).toSet(), hasLength(p.team.length));
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
