import 'dart:math';

import 'api.dart';
import 'game_socket.dart';
import 'models.dart';
import 'rules.dart';

/// A scripted player: registers, takes a seat and answers every confirm phase.
/// Used by tool/bot_match.dart and by the in-app live demo (two bots, one watched).
class Bot {
  final String name;
  final String server;
  final Api api;
  final Random rng;
  late final GameSocket socket;
  late final String sessionId;
  late final String deckId;
  int me = -1;

  bool _picked = false;
  bool _placed = false;
  String? _lastKeepKey;
  bool combatStarted = false;
  final failures = <String>[];

  Bot(this.name, this.server, {Random? rng})
      : api = Api(server),
        rng = rng ?? Random();

  Future<void> setUp() async {
    final tokens = await api.register(name, 'password123');
    deckId = (await api.decks()).first.id;
    socket = GameSocket(server, tokens.accessToken);
    socket.errors.listen((m) => failures.add('$name got error: $m'));
    final sid = socket.sessionId;
    await socket.connect();
    sessionId = await sid.timeout(const Duration(seconds: 5));
    socket.states.listen(onState);
  }

  void seat(RoomView room) => me = room.players.indexWhere((p) => p.playerId == sessionId);

  void onState(GameStateView gs) {
    if (me < 0) return;
    final opponent = gs.players[1 - me];
    if (gs.phase == Phase.roll || gs.phase == Phase.keep) combatStarted = true;
    if (!combatStarted && opponent.team.isNotEmpty) {
      failures.add('$name saw the opponent team before combat (${gs.phase})');
    }
    final ready = gs.playersReady[me];

    switch (gs.phase) {
      case Phase.selection:
        final sel = gs.selection;
        if (sel == null) {
          failures.add('$name: SELECTION without selection view');
          return;
        }
        if (sel.decks.any((d) => d.length != 7)) failures.add('$name: decks are not 7-strong');
        if (!ready && !_picked) {
          _picked = true;
          final mine = sel.decks[me].map((c) => c.id).toList()..shuffle(rng);
          socket.confirmSelection(mine.take(5).toList());
        }
      case Phase.placement:
        if (gs.players[me].team.length != 5) failures.add('$name: own team is not 5 at placement');
        if (!ready && !_placed) {
          _placed = true;
          final ids = gs.players[me].team.map((c) => c.id).toList().reversed.toList();
          socket.rearrangeTeam(ids);
          socket.confirmPlacement();
        }
      case Phase.keep:
        final key = '${gs.currentRound}/${gs.rollsLeft}';
        if (!ready && _lastKeepKey != key) {
          _lastKeepKey = key;
          final alive = gs.players[me].team.where((c) => !c.isDead).map((c) => c.id).toList();
          socket.confirmKeep(alive.where((_) => rng.nextBool()).toList());
        }
      default:
        break;
    }
  }

  void dispose() {
    try {
      socket.dispose();
    } catch (_) {}
  }
}

/// A random board layout for [teamIds]: every character once, the remaining cells empty (null).
List<String?> placementSlots(List<String> teamIds, Random rng) =>
    <String?>[...teamIds, ...List<String?>.filled(boardSize - teamIds.length, null)]..shuffle(rng);

/// Puts two set-up bots in a room with their decks chosen; returns the room.
Future<RoomView> seatBots(Bot owner, Bot guest) async {
  final created = owner.socket.rooms.first;
  owner.socket.createRoom();
  final roomId = (await created.timeout(const Duration(seconds: 5))).roomId;

  final ready = owner.socket.rooms.firstWhere((r) => r.players.length == 2 && r.players.every((p) => p.hasDeck));
  final joined = guest.socket.rooms.firstWhere((r) => r.players.length == 2);
  guest.socket.joinRoom(roomId);
  await joined.timeout(const Duration(seconds: 5));
  owner.socket.selectDeck(owner.deckId);
  guest.socket.selectDeck(guest.deckId);
  final room = await ready.timeout(const Duration(seconds: 5));
  owner.seat(room);
  guest.seat(room);
  if (owner.me == guest.me || owner.me < 0 || guest.me < 0) throw StateError('could not resolve seats');
  return room;
}
