import 'models.dart';

/// Records a match for offline replay: each `roundResolved` paired with the last
/// `gameStateUpdated` sent before it, the board the round really started from
/// (after the server's start-of-round upkeep, which the client cannot recompute).
class RoundRecorder {
  final List<Json> starts = [];
  final List<Json> resolved = [];
  Json? _lastState;

  void onState(Json state) => _lastState = state;

  void onResolved(Json round) {
    final start = _lastState;
    if (start == null) return;
    starts.add(start);
    resolved.add(round);
    _lastState = null;
  }
}
