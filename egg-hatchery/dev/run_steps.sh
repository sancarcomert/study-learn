#!/usr/bin/env bash
# Kullanim: dev/run_steps.sh <luau-yolu> [cikti.txt]
# 6 Command Bar adimini (command_bar/steps/*.lua) mock icinde IKI KEZ sirayla calistirir (tekrar calistirma testi) + test_steps.lua
set -euo pipefail
LUAU="${1:?luau yolu}"
OUT="${2:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
TMP="$(mktemp --suffix=.lua)"
{
  cat "$HERE/mock_roblox.lua"
  for round in 1 2; do
    for f in "$ROOT"/command_bar/steps/[1-6]_*.lua; do
      echo "do"; cat "$f"; echo "end"
    done
  done
  cat "$HERE/test_steps.lua"
  if [ -n "$OUT" ]; then cat "$HERE/dump_parts.lua"; fi
} > "$TMP"
if [ -n "$OUT" ]; then "$LUAU" "$TMP" > "$OUT"; else "$LUAU" "$TMP"; fi
rm -f "$TMP"
