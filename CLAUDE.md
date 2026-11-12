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

## Reference docs

Read these before planning, they are not loaded automatically:

- `../Goodlock-specs/GAME-DESIGN.md`: the rules reference, in the language of the game, one ID per
  rule. Read before any change that displays or depends on a mechanic. It lives in the specs space,
  isolated from the code: read it, never write there (permission denied). When a change needs a new
  or different rule, stop and tell the user.
- `../Goodlock-back/docs/GLOSSARY.md`: the game terms of the rules mapped to the code names.
- `../Goodlock-back/docs/features/active/<topic>/design.md`: the approved spec of a feature in
  progress, including its client contract.

The client has its own `docs/features/active/<topic>/`, same topic and date as the backend feature it
follows, laid out like the backend's. A folder is kept only while its feature is in progress: it is
deleted once the feature is shipped (git keeps the history).

- `design.md`, only when the feature needs UI decisions to be settled (screens, interactions,
  animation behavior). It links the backend `design.md` for rules and protocol instead of copying it.
- `plan.md`, always: ordered steps, each with the test to write first.

A feature that is purely client-side (UX, animation) has a client `design.md` and `plan.md` and no
backend spec. Merge the backend PR first, since it owns the protocol.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
dart run tool/bot_match.dart --server http://localhost:3000   # two bots play a full match (backend must run)
tool/sync_protocol.sh                                       # copy the backend protocol schema into test/protocol/
flutter build apk --debug                                   # build/app/outputs/flutter-apk/app-debug.apk
```

Flutter SDK: `~/development/flutter` (on `PATH` via `~/.zshrc`). Android SDK: `~/Android/Sdk`.

## Layout

```
lib/net/      REST + Socket.IO client, protocol models (fromJson)
lib/screens/  Flutter screens (Material 3, forced landscape, touch targets >= 44 px)
lib/game/     Flame components and scenes
tool/         dev scripts (headless bot match, phone.sh: wireless-debugging loop)
test/         unit/widget tests; test/fixtures/ holds real payloads recorded from the backend;
              test/protocol/ holds the synced backend schema and its validation helpers
```

## Rules

- Mobile first: judge feel on a device build, not on an emulator or desktop.
- Forced landscape, full screen (immersive). The combat board is two facing columns: the viewer on the
  left, the opponent on the right, slot 0 on top, the centre band free for captions and controls.
- The server is the source of truth for every outcome and every die roll: the client animates what it sent. The only local computation is the preview of the round from the locked dice (the rules are deterministic), which is recomputed on every lock or reroll and never replaces what the server resolves.
- Protocol models mirror backend DTOs exactly; parsing is unit-tested against recorded payloads. The backend's `protocol/protocol.schema.json` is copied to `test/protocol/` by `tool/sync_protocol.sh` (run it after a protocol change, then re-record the fixtures with `bot_match --record`); the fixtures and the hand-written payloads of the tests are validated against it.
- Game sizes (deck 6, team 4, board 5 cells with one empty) live in `lib/net/rules.dart`, mirrored from the
  backend; position a character by `position.slot`, never by its index in `team`.
- Before combat (SELECTION, PLACEMENT) the server never sends the opponent's picks or team; don't build
  UI that assumes them.
- TDD for anything non-visual. Conventional commits.
