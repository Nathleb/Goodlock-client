// Protocol models mirroring Goodlock-back DTOs (src/application/dtos/).
// Pure Dart (no Flutter import) so headless tools can use them too.

typedef Json = Map<String, dynamic>;

List<T> _list<T>(Object? raw, T Function(Json) parse) =>
    (raw as List? ?? const []).map((e) => parse(e as Json)).toList(growable: false);

/// A board cell: which side, which slot.
class Cell {
  final int playerIndex;
  final int slot;
  const Cell(this.playerIndex, this.slot);

  factory Cell.fromJson(Json j) => Cell(j['playerIndex'] as int, j['slot'] as int);

  @override
  bool operator ==(Object other) => other is Cell && other.playerIndex == playerIndex && other.slot == slot;
  @override
  int get hashCode => Object.hash(playerIndex, slot);
  @override
  String toString() => 'Cell($playerIndex, $slot)';
}

enum Phase {
  selection('SELECTION_PHASE'),
  placement('PLACEMENT_PHASE'),
  roll('ROLL_PHASE'),
  keep('KEEP_PHASE'),
  resolve('RESOLVE_PHASE'),
  result('RESULT_PHASE'),
  unknown('');

  final String wire;
  const Phase(this.wire);

  static Phase parse(String raw) => values.firstWhere((p) => p.wire == raw, orElse: () => Phase.unknown);
}

class TargetGroup {
  final String side; // ALLY | ENEMY
  final String mode; // ABSOLUTE | RELATIVE
  final List<int> n;
  const TargetGroup(this.side, this.mode, this.n);

  factory TargetGroup.fromJson(Json j) =>
      TargetGroup(j['side'] as String, j['mode'] as String, List<int>.from(j['n'] as List));
}

class FaceEffect {
  final String effect;
  final int magnitude;
  final List<TargetGroup> targets;
  final String? stat; // ApplyStat only
  final int? duration; // ApplyStat only, in rounds
  const FaceEffect(this.effect, this.magnitude, this.targets, {this.stat, this.duration});

  factory FaceEffect.fromJson(Json j) => FaceEffect(
        j['effect'] as String,
        j['magnitude'] as int,
        _list(j['targets'], TargetGroup.fromJson),
        stat: j['stat'] as String?,
        duration: j['duration'] as int?,
      );
}

/// An active buff/debuff instance on a character.
class StatInstance {
  final String stat;
  final int value;
  final int roundsLeft;
  const StatInstance(this.stat, this.value, this.roundsLeft);

  factory StatInstance.fromJson(Json j) =>
      StatInstance(j['stat'] as String, j['value'] as int, j['roundsLeft'] as int);
}

class DieFace {
  final String description;
  final int priority;
  final List<FaceEffect> effects;
  const DieFace(this.description, this.priority, this.effects);

  factory DieFace.fromJson(Json j) =>
      DieFace(j['description'] as String, j['priority'] as int, _list(j['effects'], FaceEffect.fromJson));
}

/// A catalog character (collection screen, team preview decks).
class CatalogCharacter {
  final String id;
  final String name;
  final int maxHp;
  final int baseSpeed;
  final List<DieFace> baseDie;
  final DateTime? acquiredAt; // collection only

  const CatalogCharacter(this.id, this.name, this.maxHp, this.baseSpeed, this.baseDie, [this.acquiredAt]);

  factory CatalogCharacter.fromJson(Json j) => CatalogCharacter(
        j['id'] as String,
        j['name'] as String,
        j['maxHp'] as int,
        j['baseSpeed'] as int,
        _list(j['baseDie'], DieFace.fromJson),
        j['acquiredAt'] == null ? null : DateTime.parse(j['acquiredAt'] as String),
      );
}

/// A character inside a match.
class CharacterView {
  final String id;
  final String catalogId;
  final String name;
  final int hp;
  final int maxHp;
  final int shield;
  final int baseSpeed;
  final List<DieFace> baseDie;
  final DieFace face;
  final bool isFaceLocked;
  final Cell position;
  final List<StatInstance> modifiers;
  final Map<String, int> stats; // net value per stat, already capped by the server

  const CharacterView({
    required this.id,
    required this.catalogId,
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.shield,
    required this.baseSpeed,
    required this.baseDie,
    required this.face,
    required this.isFaceLocked,
    required this.position,
    this.modifiers = const [],
    this.stats = const {},
  });

  bool get isDead => hp <= 0;

  CharacterView copyWith({int? hp, int? shield, Cell? position, DieFace? face, bool? isFaceLocked}) => CharacterView(
        id: id,
        catalogId: catalogId,
        name: name,
        hp: hp ?? this.hp,
        maxHp: maxHp,
        shield: shield ?? this.shield,
        baseSpeed: baseSpeed,
        baseDie: baseDie,
        face: face ?? this.face,
        isFaceLocked: isFaceLocked ?? this.isFaceLocked,
        position: position ?? this.position,
        modifiers: modifiers,
        stats: stats,
      );

  factory CharacterView.fromJson(Json j) => CharacterView(
        id: j['id'] as String,
        catalogId: j['catalogId'] as String? ?? '',
        name: j['name'] as String,
        hp: j['hp'] as int,
        maxHp: j['maxHp'] as int,
        shield: j['shield'] as int,
        baseSpeed: j['baseSpeed'] as int,
        baseDie: _list(j['baseDie'], DieFace.fromJson),
        face: DieFace.fromJson(j['face'] as Json),
        isFaceLocked: j['isFaceLocked'] as bool,
        position: Cell.fromJson(j['position'] as Json),
        modifiers: _list(j['modifiers'], StatInstance.fromJson),
        stats: ((j['stats'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, v as int)),
      );
}

class PlayerView {
  final int playerIndex;
  final List<CharacterView> team;
  const PlayerView(this.playerIndex, this.team);

  factory PlayerView.fromJson(Json j) => PlayerView(j['playerIndex'] as int, _list(j['team'], CharacterView.fromJson));
}

/// Team preview, per viewer: both revealed decks and only my own pick.
class SelectionView {
  final List<List<CatalogCharacter>> decks;
  final List<String>? myPicks;
  const SelectionView(this.decks, this.myPicks);

  factory SelectionView.fromJson(Json j) => SelectionView(
        (j['decks'] as List).map((d) => _list(d, CatalogCharacter.fromJson)).toList(growable: false),
        j['myPicks'] == null ? null : List<String>.from(j['myPicks'] as List),
      );
}

class GameStateView {
  final Phase phase;
  final int currentRound;
  final int initiativePlayerIndex;
  final int rollsLeft;
  final List<bool> playersReady;
  final List<PlayerView> players;
  final SelectionView? selection;
  final int? afkClaimInMs;

  const GameStateView({
    required this.phase,
    required this.currentRound,
    required this.initiativePlayerIndex,
    required this.rollsLeft,
    required this.playersReady,
    required this.players,
    this.selection,
    this.afkClaimInMs,
  });

  factory GameStateView.fromJson(Json j) => GameStateView(
        phase: Phase.parse(j['phase'] as String),
        currentRound: j['currentRound'] as int,
        initiativePlayerIndex: (j['initiativePlayerIndex'] as int?) ?? 0,
        rollsLeft: j['rollsLeft'] as int,
        playersReady: List<bool>.from(j['playersReady'] as List),
        players: _list(j['players'], PlayerView.fromJson),
        selection: j['selection'] == null ? null : SelectionView.fromJson(j['selection'] as Json),
        afkClaimInMs: j['afkClaimInMs'] as int?,
      );
}

class RoomPlayer {
  final String playerId;
  final bool isOwner;
  final bool hasDeck;
  const RoomPlayer(this.playerId, this.isOwner, this.hasDeck);

  factory RoomPlayer.fromJson(Json j) =>
      RoomPlayer(j['playerId'] as String, j['isOwner'] as bool, j['hasDeck'] as bool? ?? false);
}

class RoomView {
  final String roomId;
  final String ownerId;
  final bool isStarted;
  final List<RoomPlayer> players;
  const RoomView(this.roomId, this.ownerId, this.isStarted, this.players);

  factory RoomView.fromJson(Json j) => RoomView(
        j['roomId'] as String,
        j['ownerId'] as String,
        j['isStarted'] as bool,
        _list(j['players'], RoomPlayer.fromJson),
      );
}

class ResolvedEffect {
  final String effect;
  final List<Cell> targets;
  const ResolvedEffect(this.effect, this.targets);

  bool get fizzled => targets.isEmpty;

  factory ResolvedEffect.fromJson(Json j) => ResolvedEffect(j['effect'] as String, _list(j['targets'], Cell.fromJson));
}

class ResolveChange {
  final String characterId;
  final CharacterView after;
  const ResolveChange(this.characterId, this.after);

  factory ResolveChange.fromJson(Json j) =>
      ResolveChange(j['characterId'] as String, CharacterView.fromJson(j['after'] as Json));
}

class ResolveStep {
  final String characterId;
  final bool skipped;
  final List<ResolvedEffect> effects;
  final List<ResolveChange> changes;
  const ResolveStep(this.characterId, this.skipped, this.effects, this.changes);

  factory ResolveStep.fromJson(Json j) => ResolveStep(
        j['characterId'] as String,
        j['skipped'] as bool,
        _list(j['effects'], ResolvedEffect.fromJson),
        _list(j['changes'], ResolveChange.fromJson),
      );
}

class RoundResolved {
  final GameStateView gameState;
  final List<ResolveStep> resolveLog;
  const RoundResolved(this.gameState, this.resolveLog);

  factory RoundResolved.fromJson(Json j) =>
      RoundResolved(GameStateView.fromJson(j['gameState'] as Json), _list(j['resolveLog'], ResolveStep.fromJson));
}

class GameOver {
  final Object winner; // 0, 1 or 'draw'
  final String reason;
  const GameOver(this.winner, this.reason);

  bool get isDraw => winner == 'draw';

  factory GameOver.fromJson(Json j) => GameOver(j['winner'] as Object, j['reason'] as String);
}

class Deck {
  final String id;
  final String name;
  final List<String> characterIds;
  const Deck(this.id, this.name, this.characterIds);

  factory Deck.fromJson(Json j) =>
      Deck(j['id'] as String, j['name'] as String, List<String>.from(j['characterIds'] as List));
}
