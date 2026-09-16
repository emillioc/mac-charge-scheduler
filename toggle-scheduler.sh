#!/bin/sh
# Toggle the 4pm-9pm charge-blocking schedule on/off.
# If the daemon is loaded: unloads it and force-enables charging (paused).
# If the daemon is not loaded: reloads it, which immediately re-asserts the
# correct state for the current time (resumed).
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this with sudo." >&2
    exit 1
fi

BIN="/usr/local/libexec/chargectl"
PLIST="/Library/LaunchDaemons/com.emchandra.chargescheduler.plist"
LABEL="com.emchandra.chargescheduler"

if launchctl print "system/$LABEL" >/dev/null 2>&1; then
    launchctl bootout system "$PLIST"
    "$BIN" enable
    echo "=========================================="
    echo " SCHEDULER PAUSED - charging forced ON"
    echo " Run this script again to resume."
    echo "=========================================="
else
    launchctl bootstrap system "$PLIST"
    STATE="$("$BIN" status)"
    echo "=========================================="
    echo " SCHEDULER RESUMED - 4pm-9pm blocking active"
    echo " Current: $STATE"
    echo "=========================================="
fi
