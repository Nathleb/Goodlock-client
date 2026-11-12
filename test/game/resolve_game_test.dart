import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/character_token.dart';
import 'package:goodlock_app/game/playback.dart';
import 'package:goodlock_app/game/resolve_game.dart';
import 'package:goodlock_app/net/models.dart';
import 'package:goodlock_app/net/rules.dart';

List<RoundResolved> loadRounds() => (jsonDecode(
  File('test/fixtures/round_resolved.json').readAsStringSync(),
) as List).map((j) => RoundResolved.fromJson(j as Json)).toList();

Future<ResolveGame> pumpGame(WidgetTester tester, {int viewerIndex = 0}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final game = ResolveGame(viewerIndex: viewerIndex)..haptics = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: GameWidget(game: game)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return game;
}

void main() {
  testWidgets('plays every recorded round to the end without errors', (
    tester,
  ) async {
    final game = await pumpGame(tester);
    final rounds = loadRounds();
    for (var i = 1; i < rounds.length; i++) {
      final before = startOfNextRound(
        rounds[i - 1].gameState.players.expand((p) => p.team).toList(),
      );
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

  testWidgets(
    'DEAD-1, CELL-6: a character who dies leaves its cell at the step where it dies',
    (tester) async {
      const f = DieFace('f', 0, []);
      CharacterView ch(String id, int pi, int slot, {int hp = 10}) => CharacterView(
        id: id,
        catalogId: id,
        name: id,
        hp: hp,
        maxHp: 10,
        shield: 0,
        baseSpeed: 1,
        baseDie: const [f, f, f, f, f, f],
        face: f,
        isFaceLocked: false,
        position: Cell(pi, slot),
      );
      final game = await pumpGame(tester);
      final before = [ch('killer', 0, 1), ch('victim', 1, 1, hp: 3), ch('other', 1, 3)];
      final log = [
        ResolveStep('killer', false, const [ResolvedEffect('Damage', [Cell(1, 1)])], [
          ResolveChange('victim', ch('victim', 1, 1, hp: 0)),
        ]),
        ResolveStep('other', false, const [ResolvedEffect('Heal', [Cell(1, 3)])], [
          ResolveChange('other', ch('other', 1, 3)),
        ]),
        const ResolveStep('victim', true, [], []),
      ];
      final onBoardAtStep = <String, Set<String>>{};
      game.caption.addListener(() {
        final text = game.caption.value;
        if (text.isNotEmpty) onBoardAtStep[text] = {...game.onBoard};
      });

      game.speed = 6;
      final done = game.playRound(before, log);
      var frames = 0;
      while (game.isPlaying && frames < 2000) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      await done;

      final captions = onBoardAtStep.keys.toList();
      expect(captions, hasLength(2), reason: 'the fallen actor has no step on the board: $captions');
      expect(onBoardAtStep[captions[0]], containsAll(['killer', 'victim', 'other']));
      expect(onBoardAtStep[captions[1]], {'killer', 'other'});
      expect(game.onBoard, {'killer', 'other'});
      expect(
        game.world.children.whereType<CharacterToken>().map((t) => t.character.id).toSet(),
        {'killer', 'other'},
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lays the board out in two facing columns, slot 0 on top', (
    tester,
  ) async {
    final game = await pumpGame(tester);
    for (var slot = 0; slot < boardSize; slot++) {
      expect(
        game.cellCenter(Cell(0, slot)).x,
        lessThan(game.cellCenter(Cell(1, slot)).x),
        reason: 'viewer column on the left',
      );
      expect(
        game.cellCenter(Cell(0, slot)).y,
        game.cellCenter(Cell(1, slot)).y,
        reason: 'facing cells share a row',
      );
    }
    for (var slot = 1; slot < boardSize; slot++) {
      expect(
        game.cellCenter(Cell(0, slot)).y,
        greaterThan(game.cellCenter(Cell(0, slot - 1)).y),
      );
    }
    expect(game.cardSize.y * boardSize, lessThanOrEqualTo(game.size.y));
  });

  testWidgets('puts the viewer on the left whichever seat they hold', (
    tester,
  ) async {
    final game = await pumpGame(tester, viewerIndex: 1);
    expect(
      game.cellCenter(const Cell(1, 0)).x,
      lessThan(game.cellCenter(const Cell(0, 0)).x),
    );
  });
}
