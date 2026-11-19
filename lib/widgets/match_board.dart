import 'package:flutter/material.dart';

import '../game/step_outcome.dart';
import '../net/models.dart';
import '../net/rules.dart';
import 'cell_tile.dart';
import 'dashed_box.dart';
import 'die_face_tile.dart';

/// The board in two facing columns (LAYOUT-3): the viewer on the left, the opponent on the right, cells 0
/// to 4 from top to bottom, each cell level with the cell it faces. An empty cell is dashed (LAYOUT-4). The
/// free lane in the middle takes [center] (a caption, a message), or the labels of [outcome] when one is given.
class MatchBoard extends StatelessWidget {
  final List<PlayerView> players;
  final int me;

  /// The ids of my characters whose die is kept, in the Keep being edited.
  final Set<String> locks;

  /// Called with the id of my character when its face is tapped; null when faces cannot be tapped.
  final void Function(String characterId)? onFaceTap;

  /// Called with the character whose portrait is tapped, on either side (CELL-5); null when portraits cannot be tapped.
  final void Function(CharacterView character)? onPortraitTap;
  final Widget? center;

  /// The step on display (STEP-1..4): its actor is ringed and comes forward, its target cells get the colour of their
  /// effect and a label in the lane, level with the cell. [players] is then the board after the step.
  final StepOutcome? outcome;

  /// CELL-3: character id -> HP at the start of the round; each bar marks the HP lost since.
  final Map<String, int>? roundStartHp;
  const MatchBoard({
    super.key,
    required this.players,
    required this.me,
    this.locks = const {},
    this.onFaceTap,
    this.onPortraitTap,
    this.center,
    this.outcome,
    this.roundStartHp,
  });

  static const _actorScale = 1.05;
  static const _neutral = Colors.white54;

  @override
  Widget build(BuildContext context) {
    final actor = _actor();
    final board = Row(
      children: [
        Expanded(flex: 5, child: _side(players[me], mine: true, actor: actor)),
        Expanded(flex: 2, child: outcome == null ? Center(child: center) : _lane(context, actor)),
        Expanded(flex: 5, child: _side(players[1 - me], mine: false, actor: actor)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(8),
      child: actor == null
          ? board
          // The actor's cell is laid out over the same grid, last, so it is painted above its neighbours and the lane.
          : Stack(
              fit: StackFit.expand,
              children: [
                board,
                Row(
                  children: [
                    Expanded(flex: 5, child: actor.position.playerIndex == me ? _actorColumn(actor) : const SizedBox()),
                    const Spacer(flex: 2),
                    Expanded(flex: 5, child: actor.position.playerIndex == me ? const SizedBox() : _actorColumn(actor)),
                  ],
                ),
              ],
            ),
    );
  }

  /// The acting character, as it stands on the board on display; null with no outcome or when it is off the board.
  CharacterView? _actor() {
    final id = outcome?.actorId;
    if (id == null) return null;
    for (final p in players) {
      for (final c in p.team) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  Color _colorOf(CellOutcome target) => effectColors[target.part] ?? _neutral;

  CellOutcome? _targetAt(Cell cell) {
    for (final target in outcome?.cells ?? const <CellOutcome>[]) {
      if (target.cell == cell) return target;
    }
    return null;
  }

  Widget _rows(Widget Function(int slot) row) => Column(
    children: [
      for (var slot = 0; slot < boardSize; slot++)
        Expanded(
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: row(slot)),
        ),
    ],
  );

  Widget _side(PlayerView player, {required bool mine, required CharacterView? actor}) {
    final bySlot = {for (final c in player.team) c.position.slot: c};
    return _rows((slot) {
      final character = bySlot[slot];
      final target = _targetAt(Cell(player.playerIndex, slot));
      final targetKey = ValueKey('target-${player.playerIndex}-$slot');
      if (character == null) {
        return target == null
            ? const DashedBox(child: Center(child: Text('vide')))
            : DashedBox(
                key: targetKey,
                color: _colorOf(target),
                child: const Center(child: Text('vide')),
              );
      }
      // The actor is drawn over the board (see build); its place here stays free.
      if (character.id == actor?.id) return const SizedBox.shrink();
      return _cell(character, target, targetKey, mine: mine);
    });
  }

  Widget _cell(CharacterView character, CellOutcome? target, Key targetKey, {required bool mine}) {
    Widget tile = CellTile(
      character: character,
      mine: mine,
      locked: mine && locks.contains(character.id),
      onFaceTap: mine && onFaceTap != null ? () => onFaceTap!(character.id) : null,
      onPortraitTap: onPortraitTap == null ? null : () => onPortraitTap!(character),
      roundStartHp: roundStartHp?[character.id],
    );
    if (target != null) tile = _bordered(tile, key: targetKey, color: _colorOf(target));
    return tile;
  }

  Widget _actorColumn(CharacterView actor) {
    final cell = actor.position;
    final mine = cell.playerIndex == me;
    return _rows((slot) {
      if (slot != cell.slot) return const SizedBox.shrink();
      final tile = _cell(actor, _targetAt(cell), ValueKey('target-${cell.playerIndex}-${cell.slot}'), mine: mine);
      return Transform.scale(
        scale: _actorScale,
        child: _bordered(tile, key: ValueKey('actor-ring-${actor.id}'), color: Colors.white, width: 2.5, outside: true),
      );
    });
  }

  Widget _bordered(Widget child, {required Key key, required Color color, double width = 2, bool outside = false}) =>
      DecoratedBox(
        key: key,
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color,
            width: width,
            strokeAlign: outside ? BorderSide.strokeAlignOutside : BorderSide.strokeAlignInside,
          ),
        ),
        child: child,
      );

  /// The lane during a step: in each row, the label of my cell on the left, the opponent's on the right (STEP-2..4).
  Widget _lane(BuildContext context, CharacterView? actor) {
    final style = Theme.of(context).textTheme.labelSmall;
    Widget label(int player, int slot, {required Alignment at}) {
      final target = _targetAt(Cell(player, slot));
      final skipped = target == null && outcome!.skipped && actor != null && actor.position == Cell(player, slot);
      final (String, Color, Key)? shown = target != null
          ? (target.label, _colorOf(target), ValueKey('label-$player-$slot'))
          : skipped
          ? ('Action annulée (étourdi)', _neutral, ValueKey('skipped-${actor.id}'))
          : null;
      return Expanded(
        child: Align(
          alignment: at,
          child: shown == null
              ? null
              : Text(
                  shown.$1,
                  key: shown.$3,
                  style: style?.copyWith(color: shown.$2),
                  textAlign: at == Alignment.centerLeft ? TextAlign.left : TextAlign.right,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      );
    }

    final theirs = 1 - me;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: _rows(
        (slot) => Row(
          children: [
            label(me, slot, at: Alignment.centerLeft),
            label(theirs, slot, at: Alignment.centerRight),
          ],
        ),
      ),
    );
  }
}
