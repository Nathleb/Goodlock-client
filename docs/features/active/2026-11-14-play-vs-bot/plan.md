# Play a match against a bot — plan

Each step: its tests first (red), then the code, `flutter analyze` and `flutter test` green, one commit. Steps are stacked PRs, each opened on the previous one.

- [x] **1 controller and entry**: `MatchLink` interface (implemented by `GameSocket`), `HumanMatchController` with its state machine over a fake link (selection picks, layout moves, keep toggles, confirm and cancel, the rounds queue, game over), `seatVsBot` (create the room, seat the bot, choose the decks, start), the Play tab card with the deck choice. Tests: the controller over a fake link.
- [x] **2 Selection screen**: `CharacterCard`, `SelectionScreen`. Tests: 4 picks at most, Confirm enabled at 4, Confirm becomes Cancel, the bot's deck is read only, no overflow in landscape.
- [x] **3 Placement screen**: `PlacementScreen`. Tests: two taps move, an occupied cell swaps, the layout sent, the empty cell is dashed, the bot's side is masked.
- [x] **4 Board**: `MatchBoard` and `CellTile` (face states CELL-4, portrait CELL-2, empty cell). Tests: each face state, lock mark only where allowed, status chips, no overflow.
- [ ] **5 Keep and the loop**: tap to keep or release, Confirm and Cancel, the top bar, the hand-off to the Flame playback and back, the end of match; `HumanMatchScreen` wires the screens by phase. Tests: toggles sent on confirm, the second Keep starts from the previous locks, the result.
- [ ] **6 finish**: docs, delete this folder, the list of what a phone test must check.
