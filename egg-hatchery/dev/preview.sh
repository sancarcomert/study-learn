#!/usr/bin/env bash
# Kullanim: dev/preview.sh <luau-yolu> <cikti-klasoru>
# Test dunyasini + yumurta sahnesini kurar, parcalari dokup yazilim cizicisiyle PNG uretir (gercek Roblox gorunumu degildir).
set -euo pipefail
LUAU="${1:?luau ikilisinin yolu}"
OUT="${2:?cikti klasoru}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
TMP="$(mktemp --suffix=.lua)"
mkdir -p "$OUT"
{
  cat "$HERE/mock_roblox.lua"
  cat <<'LUA'
__SSS = game:GetService("ServerScriptService")
do
  local mods = Instance.new("Folder")
  mods.Name = "Modules"
  mods.Parent = __SSS
  for _, n in ipairs({ "Config", "Remotes", "BoothRegistry", "Products", "BoothStyler", "EggModel", "HatcheryService" }) do
    local m = Instance.new("ModuleScript")
    m.Name = n
    m.Parent = mods
  end
end
LUA
  for m in Config Remotes BoothRegistry Products BoothStyler EggModel HatcheryService; do
    echo "__moduleFns[\"$m\"] = function(script)"
    cat "$ROOT/ServerScriptService/Modules/$m.lua"
    echo
    echo "end"
  done
  cat "$HERE/test_world.lua"
  cat "$HERE/preview_egg.lua"
  [ -f "$HERE/preview_extra.lua" ] && cat "$HERE/preview_extra.lua"
  cat "$HERE/dump_parts.lua"
} > "$TMP"
"$LUAU" "$TMP" > "$OUT/parts.txt"
rm -f "$TMP"
grep -c "^P|" "$OUT/parts.txt"
