#!/bin/bash
# Wrapper called by launchd — sets up the environment and runs the pipeline.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="/Users/kuephi/.pyenv/versions/3.11.12/bin/python3"

cd "$SCRIPT_DIR"
"$PYTHON" main.py
