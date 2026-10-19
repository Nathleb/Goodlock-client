# Developer guide

How to run Goodlock (backend + Flutter app) and iterate on a real phone in seconds.
Setup is WSL2 on Windows 11 with an Android phone; adapt paths to your machine.

## Overview

| Piece | Where | Runs on |
|---|---|---|
| Backend (NestJS + Socket.IO, Postgres) | `../Goodlock-back` | WSL, port 3000 |
| Database | Docker (`docker compose up -d db` in Goodlock-back) | Docker Desktop |
| App (Flutter + Flame) | this repo | phone (or emulator) |

The phone talks to the backend over the local network: `http://<PC-IP>:3000`.

## One-time setup

### Tools

- Flutter SDK (`~/development/flutter`, on `PATH`), Android SDK (`~/Android/Sdk`, with
  `platform-tools`, `platforms;android-36`, `build-tools;36.0.0`), JDK 21.
- Docker Desktop (Windows) for Postgres.
- Low-memory machines: cap Gradle in `~/.gradle/gradle.properties`
  (`org.gradle.jvmargs=-Xmx3G`, `kotlin.daemon.jvmargs=-Xmx1G`, `org.gradle.workers.max=4`);
  the project asks for 8 GB, which can crash WSL during release builds.

### Make the backend reachable from the phone (WSL mirrored networking)

1. `C:\Users\<you>\.wslconfig`:

   ```ini
   [wsl2]
   networkingMode=mirrored
   ```

2. In an **administrator** PowerShell, allow inbound TCP 3000 (Hyper-V firewall for WSL, then
   Windows firewall on the private profile):

   ```powershell
   New-NetFirewallHyperVRule -Name GoodlockBackend -DisplayName "Goodlock backend 3000" -Direction Inbound -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -Protocol TCP -LocalPorts 3000
   New-NetFirewallRule -DisplayName "Goodlock backend 3000" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow -Profile Private
   ```

3. `wsl --shutdown` (closes every WSL window, Docker Desktop restarts its engine), reopen WSL.
4. Your Wi-Fi network must use the **Private** profile in Windows settings.
5. Find the PC address: `ipconfig` → Wi-Fi → IPv4 (e.g. `192.168.1.12`). Reserve it in your
   router (DHCP reservation) so it never changes.

Check from the phone's browser: `http://<PC-IP>:3000/rooms` must answer (401 is fine: it means
the server is reachable and wants a login).

### Pair the phone for wireless debugging (once per phone)

1. Phone: Settings → About phone → tap *Build number* 7 times (developer options).
2. Developer options → **Wireless debugging** on (phone and PC on the same Wi-Fi).
3. Wireless debugging → *Pair device with pairing code*: note `IP:port` and the 6-digit code.
4. PC, while the pairing dialog is still open (its port and code die when it closes):

   ```bash
   tool/phone.sh pair <ip>:<pairing-port> <code>   # "Successfully paired"
   tool/phone.sh connect <ip>:<port>               # port from the main Wireless debugging screen
   ```

The connect port changes when wireless debugging restarts; re-run `tool/phone.sh connect` with
the new one (pairing stays valid).

`tool/phone.sh` wraps `adb` because of a mirrored-networking quirk: connecting to a *closed*
localhost port hangs instead of being refused, so a plain `adb devices`, `adb pair` or
`adb kill-server` hangs forever when no adb server runs yet. The script starts the server
directly (`adb nodaemon server`) when nothing listens on :5037. Without the script:
`adb nodaemon server &`, then the usual `adb` commands.

## Daily loop

```bash
# 1. Database (Docker Desktop running)
cd ../Goodlock-back && docker compose up -d db

# 2. Backend
npm run start:dev                 # watch mode, port 3000

# 3. App on the phone, with hot reload
cd ../Goodlock-app
tool/phone.sh connect <phone-ip>:<port>   # if not connected
tool/phone.sh run                         # flutter run on the phone, SERVER_URL=http://<PC-IP>:3000
```

`tool/phone.sh run` picks the phone (it shows up twice: `ip:port` and its mDNS name), uses the
PC's LAN IP for `SERVER_URL` (override with `SERVER_URL=… tool/phone.sh run`) and passes extra
arguments to `flutter run` (e.g. `--release`).

No APK to rebuild while you code. The first run builds and installs a debug build (a few
minutes); after that the terminal stays attached to the phone and pushes your Dart changes:

- `r` hot reload (about a second, keeps the current screen and its state),
- `R` hot restart (a few seconds, the app starts over): needed after changing `main()`, initial
  state or `static` fields,
- `q` quit (the app stays installed on the phone).

Quit and re-run `tool/phone.sh run` only after touching native code (`android/`), adding a
package with native code to `pubspec.yaml`, or changing a `--dart-define`.

This is a debug build: fine for layout and logic, a bit less smooth than release.

**From VS Code** (Flutter extension): pick the phone in the status bar, start with F5, and every
save hot-reloads. Pass the server URL with `"args": ["--dart-define=SERVER_URL=http://<PC-IP>:3000"]`
in `.vscode/launch.json`.

The server URL is also editable in the app (login screen → *Serveur*) and is remembered.

## Judging feel: release APK

Animations and smoothness are judged on a release build only:

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64 \
  --dart-define=SERVER_URL=http://<PC-IP>:3000
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
(cd android && ./gradlew --stop)  # free the Gradle daemon's memory
```

Build before starting Docker and the backend on machines short on RAM.

## Away from home: tunnel

When the phone isn't on the PC's network, expose the backend with a temporary tunnel:

```bash
~/.local/bin/cloudflared tunnel --url http://localhost:3000
```

Paste the printed `https://….trycloudflare.com` URL in the app's *Serveur* field. It changes at
every restart of the tunnel.

## Emulator (optional)

Useful for a quick layout check, not for feel.

- Android Studio → Device Manager → start a device, drag the APK onto its window.
- Server URL from the emulator: `http://10.0.2.2:3000`.
- Old Intel graphics drivers crash the emulator (`EXCEPTION_HEAP_CORRUPTION` in `igc64.dll`):
  set the device's *Graphics acceleration* to **Software** (slow) or update the driver.

## Checks before committing

```bash
flutter analyze
flutter test
dart run tool/bot_match.dart --server http://localhost:3000   # full match between two bots
```

`tool/bot_match.dart --record test/fixtures` re-records the resolve fixture used by tests and
the offline demo (copy it to `assets/demo/round_resolved.json`).

## Gotchas

- Every `adb` command hangs (WSL mirrored mode, no adb server yet): run `tool/phone.sh server`.

- `pkill -f "dist/src/main"` kills your own shell (the pattern matches its command line); find
  the backend with `ps -eo pid,args | awk '$2=="node" && $3=="dist/src/main.js"'`.
- `docker --env-file` keeps quotes around values; strip them in `.env` for Docker runs.
