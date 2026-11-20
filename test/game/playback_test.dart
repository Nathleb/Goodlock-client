import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/playback.dart';
import 'package:goodlock_app/net/models.dart';

const _face = DieFace('f', 0, []);

CharacterView ch(
  String id, {
  int hp = 10,
  int shield = 0,
  int pi = 0,
  int slot = 0,
}) => CharacterView(
  id: id,
  catalogId: id,
  name: id,
  hp: hp,
  maxHp: 10,
  shield: shield,
  baseSpeed: 1,
  baseDie: const [_face, _face, _face, _face, _face, _face],
  face: _face,
  faceIndex: 0,
  isFaceLocked: false,
  position: Cell(pi, slot),
);

void main() {
  test('startOfNextRound clears shields and keeps everything else', () {
    final next = startOfNextRound([ch('a', hp: 4, shield: 3, slot: 2)]).single;
    expect((next.hp, next.shield, next.position), (4, 0, const Cell(0, 2)));
  });
}
