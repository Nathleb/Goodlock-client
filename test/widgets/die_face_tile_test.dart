import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/widgets/die_face_tile.dart';

void main() {
  test('FixedDamage has its own colour, distinct from Damage', () {
    expect(effectColors['FixedDamage'], isNotNull);
    expect(effectColors['FixedDamage'], isNot(effectColors['Damage']));
  });

  test('ApplyStat has its own colour, distinct from Damage, FixedDamage and Shield', () {
    expect(effectColors['ApplyStat'], isNotNull);
    expect(effectColors['ApplyStat'], isNot(effectColors['Damage']));
    expect(effectColors['ApplyStat'], isNot(effectColors['FixedDamage']));
    expect(effectColors['ApplyStat'], isNot(effectColors['Shield']));
  });

  test('ApplyState has its own colour, distinct from the other effects', () {
    final c = effectColors['ApplyState'];
    expect(c, isNotNull);
    for (final k in ['Damage', 'FixedDamage', 'Shield', 'Swap', 'ApplyStat']) {
      expect(c, isNot(effectColors[k]));
    }
  });
}
