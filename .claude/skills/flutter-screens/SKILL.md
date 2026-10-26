---
name: flutter-screens
description: Conventions for Goodlock-app Flutter screens (login, collection, decks, play, lobby). Use before adding or changing anything in lib/screens/ or lib/widgets/.
---

# Flutter screens

Screens are plain Material 3 widgets. The game board is not a screen: it is Flame (see the `flame-scenes` skill).

## Layout

- The app is forced landscape and immersive. Height is the scarce axis: put navigation on the side
  (`NavigationRail`, as in `home_screen.dart`), not in a bottom bar, and avoid tall headers.
- Touch targets are at least 44 px. Prefer `ListTile` with `minVerticalPadding`, `Card`, and
  `IconButton` over small custom taps.
- Scrolling content goes in `ListView` or `GridView`; never assume a fixed viewport size.

## State and data

- A screen takes the shared `AppSession` (`lib/app/session.dart`) through its constructor. No
  global singletons.
- Network access goes through `lib/net/api.dart` (HTTP: auth, collection, decks) and
  `lib/net/game_socket.dart` (lobby and match). Never call `http` or the socket from a widget directly.
- The client is display-only. Show what the server sent; never compute an outcome, a legal move
  or a damage number locally.
- Sizes (deck 6, team 4, board 5 cells) come from `lib/net/rules.dart`, never from literals.
- Before combat (SELECTION, PLACEMENT) the opponent's picks and team are never sent. Do not build UI
  that expects them.
- A new field on a model: check the backend DTO first (`../Goodlock-back/src/application/dtos/`),
  mirror it exactly in `lib/net/models.dart`, and add a recorded payload under `test/fixtures/`.

## Tests

- Non-visual logic is TDD: red test first. Parsing is tested against recorded payloads in
  `test/fixtures/`, not hand-written JSON.
- A screen with behavior gets a widget test in `test/screens/` (see `login_screen_test.dart`).
  Pump with a landscape size, as `test/game/resolve_game_test.dart` does.
- Pure layout is judged on a phone, not in a test: build with `tool/phone.sh run` and look.
  An emulator or desktop window does not tell you how it feels.

## Checks

`flutter analyze` and `flutter test` must pass. Strings shown to the player are currently French
(`'Jouer'`, `'Déconnexion'`); keep that consistent within a screen.
