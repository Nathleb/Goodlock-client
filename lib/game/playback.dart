import '../net/models.dart';

/// What the Resolve animation shows, in order, for one character's action.
enum BeatKind { shieldLoss, damage, heal, shieldGain, move, death }

class Beat {
  final BeatKind kind;
  final String characterId;
  final int amount; // hp or shield points; 0 for move/death
  final Cell? to; // move only
  const Beat(this.kind, this.characterId, {this.amount = 0, this.to});

  @override
  String toString() => 'Beat($kind, $characterId, $amount, $to)';
}

class StepPlan {
  final String actorId;
  final bool skipped;
  final List<ResolvedEffect> effects; // labels + resolved cells, for VFX
  final List<Beat> beats;
  const StepPlan(this.actorId, this.skipped, this.effects, this.beats);
}

/// Turns the server's resolve log into animation beats by diffing each change
/// against the running state. The server is authoritative: we only describe
/// what changed, we never compute outcomes.
List<StepPlan> planRound(List<CharacterView> before, List<ResolveStep> log) {
  final state = {for (final c in before) c.id: c};
  final plans = <StepPlan>[];
  for (final step in log) {
    final beats = <Beat>[];
    for (final change in step.changes) {
      final prev = state[change.characterId];
      final next = change.after;
      state[change.characterId] = next;
      if (prev == null) continue;
      beats.addAll(_diff(prev, next));
    }
    plans.add(StepPlan(step.characterId, step.skipped, step.effects, beats));
  }
  return plans;
}

List<Beat> _diff(CharacterView prev, CharacterView next) {
  final id = next.id;
  final beats = <Beat>[];
  final shield = next.shield - prev.shield;
  final hp = next.hp - prev.hp;
  if (shield < 0) beats.add(Beat(BeatKind.shieldLoss, id, amount: -shield));
  if (hp < 0) beats.add(Beat(BeatKind.damage, id, amount: -hp));
  if (hp > 0) beats.add(Beat(BeatKind.heal, id, amount: hp));
  if (shield > 0) beats.add(Beat(BeatKind.shieldGain, id, amount: shield));
  if (next.position != prev.position) beats.add(Beat(BeatKind.move, id, to: next.position));
  if (!prev.isDead && next.isDead) beats.add(Beat(BeatKind.death, id));
  return beats;
}

/// (hp, shield) of every character after applying the log; used to check plans against recordings.
Map<String, (int, int)> replayHp(List<CharacterView> before, List<ResolveStep> log) {
  final state = {for (final c in before) c.id: (c.hp, c.shield)};
  for (final step in log) {
    for (final change in step.changes) {
      state[change.characterId] = (change.after.hp, change.after.shield);
    }
  }
  return state;
}

/// The board at the start of the next round: the server resets shields in endOfRound
/// (dice are rerolled too, which the Resolve animation doesn't show).
List<CharacterView> startOfNextRound(List<CharacterView> endOfRound) =>
    [for (final c in endOfRound) c.copyWith(shield: 0)];
