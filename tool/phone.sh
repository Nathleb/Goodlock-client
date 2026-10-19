#!/usr/bin/env bash
# Phone dev loop over wireless debugging (see docs/DEVELOPMENT.md).
#
#   tool/phone.sh server                 start the adb server if it isn't running
#   tool/phone.sh pair <ip:port> <code>  pair once per phone (port + code from "Pair with code")
#   tool/phone.sh connect <ip:port>      connect (port from the main Wireless debugging screen)
#   tool/phone.sh run [flutter args]     flutter run on the phone (SERVER_URL defaults to this PC:3000)
#
# Why "server": with WSL mirrored networking, connecting to a closed localhost port hangs
# instead of being refused, so plain adb commands hang forever while probing for a server
# on :5037. We check the port with `ss` and start the server directly instead.
set -euo pipefail

ADB="$(command -v adb || echo "${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb")"
ADB_PORT=5037
LOG="${TMPDIR:-/tmp}/goodlock-adb-server.log"

die() { echo "phone.sh: $*" >&2; exit 1; }

server_listening() { ss -ltn "sport = :$ADB_PORT" | grep -q LISTEN; }

ensure_server() {
  server_listening && return
  [ -x "$ADB" ] || die "adb not found ($ADB)"
  echo "Starting adb server (log: $LOG)"
  setsid nohup "$ADB" nodaemon server >"$LOG" 2>&1 < /dev/null &
  for _ in $(seq 20); do
    server_listening && return
    sleep 0.25
  done
  die "adb server did not start, see $LOG"
}

# The PC's address on the local network (mirrored mode: WSL shares the Windows IP).
pc_ip() { ip -4 route get 1.1.1.1 | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}'; }

cmd="${1:-}"
shift || true
case "$cmd" in
  server)
    ensure_server
    "$ADB" devices
    ;;
  pair)
    [ $# -eq 2 ] || die "usage: tool/phone.sh pair <ip:port> <code>"
    ensure_server
    timeout 30 "$ADB" pair "$1" "$2" || die "pairing failed: keep the phone's pairing dialog open and use its current port and code"
    ;;
  connect)
    [ $# -eq 1 ] || die "usage: tool/phone.sh connect <ip:port>"
    ensure_server
    timeout 15 "$ADB" connect "$1"
    "$ADB" devices
    ;;
  run)
    ensure_server
    # The phone shows up twice (ip:port and its mDNS name), so pick one unless -d is given.
    serial="$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
    [ -n "$serial" ] || die "no phone connected: tool/phone.sh connect <ip:port>"
    device=(-d "$serial")
    for arg in "$@"; do [[ "$arg" == -d || "$arg" == --device-id* ]] && device=(); done
    url="${SERVER_URL:-http://$(pc_ip):3000}"
    echo "SERVER_URL=$url  device=$serial"
    cd "$(dirname "$0")/.."
    exec flutter run "${device[@]}" --dart-define=SERVER_URL="$url" "$@"
    ;;
  *)
    sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
