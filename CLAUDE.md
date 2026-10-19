# CLAUDE.md

Guidance for Claude Code in this repository.

## Project

`Goodlock-app` is the mobile client for Goodlock, a tactical PvP dice game. **Flutter** for the app
screens (login, collection, decks, lobby), **Flame** for the game scenes (board, Resolve animation).
Status: **prototype** (Oct 2026) to validate Flutter + Flame on a real phone before replacing the old
React/Capacitor client (`Goodlock-frontend`).

The backend is `../Goodlock-back` (NestJS + Socket.IO 4). It is the **source of truth for the protocol**:
DTOs in `Goodlock-back/src/application/dtos/`, events in
`Goodlock-back/src/infrastructure/adapters/websocket/session.gateway.ts`. Read them before changing a model.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
dart run tool/bot_match.dart --server http://localhost:3000   # two bots play a full match (backend must run)
flutter build apk --debug                                   # build/app/outputs/flutter-apk/app-debug.apk
```

Flutter SDK: `~/development/flutter` (on `PATH` via `~/.zshrc`). Android SDK: `~/Android/Sdk`.

## Layout

```
lib/net/      REST + Socket.IO client, protocol models (fromJson)
lib/screens/  Flutter screens (Material 3, forced landscape, touch targets >= 44 px)
lib/game/     Flame components and scenes
tool/         dev scripts (headless bot match, phone.sh: wireless-debugging loop)
test/         unit/widget tests; test/fixtures/ holds real payloads recorded from the backend
```

## Rules

- Mobile first: judge feel on a device build, not on an emulator or desktop.
- Forced landscape, full screen (immersive). The combat board is two facing columns: the viewer on the
  left, the opponent on the right, slot 0 on top, the centre band free for captions and controls.
- The client is display-only: never compute game outcomes locally; animate what the server sent.
- Protocol models mirror backend DTOs exactly; parsing is unit-tested against recorded payloads.
- Game sizes (deck 6, team 4, board 5 cells with one empty) live in `lib/net/rules.dart`, mirrored from the
  backend; position a character by `position.slot`, never by its index in `team`.
- Before combat (SELECTION, PLACEMENT) the server never sends the opponent's picks or team; don't build
  UI that assumes them.
- TDD for anything non-visual. Conventional commits.
