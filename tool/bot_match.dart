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

import 'package:goodlock_app/net/bot.dart';
import 'package:goodlock_app/net/models.dart';

const maxRounds = 60;
const maxRecorded = 8;

Future<void> main(List<String> args) async {
  final server = _arg(args, '--server') ?? 'http://localhost:3000';
  final recordDir = _arg(args, '--record');
  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final rng = Random(int.tryParse(_arg(args, '--seed') ?? '') ?? 42);
  final a = Bot('botA_$stamp', server, rng: rng);
  final b = Bot('botB_$stamp', server, rng: rng);

  try {
    await a.setUp();
    await b.setUp();
    stdout.writeln('connected: ${a.name} (${a.sessionId}), ${b.name} (${b.sessionId})');
    final room = await seatBots(a, b);
    stdout.writeln('room ${room.roomId}: seats A=${a.me} B=${b.me}, both decks chosen');

    var rounds = 0;
    final recorded = <Json>[];
    if (recordDir != null) a.socket.onRaw('roundResolved', recorded.add);
    a.socket.resolved.listen((r) {
      rounds++;
      final dead = r.gameState.players.map((p) => p.team.where((c) => c.isDead).length).toList();
      stdout.writeln('round $rounds resolved: ${r.resolveLog.length} steps, dead per side $dead');
    });
    final over = a.socket.gameOver.first;
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
      final kept = recorded.take(maxRecorded).toList();
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(kept));
      stdout.writeln('recorded ${kept.length} roundResolved payloads to ${file.path}');
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
    a.dispose();
    b.dispose();
  }
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}
