#!/bin/zsh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/scripts/package.sh" >/dev/null
app="$HOME/Applications/Uso.app"
rm -rf "$app"
ditto "$root/dist/Uso.app" "$app"
killall Uso 2>/dev/null || true
open "$app"
echo "Opened: $app"
