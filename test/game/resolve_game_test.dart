import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/playback.dart';
import 'package:goodlock_app/game/resolve_game.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/net/rules.dart';

List<RoundResolved> loadRounds() => (jsonDecode(File('test/fixtures/round_resolved.json').readAsStringSync()) as List)
    .map((j) => RoundResolved.fromJson(j as Json))
    .toList();

Future<ResolveGame> pumpGame(WidgetTester tester, {int viewerIndex = 0}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final game = ResolveGame(viewerIndex: viewerIndex)..haptics = false;
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameWidget(game: game))));
  await tester.pump(const Duration(milliseconds: 50));
  return game;
}

void main() {
  testWidgets('plays every recorded round to the end without errors', (tester) async {
    final game = await pumpGame(tester);
    final rounds = loadRounds();
    for (var i = 1; i < rounds.length; i++) {
      final before = startOfNextRound(rounds[i - 1].gameState.players.expand((p) => p.team).toList());
      game.speed = 6;
      final done = game.playRound(before, rounds[i].resolveLog);
      var frames = 0;
      while (game.isPlaying && frames < 4000) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      await done;
      expect(game.isPlaying, isFalse, reason: 'round ${i + 1} did not finish');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays the board out in two facing columns, slot 0 on top', (tester) async {
    final game = await pumpGame(tester);
    for (var slot = 0; slot < boardSize; slot++) {
      expect(game.cellCenter(Cell(0, slot)).x, lessThan(game.cellCenter(Cell(1, slot)).x), reason: 'viewer column on the left');
      expect(game.cellCenter(Cell(0, slot)).y, game.cellCenter(Cell(1, slot)).y, reason: 'facing cells share a row');
    }
    for (var slot = 1; slot < boardSize; slot++) {
      expect(game.cellCenter(Cell(0, slot)).y, greaterThan(game.cellCenter(Cell(0, slot - 1)).y));
    }
    expect(game.cardSize.y * boardSize, lessThanOrEqualTo(game.size.y));
  });

  testWidgets('puts the viewer on the left whichever seat they hold', (tester) async {
    final game = await pumpGame(tester, viewerIndex: 1);
    expect(game.cellCenter(const Cell(1, 0)).x, lessThan(game.cellCenter(const Cell(0, 0)).x));
  });

  testWidgets('board layout snapshot', (tester) async {
    final game = await pumpGame(tester);
    final rounds = loadRounds();
    game.setBoard(rounds[1].gameState.players.expand((p) => p.team).toList());
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(find.byType(GameWidget<ResolveGame>), matchesGoldenFile('goldens/board.png'));
  });
}
