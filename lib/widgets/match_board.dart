import 'package:flutter/material.dart';

import '../net/models.dart';
import '../net/rules.dart';
import 'cell_tile.dart';
import 'dashed_box.dart';

/// The board in two facing columns (LAYOUT-3): the viewer on the left, the opponent on the right, cells 0
/// to 4 from top to bottom, each cell level with the cell it faces. An empty cell is dashed (LAYOUT-4). The
/// free lane in the middle takes [center] (a caption, a message).
class MatchBoard extends StatelessWidget {
  final List<PlayerView> players;
  final int me;

  /// The ids of my characters whose die is kept, in the Keep being edited.
  final Set<String> locks;

  /// Called with the id of my character when its face is tapped; null when faces cannot be tapped.
  final void Function(String characterId)? onFaceTap;
  final Widget? center;
  const MatchBoard({
    super.key,
    required this.players,
    required this.me,
    this.locks = const {},
    this.onFaceTap,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(flex: 5, child: _side(players[me], mine: true)),
          Expanded(flex: 2, child: Center(child: center)),
          Expanded(flex: 5, child: _side(players[1 - me], mine: false)),
        ],
      ),
    );
  }

  Widget _side(PlayerView player, {required bool mine}) {
    final bySlot = {for (final c in player.team) c.position.slot: c};
    return Column(
      children: [
        for (var slot = 0; slot < boardSize; slot++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: bySlot[slot] == null
                  ? const DashedBox(child: Center(child: Text('vide')))
                  : CellTile(
                      character: bySlot[slot]!,
                      mine: mine,
                      locked: mine && locks.contains(bySlot[slot]!.id),
                      onFaceTap: mine && onFaceTap != null ? () => onFaceTap!(bySlot[slot]!.id) : null,
                    ),
            ),
          ),
      ],
    );
  }
}
