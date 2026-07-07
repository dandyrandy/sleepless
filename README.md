# Sleepless

A macOS menubar app that keeps your Mac awake **even with the lid closed** — no
external display needed. Built for the "server in a backpack" use case: lid
closed, tethered to your phone, still running.

macOS force-sleeps a MacBook on lid close unless an external display is
attached; user-space tricks like `caffeinate` cannot override that. Sleepless
flips the only switch that can — `pmset disablesleep` — which requires root,
via a tiny root-owned helper script with a narrowly-scoped sudoers rule.

## Menubar icon

- ☾ `moon.zzz` — off, normal sleep behavior
- ⚡ `bolt.fill` — active, the Mac will not sleep

## Build & install

```sh
./build.sh          # builds dist/Sleepless.app
open dist/Sleepless.app
```

Optionally move `dist/Sleepless.app` to `/Applications` (recommended if you
enable Launch at Login, so the registered path is stable).

### One-time helper setup

The first time you choose **Keep Awake**, the app offers to install the
helper and asks for your administrator password. Or install it manually:

```sh
sudo ./helper/install-helper.sh "$USER"
```

This installs:

| File | Purpose |
|---|---|
| `/usr/local/libexec/sleepless-helper` | root-owned script; runs `pmset -a disablesleep 1\|0`, nothing else |
| `/etc/sudoers.d/sleepless` | lets your user run exactly `sleepless-helper on` and `sleepless-helper off` without a password |

The helper is root-owned and not user-writable, and the sudoers rule matches
the exact command + argument, so it grants no general root access.

## Usage

Click the menubar icon:

- **Keep Awake** — on until you turn it off
- **Keep Awake For** — 30 min / 1 h / 2 h / 4 h, then auto-off
- **Turn Off — Allow Sleep** — restore normal sleep
- **Launch at Login** — starts the app at login (always starts in the *off* state)

The menu also shows battery %, power source, and thermal warnings while open.

## Safety behavior

- **Low battery auto-off** — on battery at ≤ 15%, keep-awake turns itself off
  (checked every 30 s) so the Mac can sleep instead of draining to dead.
- **Thermal auto-off** — if macOS reports *critical* thermal pressure,
  keep-awake turns off. The menu shows a warning already at *serious*.
- **Crash safety** — normal sleep is restored on quit and on
  SIGTERM/SIGINT/SIGHUP. If the app is killed uncleanly (sleep stays
  disabled), relaunching it detects that and shows the active ⚡ state so you
  can turn it off; or run `sudo pmset -a disablesleep 0` yourself.
- Auto-offs post a notification and are listed in the menu ("Last auto-off: …").
- The display still sleeps on its normal schedule; only *system* sleep is
  prevented.

## Backpack caveats

- A closed MacBook doing real work in a bag has almost no airflow. It will
  thermally throttle before the critical auto-off fires — give it some space,
  and don't bury it under a jacket.
- Keep-awake with the lid closed drains battery fast if the machine is busy.
- Wi-Fi/tethering stays connected because the system never sleeps.

## Uninstall

```sh
sudo ./helper/uninstall-helper.sh   # removes helper + sudoers rule, restores sleep
rm -rf dist/Sleepless.app           # or /Applications/Sleepless.app
```

## Development

Plain SwiftPM, no Xcode project:

```sh
swift build          # debug build
./build.sh           # release .app bundle in dist/
```

`swift run` works for quick iteration, but notifications and Launch at Login
require running from the `.app` bundle.
