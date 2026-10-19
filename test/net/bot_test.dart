import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/bot.dart';

void main() {
  group('placementSlots', () {
    const team = ['a', 'b', 'c', 'd'];

    test('lays the 4 characters on 5 cells with exactly one empty cell', () {
      final slots = placementSlots(team, Random(1));
      expect(slots, hasLength(5));
      expect(slots.where((s) => s == null), hasLength(1));
      expect(slots.whereType<String>().toList()..sort(), team);
    });

    test('moves the empty cell around depending on the seed', () {
      final holes = {for (var seed = 0; seed < 40; seed++) placementSlots(team, Random(seed)).indexOf(null)};
      expect(holes.length, greaterThan(1));
    });
  });
}
