import 'package:flutter/material.dart';

import '../app/session.dart';
import '../game/human_match_controller.dart';
import '../net/models.dart';
import '../net/vs_bot.dart';
import 'selection_screen.dart';

/// A match of the player against a bot, from the room set-up to the result. The screens of each phase
/// are drawn from [HumanMatchController].
class HumanMatchScreen extends StatefulWidget {
  final AppSession session;
  final String deckId;
  const HumanMatchScreen({super.key, required this.session, required this.deckId});

  @override
  State<HumanMatchScreen> createState() => _HumanMatchScreenState();
}

class _HumanMatchScreenState extends State<HumanMatchScreen> {
  VsBotMatch? _match;
  HumanMatchController? _controller;
  String _status = 'Mise en place du match…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final match = await seatVsBot(widget.session, widget.deckId);
      if (!mounted) {
        match.dispose();
        return;
      }
      setState(() {
        _match = match;
        _controller = HumanMatchController(match.socket, me: match.me);
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Échec : $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _match?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (controller == null) ...[
              const Positioned(left: 4, top: 4, child: BackButton()),
              Center(child: Text(_status)),
            ] else
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => switch (controller.phase) {
                    Phase.selection => SelectionScreen(controller: controller),
                    _ => Center(child: Text(_describe(controller.phase))),
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _describe(Phase? phase) => switch (phase) {
        null => 'En attente du serveur…',
        _ => 'Phase : ${phase.name}',
      };
}
