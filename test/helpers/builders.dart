import 'package:goodlock_app/net/models.dart';

const blankFace = DieFace('rest', 0, []);

/// A character on the board with a die of six identical faces.
CharacterView character(
  String id, {
  required int side,
  required int slot,
  int hp = 20,
  int maxHp = 20,
  bool locked = false,
  DieFace face = blankFace,
  Map<String, int> states = const {},
  int shield = 0,
}) =>
    CharacterView(
      id: id,
      catalogId: 'cat-$id',
      name: 'Name $id',
      hp: hp,
      maxHp: maxHp,
      shield: shield,
      baseSpeed: 3,
      baseDie: List.filled(6, face),
      face: face,
      isFaceLocked: locked,
      position: Cell(side, slot),
      states: states,
    );

/// A deck of six catalog characters, ids `<prefix>0` to `<prefix>5`.
List<CatalogCharacter> deckOf(String prefix) =>
    [for (var i = 0; i < 6; i++) CatalogCharacter('$prefix$i', 'Char $prefix$i', 20 + i, 2 + i, List.filled(6, blankFace))];

List<PlayerClock> clocksOf({int mine = 600000, int theirs = 600000, bool running = true}) => [
      PlayerClock(remainingMs: mine, reconnectionMs: 180000, running: running, connected: true),
      PlayerClock(remainingMs: theirs, reconnectionMs: 180000, running: running, connected: true),
    ];

GameStateView stateOf(
  Phase phase, {
  int round = 0,
  int rollsLeft = 2,
  bool myReady = false,
  List<CharacterView> mine = const [],
  List<CharacterView> theirs = const [],
  SelectionView? selection,
  List<PlayerClock>? clocks,
}) =>
    GameStateView(
      phase: phase,
      currentRound: round,
      initiativePlayerIndex: 0,
      rollsLeft: rollsLeft,
      myReady: myReady,
      clocks: clocks ?? clocksOf(),
      players: [PlayerView(0, mine), PlayerView(1, theirs)],
      selection: selection,
    );
