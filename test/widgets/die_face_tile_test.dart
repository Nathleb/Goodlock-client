import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/widgets/die_face_tile.dart';

void main() {
  test('FixedDamage has its own colour, distinct from Damage', () {
    expect(effectColors['FixedDamage'], isNotNull);
    expect(effectColors['FixedDamage'], isNot(effectColors['Damage']));
  });
}
