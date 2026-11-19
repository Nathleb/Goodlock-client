# Effect parts: client plan

Follows the backend feature of the same name (`../Goodlock-back/docs/features/active/2026-11-16-effect-parts/design.md`):
a face effect is `{ targets, parts: [{ part, magnitude, stat?, state?, duration? }] }` and a resolved
effect is `{ parts, targets }`. No UI decision: the display stays as it is, one chip or glyph per part.
Merge the backend PR first.

- [x] 1. **Protocol models.** Sync the schema, convert the recorded fixtures to the new shape, then
  `FacePart`, `FaceEffect { targets, parts }` and `ResolvedEffect { parts, targets }` in
  `lib/net/models.dart`. Tests first: the hand-written payloads of `test/net/models_test.dart` in the
  new shape, validated against the schema; a two-part effect parses with its parts in order.
- [ ] 2. **Display.** `die_face_tile.dart` (one chip per part, the grid in the colour of the first
  part), `face_glyph.dart` (first part of the first effect), `resolve_game.dart` (caption lists the
  parts, a Damage part makes the lunge, rings in the colour of the first part). Tests first in the
  widget and game tests.
