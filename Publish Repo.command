#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="/Users/giminu0930/Desktop/Gimminu-profile"
BOOTSTRAP_SCRIPT="$ROOT_DIR/scripts/bootstrap_repo.sh"

resolve_target() {
  local arg_target="${1:-}"

  if [[ -n "$arg_target" ]]; then
    printf '%s' "$arg_target"
    return
  fi

  if command -v osascript >/dev/null 2>&1; then
    osascript <<'APPLESCRIPT'
POSIX path of (choose folder with prompt "Choose a project folder to publish to GitHub")
APPLESCRIPT
  fi
}

TARGET_PATH="$(resolve_target "${1:-}")"

if [[ -z "$TARGET_PATH" ]]; then
  echo "No project folder selected."
  echo
  read -r -p "Press Enter to close..."
  exit 1
fi

echo "Selected project: $TARGET_PATH"
echo

"$BOOTSTRAP_SCRIPT" --interactive --path "$TARGET_PATH" --create-github

echo
echo "Finished."
read -r -p "Press Enter to close..."
