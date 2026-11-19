import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/net/models.dart';

Map<String, dynamic> faceJson({String description = 'combo', int priority = 1, int magnitude = 4}) => {
      'description': description,
      'priority': priority,
      'effects': [
        {
          'targets': [
            {'side': 'ENEMY', 'mode': 'RELATIVE', 'n': [0, 1]}
          ],
          'parts': [
            {'part': 'Damage', 'magnitude': magnitude},
            {'part': 'ApplyState', 'magnitude': 0, 'state': 'POISON', 'duration': 2},
          ],
        }
      ],
    };

void main() {
  test('two faces parsed from the same payload are equal, with the same hash', () {
    final a = DieFace.fromJson(faceJson());
    final b = DieFace.fromJson(faceJson());
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('faces differ by description, priority or any effect', () {
    final base = DieFace.fromJson(faceJson());
    expect(base, isNot(DieFace.fromJson(faceJson(description: 'other'))));
    expect(base, isNot(DieFace.fromJson(faceJson(priority: 0))));
    expect(base, isNot(DieFace.fromJson(faceJson(magnitude: 5))));
    expect(base, isNot(const DieFace('combo', 1, [])));
  });

  test('a target group is equal by side, mode and cells, in order', () {
    expect(const TargetGroup('ENEMY', 'RELATIVE', [0, 1]), TargetGroup('ENEMY', 'RELATIVE', [0, 1]));
    expect(TargetGroup('ENEMY', 'RELATIVE', [0, 1]).hashCode, TargetGroup('ENEMY', 'RELATIVE', [0, 1]).hashCode);
    expect(const TargetGroup('ENEMY', 'RELATIVE', [0, 1]), isNot(const TargetGroup('ALLY', 'RELATIVE', [0, 1])));
    expect(const TargetGroup('ENEMY', 'RELATIVE', [0, 1]), isNot(const TargetGroup('ENEMY', 'ABSOLUTE', [0, 1])));
    expect(const TargetGroup('ENEMY', 'RELATIVE', [0, 1]), isNot(const TargetGroup('ENEMY', 'RELATIVE', [1, 0])));
    expect(const TargetGroup('ENEMY', 'RELATIVE', [0, 1]), isNot(const TargetGroup('ENEMY', 'RELATIVE', [0])));
    expect(const TargetGroup('ENEMY', 'RELATIVE', [0]), isNot(const TargetGroup('ENEMY', 'RELATIVE', [0, 1])));
  });

  test('a part is equal by kind, magnitude, stat, state and duration', () {
    const part = FacePart('ApplyStat', -2, stat: 'POWER', duration: 2);
    // Parsed, so not the same const instance.
    final same = FacePart.fromJson({'part': 'ApplyStat', 'magnitude': -2, 'stat': 'POWER', 'duration': 2});
    expect(part, same);
    expect(part.hashCode, same.hashCode);
    expect(part, isNot(const FacePart('ApplyState', -2, stat: 'POWER', duration: 2)));
    expect(part, isNot(const FacePart('ApplyStat', -1, stat: 'POWER', duration: 2)));
    expect(part, isNot(const FacePart('ApplyStat', -2, stat: 'SPEED', duration: 2)));
    expect(part, isNot(const FacePart('ApplyStat', -2, stat: 'POWER', state: 'STUN', duration: 2)));
    expect(part, isNot(const FacePart('ApplyStat', -2, stat: 'POWER', duration: 1)));
  });

  test('an effect is equal by its target groups and its parts, in order', () {
    const effect = FaceEffect([TargetGroup('ALLY', 'ABSOLUTE', [0])], [FacePart('Heal', 2), FacePart('Shield', 1)]);
    final same = FaceEffect([TargetGroup('ALLY', 'ABSOLUTE', [0])], [FacePart('Heal', 2), FacePart('Shield', 1)]);
    expect(effect, same);
    expect(effect.hashCode, same.hashCode);
    expect(effect, isNot(const FaceEffect([TargetGroup('ALLY', 'ABSOLUTE', [1])], [FacePart('Heal', 2), FacePart('Shield', 1)])));
    expect(effect, isNot(const FaceEffect([TargetGroup('ALLY', 'ABSOLUTE', [0])], [FacePart('Shield', 1), FacePart('Heal', 2)])));
  });

  test('the current face of a parsed character is found in its die', () {
    final die = [for (var i = 0; i < 6; i++) DieFace.fromJson(faceJson(description: 'f$i'))];
    final current = DieFace.fromJson(faceJson(description: 'f3'));
    expect(die.indexOf(current), 3);
  });
}
