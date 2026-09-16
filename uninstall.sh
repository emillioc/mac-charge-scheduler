#!/bin/sh
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this with sudo." >&2
    exit 1
fi

BIN_DEST="/usr/local/libexec/chargectl"
PLIST_DEST="/Library/LaunchDaemons/com.emchandra.chargescheduler.plist"

# Always leave the machine able to charge before removing the scheduler.
if [ -x "$BIN_DEST" ]; then
    "$BIN_DEST" enable || true
fi

launchctl bootout system "$PLIST_DEST" 2>/dev/null || true
rm -f "$PLIST_DEST" "$BIN_DEST"

echo "Uninstalled. Charging left enabled."
