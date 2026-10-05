#!/usr/bin/env bash
# Kullanim: dev/run_map.sh <luau-yolu> [cikti.txt]
# mock_roblox + MapBuilder + dump birlestirip gercek Luau ile calistirir.
set -euo pipefail
LUAU="${1:?luau ikilisinin yolu}"
OUT="${2:-/dev/stdout}"
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp --suffix=.lua)"
cat "$HERE/mock_roblox.lua" "$HERE/../ServerScriptService/MapBuilder.server.lua" "$HERE/dump_parts.lua" > "$TMP"
"$LUAU" "$TMP" > "$OUT"
rm -f "$TMP"
