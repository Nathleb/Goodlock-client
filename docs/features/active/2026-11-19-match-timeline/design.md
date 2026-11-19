# Match timeline, round preview and die view

UI specs (read-only, owned by the user): `../Goodlock-specs/ui/components/{timeline,die-view,cell}.md` and
`../Goodlock-specs/ui/screens/match.md`. Protocol: backend branch `feat/keep-preview` adds
`GameStateView.preview` (`ResolveStep[]`, KEEP states only), the log the round would give with the current faces.

## Decisions

- The preview comes from the server; the client computes no outcome.
- Keep and Resolve share one Flutter match screen (board, timeline, status bar). The Flame Resolve scene goes away.
- A timeline is built from a start board and a log (`RoundTimeline`): one notch for the state before any action,
  one per action, the last one for the end of the round (TL-4). The playhead (`Playhead`) is a notch index plus
  playback; the board shows the state of the notch (STEP-1).
- Resolve plays the server's log through the same timeline, autoplaying (FLOW-4), stopping on the last notch (FLOW-5)
  or on the effect that ends the match (FLOW-6).
- Out of scope: Upkeep and rolling-dice animations (FLOW-1, FLOW-2), slide animation of cells (CELL-6), drag and drop.
