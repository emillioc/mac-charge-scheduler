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
- `chargectl auto` checks the current local hour. Outside the blocked
  window it always enables charging. Inside the window, it applies a
  **battery-percentage safety valve** instead of blocking unconditionally:
  below 15% it overrides the block and charges from the grid, above 30% it
  resumes blocking (running on battery), and in between it leaves whatever
  state charging is already in. This keeps the battery cycling roughly
  15-30% during peak hours instead of ever risking it running out, without
  a separate state file — the SMC key's own current value is the hysteresis
  memory.
- A root `LaunchDaemon` (`com.emchandra.chargescheduler.plist`) runs
  `chargectl auto` at the two window boundaries (4pm/11pm), every 5 minutes
  (`StartInterval`, so the battery threshold gets checked often enough to
  react promptly), and on every daemon load (`RunAtLoad`). That last part
  matters: if a scheduled firing is missed (e.g. the Mac was asleep at
  4pm), the very next load/reboot re-asserts the correct state, so it can't
  get permanently stuck in the wrong mode.

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
git clone https://github.com/emillioc/mac-charge-scheduler.git
cd mac-charge-scheduler
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

## Pause / resume the schedule

`toggle-scheduler.sh` is a single on/off switch for the whole schedule,
without uninstalling anything:

```sh
sudo toggle-scheduler.sh
```

- If the daemon is currently loaded, it unloads it and force-enables
  charging (so a paused schedule always leaves you able to charge, not
  stuck mid-block):
  ```
  ==========================================
   SCHEDULER PAUSED - charging forced ON
   Run this script again to resume.
  ==========================================
  ```
- Run it again and it reloads the daemon, which immediately re-applies the
  correct state for the current time:
  ```
  ==========================================
   SCHEDULER RESUMED - 4pm-11pm blocking active
   Current: [timestamp] charging is disabled
  ==========================================
  ```

It's installed to `/usr/local/bin/toggle-scheduler.sh` by `install.sh`, so
it's runnable from anywhere once installed.

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
