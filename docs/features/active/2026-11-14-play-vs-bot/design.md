# Play a match against a bot — design

Purpose: let one person play a full match alone on the real server, against a bot on the other seat, with human input for Selection, Placement and Keep. Rules are in `../Goodlock-specs/GAME-DESIGN.md`; how they are shown in `PLAYER-EXPERIENCE.md`. No backend change: the socket already carries every event.

## Out of scope (for now)

The timeline and the Keep preview (TL-*, UX-1), the die view (DIE-1), the rolling-dice and Upkeep animations (FLOW-1, FLOW-2), a lobby or room browser, drag and drop. The bot plays at random.

## Entry

A card "Jouer contre un bot" in the Play tab. A tap picks the deck (a short list when the player has several, none when they have one), then creates a room, seats a bot as guest, chooses both decks and starts the match. The bot is the existing `Bot` (random picks, random placement, random keeps).

## Screens (landscape, 44 px targets, height is scarce)

All three share a top bar: phase, round and rerolls left, who holds the initiative, my clock (live) and the opponent's (static: CLOCK-4), and the Confirm button. After Confirm the same button reads Cancel (GAME-8). The player never sees whether the bot confirmed (GAME-9).

- **Selection (SEL-2, CHAR-1):** my deck (6 cards, tap to keep, 4 at most) on the left, the bot's deck (6 cards, read only) on the right. A card shows name, max HP, base speed and the six faces in miniature. Confirm is enabled at exactly 4 picks.
- **Placement (PLACE-1, PLACE-2):** my side only, cells 0 to 4 from top to bottom, my four characters on 0 to 3 and cell 4 dashed. Two taps move a character: first the character, then a cell; on an occupied cell the two swap. Each move sends the whole layout. The bot's side reads "masked until the first round".
- **Match (Keep and Resolve):** two facing columns, me on the left, cells 0 to 4 from top to bottom, empty cells dashed (LAYOUT-3, LAYOUT-4). A cell shows the current face on the lane side and the portrait (name, speed, HP bar and text, status chips with the shield) on the screen edge (CELL-1, CELL-2). Face states (CELL-4): to reroll, kept (lock mark), the opponent's (a lock mark only for dice kept at the last Roll), blank. In a Keep, tapping one of my faces keeps or releases it (CELL-5). In Resolve the Flame scene plays the round (FLOW-4), then the board comes back for the next Keep.
- **End of match:** the existing result widget; Leave goes back to the Play tab.

## Structure

- `HumanMatchController` (plain Dart, `ChangeNotifier`): owns the state machine over a `MatchLink` (the socket's streams and commands, an interface so tests use a fake). It exposes the last state, the room, my seat, the picks, the layout and the keeps being edited, a queue of rounds to play, the result. Screens only render it and call it.
- The screens are plain widgets over the controller; the board is a Flutter widget (tappable faces), the resolution stays Flame (`ResolveGame`).
- The client never computes an outcome: faces, HP and statuses come from the server.
