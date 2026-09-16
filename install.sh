#!/bin/sh
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this with sudo." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DEST="/usr/local/libexec/chargectl"
PLIST_DEST="/Library/LaunchDaemons/com.emchandra.chargescheduler.plist"

echo "Building release binary..."
sudo -u "${SUDO_USER:-$USER}" swift build --package-path "$SCRIPT_DIR" -c release

mkdir -p "$(dirname "$BIN_DEST")"

install -o root -g wheel -m 0755 "$SCRIPT_DIR/.build/release/chargectl" "$BIN_DEST"
install -o root -g wheel -m 0644 "$SCRIPT_DIR/com.emchandra.chargescheduler.plist" "$PLIST_DEST"

launchctl bootout system "$PLIST_DEST" 2>/dev/null || true
launchctl bootstrap system "$PLIST_DEST"

echo "Installed. Binary: $BIN_DEST"
echo "Daemon:  $PLIST_DEST"
echo "Log:     /var/log/chargescheduler.log"
echo
echo "Check status any time with: sudo $BIN_DEST status"
