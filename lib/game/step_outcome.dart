// What the board and the status bar show for one notch of a round (STEP-2..5).
// Pure Dart (no Flutter import). It computes no outcome: it diffs the boards of the timeline around a step and
// words the face that played.

import '../net/models.dart';
import '../net/rules.dart';
import 'round_timeline.dart';

/// What one effect of an action did on one of its target cells (STEP-2, STEP-3).
class CellOutcome {
  final Cell cell;

  /// The character that stood on the cell before the action; null for an empty cell.
  final String? characterId;

  /// The first part of the effect that reached the cell (Damage, Heal...): the board picks the color from it.
  final String part;

  /// What the effect really did, in French: "−12", "bloqué", "+5", "Bouclier +4", "Étourdi · 1 t.", "raté"...
  final String label;
  const CellOutcome(this.cell, this.characterId, this.part, this.label);
}

/// What a notch shows: the acting character, the target cells and the caption of the status bar.
class StepOutcome {
  final String? actorId; // null on the start and end notches
  final bool skipped;
  final List<CellOutcome> cells;
  final String caption;
  const StepOutcome(this.actorId, this.skipped, this.cells, this.caption);
}

/// The outcome of [notch] of [timeline]; [resolving] is false during a Keep, when the round is a preview.
///
/// Known approximation: each target cell is matched against the board before the whole action. Cells are resolved
/// just before each effect, so when an effect of the action has already swapped characters, a later effect's label
/// can land on the character that stood on the cell before the swap.
StepOutcome stepOutcome(RoundTimeline timeline, int notch, {required bool resolving}) {
  final index = timeline.stepAt(notch);
  if (index == null) {
    final caption = notch == 0
        ? 'Début du round.'
        : resolving
        ? 'Fin du round.'
        : 'Fin du round si personne ne relance.';
    return StepOutcome(null, false, const [], caption);
  }
  final token = timeline.tokens[index];
  final step = timeline.steps[index];
  final before = timeline.boardAt(notch - 1);
  final after = timeline.boardAt(notch);
  final actor = _byId(before, token.characterId)?.name ?? token.characterId;
  final number = '$notch. $actor : ';
  if (step.skipped) {
    final why = token.status == TokenStatus.dead ? 'mort avant son tour' : 'action annulée (étourdi)';
    return StepOutcome(token.characterId, true, const [], '$number$why.');
  }
  return StepOutcome(
    token.characterId,
    false,
    _cells(step.effects, before, after),
    '$number${_describe(step.effects, token.face, before)}.',
  );
}

CharacterView? _byId(List<CharacterView> board, String id) {
  for (final c in board) {
    if (c.id == id) return c;
  }
  return null;
}

CharacterView? _livingAt(List<CharacterView> board, Cell cell) {
  for (final c in board) {
    if (!c.isDead && c.position == cell) return c;
  }
  return null;
}

/// One outcome per target cell, in the order of the log; a cell two effects reach keeps the part of the first.
List<CellOutcome> _cells(List<ResolvedEffect> effects, List<CharacterView> before, List<CharacterView> after) {
  final outcomes = <Cell, CellOutcome>{};
  for (final effect in effects) {
    final part = effect.parts.isEmpty ? '' : effect.parts.first;
    for (final cell in effect.targets) {
      if (outcomes.containsKey(cell)) continue;
      final target = _livingAt(before, cell);
      final label = target != null
          ? _diff(target, _byId(after, target.id)!)
          // A Swap moves a character into an empty cell: that is not a miss.
          : effect.parts.contains('Swap') && _livingAt(after, cell) != null
          ? 'déplacé'
          : 'raté';
      outcomes[cell] = CellOutcome(cell, target?.id, part, label);
    }
  }
  return outcomes.values.toList(growable: false);
}

/// What changed on a character across the action, as the server sent it.
String _diff(CharacterView prev, CharacterView next) {
  final hp = next.hp - prev.hp; // a killed character is at 0 hp on the timeline boards
  final shield = next.shield - prev.shield;
  final divineShieldSpent = (prev.states['DIVINE_SHIELD'] ?? 0) > 0 && (next.states['DIVINE_SHIELD'] ?? 0) == 0;
  final pieces = <String>[
    if (hp < 0) '−${-hp}',
    if (hp > 0) '+$hp',
    if (hp == 0 && (shield < 0 || divineShieldSpent)) 'bloqué',
    if (shield > 0) 'Bouclier +$shield',
    if (next.position != prev.position) 'déplacé',
    for (final stat in _keys(prev.stats, next.stats))
      if ((next.stats[stat] ?? 0) != (prev.stats[stat] ?? 0))
        '${_statName(stat)} ${_signed((next.stats[stat] ?? 0) - (prev.stats[stat] ?? 0))}',
    for (final axis in _keys(prev.states, next.states))
      if ((next.states[axis] ?? 0) != (prev.states[axis] ?? 0) && !(axis == 'DIVINE_SHIELD' && divineShieldSpent))
        _stateLabel(axis, prev.states[axis] ?? 0, next.states[axis] ?? 0),
  ];
  return pieces.isEmpty ? 'sans effet' : pieces.join(' · ');
}

List<String> _keys(Map<String, int> a, Map<String, int> b) => ({...a.keys, ...b.keys}.toList()..sort());

String _signed(int n) => n < 0 ? '−${-n}' : '+$n';

/// A state counter is a signed duration (STATE-1): its sign tells which state of the axis holds it.
String _stateLabel(String axis, int prev, int next) {
  final sign = next != 0 ? next.sign : prev.sign;
  return '${_axisState(axis, sign)} · ${next.abs()} t.';
}

String _axisState(String axis, int sign) => switch (axis) {
  'SPEED' => sign > 0 ? 'Hâte' : 'Lenteur',
  'VITALITY' => sign > 0 ? 'Régénération' : 'Poison',
  'STUN' => 'Étourdi',
  'ROOT' => 'Enraciné',
  'DIVINE_SHIELD' => 'Bouclier divin',
  _ => axis,
};

String _stateName(String state) => switch (state) {
  'HASTE' => 'Hâte',
  'SLOW' => 'Lenteur',
  'REGEN' => 'Régénération',
  'POISON' => 'Poison',
  'STUN' => 'Étourdi',
  'ROOT' => 'Enraciné',
  'DIVINE_SHIELD' => 'Bouclier divin',
  _ => state,
};

String _statName(String stat) => switch (stat) {
  'POWER' => 'Puissance',
  'ARMOR' => 'Armure',
  _ => stat,
};

/// "7 dégâts, en face et voisins → Morrow, cellule vide, Ysolde", one clause per effect that played.
/// `effects[i]` is the effect `face.effects[i]` gave; the log stops early when the actor dies during its action.
String _describe(List<ResolvedEffect> effects, DieFace face, List<CharacterView> before) {
  if (effects.isEmpty) return 'face vide';
  return [
    for (var i = 0; i < effects.length; i++)
      _clause(effects[i], i < face.effects.length ? face.effects[i] : null, before),
  ].join(' ; ');
}

/// The face effect is trusted only when its parts are the ones logged: a timeline started from a stale board (a face
/// rerolled since) is then worded from the log alone, without values or targeting.
String _clause(ResolvedEffect effect, FaceEffect? face, List<CharacterView> before) {
  final authored = face != null && _sameParts(face, effect) ? face : null;
  final parts = authored == null ? effect.parts.map(_partWord).join(' + ') : authored.parts.map(_partText).join(' + ');
  final targeting = authored == null ? '' : ', ${_targeting(authored.targets)}';
  final names = effect.fizzled
      ? 'aucune cellule'
      : effect.targets.map((cell) => _livingAt(before, cell)?.name ?? 'cellule vide').join(', ');
  return '$parts$targeting → $names';
}

bool _sameParts(FaceEffect face, ResolvedEffect effect) =>
    face.parts.length == effect.parts.length &&
    [for (var i = 0; i < face.parts.length; i++) face.parts[i].part == effect.parts[i]].every((same) => same);

/// The word of a logged part, which carries no value.
String _partWord(String part) => switch (part) {
  'Damage' => 'dégâts',
  'FixedDamage' => 'dégâts fixes',
  'Heal' => 'soin',
  'Shield' => 'bouclier',
  'Swap' => 'échange',
  'ApplyStat' => 'stat',
  'ApplyState' => 'état',
  _ => part,
};

/// The words of one part of a face, with the value written on the face.
///
/// Duplicates in spirit `actionLabels` of `resolve_game.dart`, which imports Flame: that one goes away with the Flame
/// Resolve scene.
String _partText(FacePart p) {
  final duration = p.duration == null ? '' : ' (${p.duration} t.)';
  return switch (p.part) {
    'Damage' => '${p.magnitude} dégâts',
    'FixedDamage' => '${p.magnitude} dégâts fixes',
    'Heal' => 'soin ${p.magnitude}',
    'Shield' => 'bouclier ${p.magnitude}',
    'Swap' => 'échange',
    'ApplyStat' => '${_statName(p.stat ?? '')} ${_signed(p.magnitude)}$duration',
    'ApplyState' => '${_stateName(p.state ?? '')}$duration',
    _ => '${p.part} ${p.magnitude}',
  };
}

/// A short French phrase for the cells a face aims at (TGT rules): RELATIVE offsets are read from the actor's cell,
/// ABSOLUTE ones are slots.
String _targeting(List<TargetGroup> groups) => groups.map(_group).join(' et ');

String _group(TargetGroup g) {
  final ally = g.side == 'ALLY';
  final n = g.n.toSet();
  if (g.mode == 'ABSOLUTE') {
    if (n.length == boardSize && n.every((s) => s >= 0 && s < boardSize)) {
      return ally ? 'tous les alliés' : 'tous les ennemis';
    }
    final slots = (n.toList()..sort()).join(', ');
    if (n.length == 1) return ally ? 'cellule alliée $slots' : 'cellule ennemie $slots';
    return ally ? 'cellules alliées $slots' : 'cellules ennemies $slots';
  }
  final words = <String>[if (n.contains(0)) ally ? 'soi' : 'en face'];
  final others = n.difference({0});
  if (others.any((o) => o.abs() > 1)) {
    words.add(ally ? 'alliés' : 'ennemis');
  } else if (others.length == 2) {
    words.add(ally ? 'alliés voisins' : 'voisins');
  } else if (others.length == 1) {
    words.add(ally ? 'allié voisin' : 'voisin');
  }
  return words.join(' et ');
}
