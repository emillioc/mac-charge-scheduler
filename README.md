# chargectl

A tiny command-line tool + `launchd` daemon that blocks MacBook charging
during a fixed daily window (currently **4pm–11pm**), so you can avoid
charging during peak electricity hours.

**This is a personal-use tool, built and tested for one specific machine
(Apple Silicon MacBook Pro). It is not a polished, general-purpose app —
share/fork at your own risk, and read the disclaimer below before running
it on your own Mac.**

## ⚠️ Disclaimer

This works by writing directly to an undocumented Apple SMC key (`CHTE`,
falling back to `CH0C`) that controls whether the battery accepts charge —
the same private mechanism used by tools like [AlDente](https://apphousekitchen.com/)
and the now-archived [Battery Toolkit](https://github.com/mhaeuser/Battery-Toolkit).
Apple does not document or support this key, and:

- It has only been tested on the author's own machine.
- Behavior on other Mac models/chip generations is not guaranteed.
- There is no warranty of any kind. Use it on your own hardware at your own risk.

## How it works

- `chargectl` opens the `AppleSMC` IOKit service and reads/writes the
  charge-enable key directly (`Sources/chargectl/SMCComm.swift`,
  `SMCComm+Charging.swift`). Writing requires root.
- `chargectl auto` checks the current local hour: if it falls inside the
  blocked window, it disables charging; otherwise it enables it.
- A root `LaunchDaemon` (`com.emchandra.chargescheduler.plist`) runs
  `chargectl auto` at the two window boundaries **and** on every daemon
  load (`RunAtLoad`). That second part matters: if a scheduled firing is
  missed (e.g. the Mac was asleep at 4pm), the very next load/reboot
  re-asserts the correct state, so it can't get permanently stuck in the
  wrong mode.

The core SMC communication code is adapted from
[mhaeuser/Battery-Toolkit](https://github.com/mhaeuser/Battery-Toolkit)
(BSD-3-Clause), trimmed down to just the charge-enable/disable key — no
GUI, no XPC daemon, no calibration/Sailing Mode/MagSafe features. The
`SMCParamStruct` C struct is Apple's own long-public APSL-licensed
definition. See file headers for full copyright notices.

## Requirements

- Apple Silicon Mac running macOS
- Xcode Command Line Tools (for `swift build`)
- Admin (sudo) access

## Install

```sh
git clone <this-repo>
cd charge-scheduler
sudo ./install.sh
```

This builds the release binary, installs it to `/usr/local/libexec/chargectl`,
installs the `toggle-scheduler.sh` helper to `/usr/local/bin/`, and loads
the LaunchDaemon.

## Usage

```sh
sudo chargectl status     # read current charging state
sudo chargectl enable     # force charging on
sudo chargectl disable    # force charging off
sudo chargectl auto       # apply the schedule for the current hour (what the daemon runs)

sudo toggle-scheduler.sh  # pause the schedule (forces charging on) / resume it — run again to flip
```

Logs go to `/var/log/chargescheduler.log`.

## Changing the blocked window

The window is currently 4pm–11pm (`16..<23`), defined in two places that
must be kept in sync:

1. `Sources/chargectl/main.swift` — the `blockedWindow` range in `cmdAuto()`
2. `com.emchandra.chargescheduler.plist` — the two `StartCalendarInterval`
   entries (should match the window's start/end hours)

After editing either, re-run `sudo ./install.sh` to rebuild and reload.

## Uninstall

```sh
sudo ./uninstall.sh
```

Always force-enables charging first, so you're never left unable to charge.

## License

Portions of this project are adapted from `mhaeuser/Battery-Toolkit`
(BSD-3-Clause) and Apple's original `SMCParamStruct` (APSL 2.0); their
copyright notices are preserved in the relevant file headers.
