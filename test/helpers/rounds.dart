import 'package:goodlock_app/net/models.dart';

import 'builders.dart';

ResolveStep _act(String actor, [List<ResolveChange> changes = const []]) =>
    ResolveStep(actor, false, const [], changes, unplayed: false);

/// A late round of a match where player 1 already lost t3: m0 hits t0, t1 hits m1, then m2 hits t2.
///
/// With [kills], m2's hit kills t2, the second death of player 1 (END-2): the match ends on the third action, notch
/// 3. With [unplayed], t0's action follows, left unplayed since the match was decided before its turn (END-1).
/// Without them nobody dies: an elimination comes later, at the next Upkeep (a poison death, STATE-7).
RoundResolved lateRound({int round = 4, int initiative = 1, bool kills = true, bool unplayed = false}) {
  final start = GameStateView(
    phase: Phase.resolve,
    currentRound: round,
    initiativePlayerIndex: initiative,
    rollsLeft: 0,
    clocks: clocksOf(),
    players: [
      PlayerView(0, [for (var i = 0; i < 4; i++) character('m$i', side: 0, slot: i)]),
      PlayerView(1, [for (var i = 0; i < 3; i++) character('t$i', side: 1, slot: i)], [
        character('t3', side: 1, slot: 3, hp: 0),
      ]),
    ],
  );
  final log = [
    _act('m0', [ResolveChange('t0', character('t0', side: 1, slot: 0, hp: 15))]),
    _act('t1', [ResolveChange('m1', character('m1', side: 0, slot: 1, hp: 10))]),
    _act('m2', [ResolveChange('t2', character('t2', side: 1, slot: 2, hp: kills ? 0 : 5))]),
    if (unplayed) const ResolveStep('t0', true, [], [], unplayed: true),
  ];
  return RoundResolved(stateOf(Phase.result, round: round), log, start);
}

/// The Keep of the round after [lateRound].
GameStateView keepAfterLateRound({int round = 5}) => stateOf(
  Phase.keep,
  round: round,
  mine: [for (var i = 0; i < 4; i++) character('m$i', side: 0, slot: i)],
  theirs: [for (var i = 0; i < 3; i++) character('t$i', side: 1, slot: i)],
);
