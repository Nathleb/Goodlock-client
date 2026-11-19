import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/round_timeline.dart';

import '../helpers/builders.dart';

void main() {
  test('LAYOUT-3: a timeline board becomes two players, indexed by player, each team ordered by slot', () {
    final players = playersFromBoard([
      character('t2', side: 1, slot: 2),
      character('m3', side: 0, slot: 3),
      character('m0', side: 0, slot: 0),
      character('t0', side: 1, slot: 0),
    ]);

    expect(players.map((p) => p.playerIndex), [0, 1]);
    expect(players[0].team.map((c) => c.id), ['m0', 'm3']);
    expect(players[1].team.map((c) => c.id), ['t0', 't2']);
  });

  test('CELL-6: a character with no HP left is off the board', () {
    final players = playersFromBoard([
      character('m0', side: 0, slot: 0, hp: 0),
      character('m1', side: 0, slot: 1, hp: 1),
      character('t0', side: 1, slot: 0, hp: -3),
    ]);

    expect(players[0].team.map((c) => c.id), ['m1']);
    expect(players[1].team, isEmpty);
  });
}
