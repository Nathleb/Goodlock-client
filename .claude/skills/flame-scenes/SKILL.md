---
name: flame-scenes
description: Conventions for Goodlock-app Flame game scenes (board, Resolve animation, character tokens). Use before adding or changing anything in lib/game/.
---

# Flame scenes

`lib/game/` holds the combat board. Embed it in a screen with `GameWidget`; screens around it follow
the `flutter-screens` skill.

## Structure

- `playback.dart` is pure Dart: `planRound` turns the server's resolve log into `StepPlan`s of `Beat`s
  by diffing each change against the running state. No Flame import, fully unit-testable.
- `resolve_game.dart` (`ResolveGame extends FlameGame with HasTimeScale`) plays those beats: it owns
  layout, the effect colors per label, shakes, hit-stop and haptics.
- `character_token.dart` is one card on the board.

Keep that split: decide *what happened* in `playback.dart`, decide *how it looks* in the game.

## Rules

- Display only. Every number on screen comes from the server's `changes`; animate it, never
  recompute it.
- Layout: two facing columns of `boardSize` cells, the viewer on the left, slot 0 on top. Position by
  `position.slot`, never by index in `team`. Sizes come from `lib/net/rules.dart`.
- A new effect label gets an entry in `_effectColors` and, if it changes a stat the diff does not
  cover yet, a new `BeatKind` in `playback.dart` (test first). Unknown labels must not crash.
- Animations are `Future`-based: `await` an effect through the `_fx` helper, run simultaneous
  reactions with `Future.wait`. Do not leave a bare `Future` running (`unawaited` only on purpose, as
  `_hitStop` does), or `isPlaying` lies and rounds overlap.
- All durations go through `HasTimeScale` / `speed`, so tests can run at speed 6 and a player can
  skip. Never use a raw `Future.delayed` for animation timing; use the game's `_wait`.
- Haptics go through the `haptics` flag so tests can switch them off (`..haptics = false`).
- Keep the cell frames faint: an empty cell must still read as a cell.

## Tests

- Beats: `test/game/playback_test.dart`, against recorded rounds in `test/fixtures/round_resolved.json`.
- Scene: `test/game/resolve_game_test.dart` plays every recorded round to the end and checks the
  board layout and a golden (`test/game/goldens/board.png`). Pump a 1920x1080 view at DPR 3.
- A golden that changes on purpose is regenerated with `flutter test --update-goldens`, and only after
  looking at the new image. Never regenerate to silence a diff you do not understand.
- Feel (timing, shake strength, haptics) is judged on a phone with `tool/phone.sh run`, not in tests.

## Checks

`flutter analyze` and `flutter test` must pass. After a protocol change, replay the headless bots:
`dart run tool/bot_match.dart --server http://localhost:3000` (backend running).
