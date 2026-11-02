#!/usr/bin/env bash
# Copy the backend's protocol schema into the client tests (see CLAUDE.md, "Reference docs").
#
#   tool/sync_protocol.sh
#
# Run it after a protocol change in ../Goodlock-back, then re-record the fixtures
# (dart run tool/bot_match.dart --server http://localhost:3000 --record test/fixtures)
# and update lib/net/models.dart until `flutter test` passes.
set -euo pipefail

cd "$(dirname "$0")/.."
SRC="${BACKEND_DIR:-../Goodlock-back}/protocol/protocol.schema.json"
DEST="test/protocol/protocol.schema.json"

[ -f "$SRC" ] || { echo "sync_protocol.sh: $SRC not found (set BACKEND_DIR to the backend checkout)" >&2; exit 1; }
mkdir -p "$(dirname "$DEST")"
cp "$SRC" "$DEST"
echo "synced $DEST from $SRC"
