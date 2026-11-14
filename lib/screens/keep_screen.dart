import 'package:flutter/material.dart';

import '../game/human_match_controller.dart';
import '../widgets/match_bar.dart';
import '../widgets/match_board.dart';

/// KEEP-1, FLOW-3: the player taps their own faces to keep or release them, then confirms. The board is the
/// same as in the other phases; the dice kept in the first Keep start out kept in the second.
class KeepScreen extends StatelessWidget {
  final HumanMatchController controller;
  const KeepScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        return Column(
          children: [
            MatchBar(controller: controller),
            Expanded(
              child: state == null
                  ? const Center(child: Text('En attente du serveur…'))
                  : MatchBoard(
                      players: state.players,
                      me: controller.me,
                      locks: controller.locks,
                      onFaceTap: controller.ready ? null : controller.toggleLock,
                      center: Text(
                        controller.ready ? 'Annule pour modifier tes dés.' : 'Touche tes faces pour les garder.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
