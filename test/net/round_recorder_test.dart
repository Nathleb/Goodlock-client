import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/round_recorder.dart';

Map<String, dynamic> keep(int n) => {'phase': 'KEEP_PHASE', 'n': n};

void main() {
  test('pairs each resolved round with the first board sent after the previous round', () {
    final recorder = RoundRecorder()
      ..onState(keep(1))
      ..onState(keep(2))
      ..onResolved({'round': 1})
      ..onState(keep(3))
      ..onState(keep(4))
      ..onResolved({'round': 2});

    expect(recorder.starts, [keep(1), keep(3)]);
    expect(recorder.resolved, [
      {'round': 1},
      {'round': 2},
    ]);
  });

  test('ignores boards that are not a KEEP_PHASE broadcast', () {
    final recorder = RoundRecorder()
      ..onState({'phase': 'PLACEMENT', 'n': 0})
      ..onState(keep(1))
      ..onState({'phase': 'GAME_OVER', 'n': 2})
      ..onResolved({'round': 1});

    expect(recorder.starts, [keep(1)]);
  });

  test('skips a resolved round that no board preceded', () {
    final recorder = RoundRecorder()
      ..onResolved({'round': 1})
      ..onState(keep(1))
      ..onResolved({'round': 2});

    expect(recorder.starts, [keep(1)]);
    expect(recorder.resolved, [
      {'round': 2},
    ]);
  });

  test('never pairs two rounds with the same board', () {
    final recorder = RoundRecorder()
      ..onState(keep(1))
      ..onResolved({'round': 1})
      ..onResolved({'round': 2});

    expect(recorder.resolved, [
      {'round': 1},
    ]);
  });
}
