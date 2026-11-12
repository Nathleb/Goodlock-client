import 'dart:async';

import 'package:flutter/material.dart';

import '../game/match_clocks.dart';
import '../net/models.dart';

/// Both clocks in the status bar (LAYOUT-2): mine on the left, the opponent's on the right, like the
/// board (LAYOUT-3). A disconnected player also shows the reconnection time they have left (AWAY-2).
/// Repaints a few times a second; [now] is injectable for tests.
class MatchClocksBar extends StatefulWidget {
  final MatchClocks clocks;
  final DateTime Function() now;
  const MatchClocksBar({super.key, required this.clocks, this.now = DateTime.now});

  @override
  State<MatchClocksBar> createState() => _MatchClocksBarState();
}

class _MatchClocksBarState extends State<MatchClocksBar> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now();
    final me = widget.clocks.viewerIndex;
    final mine = widget.clocks.read(me, now);
    final theirs = widget.clocks.read(1 - me, now);
    return Row(
      children: [
        if (mine != null) _ClockChip(key: const Key('clock-me'), label: 'Moi', clock: mine),
        const Spacer(),
        if (theirs != null) _ClockChip(key: const Key('clock-opponent'), label: 'Adversaire', clock: theirs),
      ],
    );
  }
}

class _ClockChip extends StatelessWidget {
  final String label;
  final PlayerClock clock;
  const _ClockChip({super.key, required this.label, required this.clock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final low = clock.remainingMs < 30000;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 16, color: low ? Colors.redAccent : null),
              const SizedBox(width: 4),
              Text('$label ${formatClock(clock.remainingMs)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: low ? Colors.redAccent : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
          if (!clock.connected)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 14, color: Colors.orangeAccent),
                const SizedBox(width: 4),
                Text('Reconnexion ${formatClock(clock.reconnectionMs)}',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.orangeAccent)),
              ],
            ),
        ],
      ),
    );
  }
}
