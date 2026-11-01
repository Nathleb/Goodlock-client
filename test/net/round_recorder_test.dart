import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/round_recorder.dart';

void main() {
  test('pairs each resolved round with the last board sent before it', () {
    final recorder = RoundRecorder()
      ..onState({'phase': 'ROLL_PHASE', 'n': 1})
      ..onState({'phase': 'ROLL_PHASE', 'n': 2})
      ..onResolved({'round': 1})
      ..onState({'phase': 'ROLL_PHASE', 'n': 3})
      ..onResolved({'round': 2});

    expect(recorder.starts, [
      {'phase': 'ROLL_PHASE', 'n': 2},
      {'phase': 'ROLL_PHASE', 'n': 3},
    ]);
    expect(recorder.resolved, [
      {'round': 1},
      {'round': 2},
    ]);
  });

  test('skips a resolved round that no board preceded', () {
    final recorder = RoundRecorder()
      ..onResolved({'round': 1})
      ..onState({'n': 1})
      ..onResolved({'round': 2});

    expect(recorder.starts, [
      {'n': 1},
    ]);
    expect(recorder.resolved, [
      {'round': 2},
    ]);
  });

  test('never pairs two rounds with the same board', () {
    final recorder = RoundRecorder()
      ..onState({'n': 1})
      ..onResolved({'round': 1})
      ..onResolved({'round': 2});

    expect(recorder.resolved, [
      {'round': 1},
    ]);
  });
}
