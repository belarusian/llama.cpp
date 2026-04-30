#!/usr/bin/env bash
# Wrapper script for generators generate command
# Usage: ./scripts/generate.sh [OPTIONS]

set -e

# Ensure we're in the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT_ABS="$(cd "$PROJECT_ROOT" && pwd)"
cd "$PROJECT_ROOT_ABS"

# Activate virtual environment if present
if [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
fi

# Run the generators generate command with all passed arguments
python3 -m generators "$@"