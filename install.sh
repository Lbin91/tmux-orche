#!/usr/bin/env bash
set -euo pipefail

DEST="${1:-$HOME/.agents/skills}"
SRC="$(cd "$(dirname "$0")" && pwd)"

installed=0
for dir in "$SRC"/*/; do
  [ -f "$dir/SKILL.md" ] || continue
  name="$(basename "$dir")"
  mkdir -p "$DEST/$name"
  cp -R "$dir/." "$DEST/$name/"
  echo "installed $name -> $DEST/$name"
  installed=$((installed + 1))
done

[ "$installed" -gt 0 ] || { echo "no skills found in $SRC" >&2; exit 1; }
echo "done: $installed skill(s). restart your agent session to load them."
