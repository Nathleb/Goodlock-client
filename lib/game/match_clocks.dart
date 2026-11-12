import 'dart:math';

import '../net/models.dart';

/// The clocks of a match as the viewer sees them between two messages of the server (CLOCK-2, AWAY-2).
///
/// Only the viewer's own clock counts down locally, while the server says it runs. The opponent's
/// thinking time stays as the last state gave it and changes only when the next state arrives, at the
/// end of a decision phase: it never shows whether the opponent has confirmed (GAME-9). The
/// reconnection time of a disconnected player is public and counts down for both (GAME-7).
/// Pure Dart: time is a parameter.
class MatchClocks {
  final int viewerIndex;
  final List<_Reading?> _readings = [null, null];
  DateTime? _stoppedAt;

  MatchClocks(this.viewerIndex);

  /// Takes the clocks of a state received at [at]. A state without clocks keeps those shown.
  void onState(GameStateView gs, DateTime at) {
    if (gs.clocks.length != 2) return;
    for (var i = 0; i < 2; i++) {
      _readings[i] = _Reading(gs.clocks[i], at);
    }
  }

  /// A player disconnected or came back at [at]: their reconnection time starts or stops from the value sent.
  void onPresence(PresenceChanged p, DateTime at) {
    final settled = read(p.playerIndex, at);
    if (settled == null) return;
    _readings[p.playerIndex] =
        _Reading(settled.copyWith(connected: p.connected, reconnectionMs: p.reconnectionMs), at);
  }

  /// The match ended at [at]: the clocks stop where they are.
  void stop(DateTime at) => _stoppedAt ??= at;

  /// The clock of [playerIndex] at [now], or null before the first state that carries clocks.
  PlayerClock? read(int playerIndex, DateTime now) {
    final reading = _readings[playerIndex];
    if (reading == null) return null;
    final stoppedAt = _stoppedAt;
    final until = stoppedAt != null && stoppedAt.isBefore(now) ? stoppedAt : now;
    final elapsed = max(0, until.difference(reading.at).inMilliseconds);
    final c = reading.clock;
    final countsDown = playerIndex == viewerIndex && c.running;
    return c.copyWith(
      remainingMs: countsDown ? max(0, c.remainingMs - elapsed) : c.remainingMs,
      reconnectionMs: c.connected ? c.reconnectionMs : max(0, c.reconnectionMs - elapsed),
    );
  }
}

class _Reading {
  final PlayerClock clock;
  final DateTime at;
  const _Reading(this.clock, this.at);
}

/// A time as minutes and seconds ("9:05"), rounded up: "0:00" only once the time is out.
String formatClock(int ms) {
  final seconds = (max(0, ms) + 999) ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
