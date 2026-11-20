// The playhead of a round timeline (TL-4, TL-6): which notch the board shows, and its playback.
// No widget: the screen listens to it and draws the notch.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// A notch index along a timeline of [notchCount] notches, and the playback that moves it (TL-6).
///
/// Playback moves one notch per [stepDelay] and stops on the stop notch: the last one (FLOW-5), or the
/// `haltAt` notch given to [load] (FLOW-6). Every gesture (seek, fast forward, pause, [stop]) stops it.
/// Each change notifies the listeners once; [load] always notifies, any other call that changes nothing does not.
class Playhead extends ChangeNotifier {
  Playhead({this._stepDelay = const Duration(milliseconds: 900)});

  Duration _stepDelay;
  int _notch = 0;
  int _notchCount = 0;
  int? _haltAt;
  Timer? _timer;

  int get notch => _notch;
  int get notchCount => _notchCount;
  bool get playing => _timer != null;
  bool get atEnd => _notch == _notchCount - 1;

  int get _lastNotch => _notchCount - 1;
  int get _stopNotch => _haltAt ?? _lastNotch;

  Duration get stepDelay => _stepDelay;

  /// The time between two notches; a change applies at once to the playback in progress (x1/x2).
  set stepDelay(Duration value) {
    if (value == _stepDelay) return;
    _stepDelay = value;
    if (playing) _startTimer();
    notifyListeners();
  }

  /// A new timeline (a new Roll, a new Resolve): back to notch 0, paused (TL-6), or playing if [autoplay]
  /// (FLOW-4). The playback then stops on [haltAt] instead of the last notch (FLOW-6).
  void load(int notchCount, {bool autoplay = false, int? haltAt}) {
    if (notchCount < 2) throw ArgumentError.value(notchCount, 'notchCount', 'must be at least 2');
    if (haltAt != null && (haltAt < 1 || haltAt >= notchCount)) {
      throw ArgumentError.value(haltAt, 'haltAt', 'must be in 1..${notchCount - 1}');
    }
    _cancelTimer();
    _notchCount = notchCount;
    _haltAt = haltAt;
    _notch = 0;
    if (autoplay) _startTimer();
    notifyListeners();
  }

  /// Moves one notch per [stepDelay] up to the stop notch. A playhead on the stop notch or past it starts again
  /// from 0 (TL-6): on the last notch, and with a `haltAt`, on that notch or anywhere after it (after a fast
  /// forward, say).
  void play() {
    if (_notchCount == 0 || playing) return;
    if (_notch >= _stopNotch) _notch = 0;
    _startTimer();
    notifyListeners();
  }

  void pause() {
    if (!playing) return;
    _cancelTimer();
    notifyListeners();
  }

  void togglePlay() => playing ? pause() : play();

  /// The last notch, even past `haltAt`.
  void fastForward() {
    if (_notchCount == 0) return;
    _moveTo(_lastNotch);
  }

  /// Dragging: [fraction] (0..1) along the timeline, snapped to the nearest notch. A NaN fraction (a drag along
  /// a track of no width) is ignored.
  void seek(double fraction) {
    if (_notchCount == 0 || fraction.isNaN) return;
    _moveTo((fraction.clamp(0.0, 1.0) * _lastNotch).round());
  }

  /// Tapping a token or a notch.
  void seekToNotch(int notch) {
    if (_notchCount == 0) return;
    _moveTo(notch.clamp(0, _lastNotch));
  }

  /// Stops the playback, e.g. when the die view opens (TL-6).
  void stop() => pause();

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  void _moveTo(int notch) {
    if (notch == _notch && !playing) return;
    _cancelTimer();
    _notch = notch;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_stepDelay, (_) => _advance());
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _advance() {
    _notch++;
    if (_notch >= _stopNotch) _cancelTimer();
    notifyListeners();
  }
}
