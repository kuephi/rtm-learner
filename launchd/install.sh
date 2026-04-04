#!/bin/bash
# Install the launchd agent and start it.
set -euo pipefail

PLIST_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/com.rtm-learner.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.rtm-learner.plist"

cp "$PLIST_SRC" "$PLIST_DEST"
launchctl load "$PLIST_DEST"
echo "Installed. Job will run daily at 08:00."
echo "Logs → data/rtm-learner.log"
echo ""
echo "Run now:      bash launchd/run-now.sh"
echo "Uninstall:    bash launchd/uninstall.sh"
