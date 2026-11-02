# Protocol schema (client) — plan

**Status:** in progress (started 2026-10-26). Backend spec: `../Goodlock-back/docs/features/active/2026-10-26-protocol-schema/design.md`.

The client keeps a synced copy of the backend's `protocol/protocol.schema.json` and validates its fixtures and hand-written payloads against it. No UI change, so no client `design.md`.

- [x] 7. Sync and first check: `json_schema` dev dependency, `tool/sync_protocol.sh`, `test/protocol/protocol.schema.json`. Test first: `test/protocol/schema_test.dart` validates every payload of `test/fixtures/round_resolved.json` against `RoundResolvedDTO`.
- [ ] 8. Hand-written payloads: `test/net/models_test.dart` validates the maps it builds (`character()`, `face()`) against `CharacterDTO` and `DieFaceDTO`.
- [ ] 9. Docs: `CLAUDE.md` points to the schema and to `tool/sync_protocol.sh`.
