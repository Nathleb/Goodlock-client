# Plan: match timeline

- [x] 1. Model: `GameStateView.preview`; schema synced; fixtures validated.
- [x] 1b. `RoundResolved.startOfResolve`: the faces actually resolved (the Resolve timeline starts from it, not from the last Keep board).
- [x] 2. `RoundTimeline`: board per notch, token status (TL-1, TL-3, TL-4).
- [x] 3. Step outcome: per-cell result and one-line caption (STEP-2..5).
- [ ] 4. `Playhead`: play, pause, fast forward, seek, reset (TL-6, FLOW-4..6).
- [ ] 5. Timeline widget (TL-1..3, TL-6).
- [ ] 6. Die view and portrait tap (DIE-1, DIE-2, CELL-5).
- [ ] 7. Board shows a step (STEP-1..4, CELL-3).
- [ ] 8. Match screen replaces the Keep screen and the Flame Resolve in `HumanMatchView` (LAYOUT-1, LAYOUT-2, FLOW-3..6).
- [ ] 9. Remove the Flame Resolve scene; move the bot-vs-bot screen to the match screen.
- [ ] 10. Docs: `docs/DEVELOPMENT.md`; delete this folder.
