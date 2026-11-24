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

  /// The space between a cell and its neighbour above or below, split between the two rows.
  static const _rowGap = 3.0;

  /// How far the actor's cell comes forward on its left and right (STEP-1). Less than [_padding] and [_laneInset], so
  /// it stays on the screen and off the lane labels; up and down it fills the gap between rows.
  static const _lift = 4.0;
  static const _padding = 8.0;
  static const _laneInset = 8.0;
  static const _neutral = Colors.white54;

  @override
  Widget build(BuildContext context) {
    final actor = _actor();
    // One shape whatever the notch, so the cells keep their state when the playhead moves.
    return Padding(
      padding: const EdgeInsets.all(_padding),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              Expanded(flex: 5, child: _side(players[me], mine: true, actor: actor)),
              Expanded(flex: 2, child: outcome == null ? Center(child: center) : _lane(context, actor)),
              Expanded(flex: 5, child: _side(players[1 - me], mine: false, actor: actor)),
            ],
          ),
          // The actor's cell is laid out over the same grid, last, so it is painted above its neighbours and the lane.
          Row(
            children: [
              Expanded(flex: 5, child: _actorColumn(actor, mine: true)),
              const Spacer(flex: 2),
              Expanded(flex: 5, child: _actorColumn(actor, mine: false)),
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

  Widget _rows(Widget Function(int slot) row, {Key? key}) => Column(
    key: key,
    children: [
      for (var slot = 0; slot < boardSize; slot++)
        Expanded(
          child: Padding(padding: const EdgeInsets.symmetric(vertical: _rowGap), child: row(slot)),
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

  /// The column of my side ([mine]) or of the opponent's, holding the actor's cell when the actor stands there.
  Widget _actorColumn(CharacterView? actor, {required bool mine}) {
    if (actor == null || (actor.position.playerIndex == me) != mine) return const SizedBox.shrink();
    final cell = actor.position;
    return _rows((slot) {
      if (slot != cell.slot) return const SizedBox.shrink();
      final tile = _cell(actor, _targetAt(cell), ValueKey('target-${cell.playerIndex}-${cell.slot}'), mine: mine);
      // It comes forward: laid out bigger than its place, over the gaps around it, ringed on its inner edge.
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -_lift,
            right: -_lift,
            top: -_rowGap,
            bottom: -_rowGap,
            child: _bordered(tile, key: ValueKey('actor-ring-${actor.id}'), color: Colors.white, width: 2.5),
          ),
        ],
      );
    });
  }

  Widget _bordered(Widget child, {required Key key, required Color color, double width = 2}) => DecoratedBox(
    key: key,
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color, width: width),
    ),
    child: child,
  );

  /// The lane during a step: in each row, the label of my cell on the left, the opponent's on the right (STEP-2..4).
  /// A label alone in its row takes the whole lane; two share it in halves.
  Widget _lane(BuildContext context, CharacterView? actor) {
    final style = Theme.of(context).textTheme.labelSmall;
    Widget? label(int player, int slot, {required bool mine}) {
      final target = _targetAt(Cell(player, slot));
      final skipped = target == null && outcome!.skipped && actor != null && actor.position == Cell(player, slot);
      final (String, Color, Key)? shown = target != null
          ? (target.label, _colorOf(target), ValueKey('label-$player-$slot'))
          : skipped
          ? ('Action annulée (étourdi)', _neutral, ValueKey('skipped-${actor.id}'))
          : null;
      if (shown == null) return null;
      return Expanded(
        child: Align(
          alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
          child: Text(
            shown.$1,
            key: shown.$3,
            style: style?.copyWith(color: shown.$2),
            textAlign: mine ? TextAlign.left : TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _laneInset),
      child: _rows(key: const ValueKey('lane'), (slot) {
        final left = label(me, slot, mine: true);
        final right = label(1 - me, slot, mine: false);
        return Row(
          children: [
            ?left,
            if (left != null && right != null) const SizedBox(width: 4),
            ?right,
          ],
        );
      }),
    );
  }
}
