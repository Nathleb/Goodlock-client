# Goodlock app

Mobile client (Flutter + Flame) for Goodlock, a tactical PvP dice game. The backend lives in
`../Goodlock-back`.

- Developer guide (setup, phone over Wi-Fi with hot reload, release builds):
  [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md)
- Phone over wireless debugging: `tool/phone.sh pair <ip:port> <code>` once, then
  `tool/phone.sh connect <ip:port>` and `tool/phone.sh run` (hot reload against the LAN backend)
- Conventions for Claude Code: [`CLAUDE.md`](CLAUDE.md)
