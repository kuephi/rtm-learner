#!/bin/bash
# Unload and remove the launchd agent.
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.rtm-learner.plist"

if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST"
    rm "$PLIST"
    echo "Uninstalled."
else
    echo "Not installed — nothing to do."
fi
