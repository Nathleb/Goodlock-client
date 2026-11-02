import 'models.dart';

/// Records a match for offline replay: each `roundResolved` paired with the first
/// KEEP_PHASE `gameStateUpdated` broadcast since the previous round, the board the
/// round really started from (after the server's start-of-round upkeep, which the
/// client cannot recompute). Later boards of the same round are private echoes or
/// rerolls, so they are ignored.
class RoundRecorder {
  final List<Json> starts = [];
  final List<Json> resolved = [];
  Json? _roundStart;

  void onState(Json state) {
    if (state['phase'] != 'KEEP_PHASE') return;
    _roundStart ??= state;
  }

  void onResolved(Json round) {
    final start = _roundStart;
    if (start == null) return;
    starts.add(start);
    resolved.add(round);
    _roundStart = null;
  }
}
