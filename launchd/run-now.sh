#!/bin/bash
# Trigger the job immediately without waiting for the scheduled time.
set -euo pipefail

launchctl start com.rtm-learner
echo "Triggered. Follow output: tail -f data/rtm-learner.log"
