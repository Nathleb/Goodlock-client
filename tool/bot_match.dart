// Two bots play a full match against a running backend.
//
//   dart run tool/bot_match.dart --server http://localhost:3000 [--record test/fixtures]
//
// Doubles as the end-to-end check of collection -> decks -> team preview -> combat:
// it fails (exit 1) on any server error or if a secret leaks before combat.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:goodlock_app/net/api.dart';
import 'package:goodlock_app/net/game_socket.dart';
import 'package:goodlock_app/net/models.dart';

const maxRounds = 60;
final rng = Random(42);

class Bot {
  final String name;
  final Api api;
  late final GameSocket socket;
  late final String sessionId;
  late final String deckId;
  int me = -1;

  bool _picked = false;
  bool _placed = false;
  String? _lastKeepKey;
  bool combatStarted = false;
  final failures = <String>[];

  Bot(this.name, String server) : api = Api(server);

  Future<void> setUp(String server) async {
    final tokens = await api.register(name, 'password123');
    deckId = (await api.decks()).first.id;
    socket = GameSocket(server, tokens.accessToken);
    socket.errors.listen((m) => failures.add('$name got error: $m'));
    final sid = socket.sessionId;
    await socket.connect();
    sessionId = await sid.timeout(const Duration(seconds: 5));
  }

  void seat(RoomView room) => me = room.players.indexWhere((p) => p.playerId == sessionId);

  void onState(GameStateView gs) {
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
}

Future<void> main(List<String> args) async {
  final server = _arg(args, '--server') ?? 'http://localhost:3000';
  final recordDir = _arg(args, '--record');
  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final a = Bot('botA_$stamp', server);
  final b = Bot('botB_$stamp', server);

  try {
    await a.setUp(server);
    await b.setUp(server);
    stdout.writeln('connected: ${a.name} (${a.sessionId}), ${b.name} (${b.sessionId})');

    // Lobby
    final created = a.socket.rooms.first;
    a.socket.createRoom();
    final roomId = (await created.timeout(const Duration(seconds: 5))).roomId;

    final bothReady = a.socket.rooms.firstWhere((r) => r.players.length == 2 && r.players.every((p) => p.hasDeck));
    b.socket.joinRoom(roomId);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    a.socket.selectDeck(a.deckId);
    b.socket.selectDeck(b.deckId);
    final room = await bothReady.timeout(const Duration(seconds: 5));
    a.seat(room);
    b.seat(room);
    stdout.writeln('room $roomId: seats A=${a.me} B=${b.me}, both decks chosen');
    if (a.me == b.me || a.me < 0 || b.me < 0) throw StateError('could not resolve seats');

    // Game
    var rounds = 0;
    final recorded = <Json>[];
    if (recordDir != null) a.socket.onRaw('roundResolved', recorded.add);
    a.socket.resolved.listen((r) {
      rounds++;
      final dead = r.gameState.players.map((p) => p.team.where((c) => c.isDead).length).toList();
      stdout.writeln('round $rounds resolved: ${r.resolveLog.length} steps, dead per side $dead');
    });
    final over = a.socket.gameOver.first;
    a.socket.states.listen(a.onState);
    b.socket.states.listen(b.onState);
    a.socket.startGame();

    final result = await Future.any([
      over,
      Future<GameOver>.delayed(const Duration(minutes: 2), () => throw TimeoutException('no gameOver')),
      a.socket.resolved.where((_) => rounds >= maxRounds).first.then((_) => throw StateError('too many rounds')),
    ]);
    stdout.writeln('game over: winner=${result.winner} reason=${result.reason} after $rounds rounds');

    final failures = [...a.failures, ...b.failures];
    if (!a.combatStarted || !b.combatStarted) failures.add('combat never started');
    if (recordDir != null && recorded.isNotEmpty) {
      final file = File('$recordDir/round_resolved.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(recorded.take(3).toList()));
      stdout.writeln('recorded ${min(3, recorded.length)} roundResolved payloads to ${file.path}');
    }
    if (failures.isNotEmpty) {
      stderr.writeln('FAILED:\n- ${failures.join('\n- ')}');
      exitCode = 1;
    } else {
      stdout.writeln('OK: full match played, no secret leaked before combat');
    }
  } catch (e) {
    stderr.writeln('FAILED: $e');
    exitCode = 1;
  } finally {
    for (final bot in [a, b]) {
      try {
        bot.socket.dispose();
      } catch (_) {}
    }
  }
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}
