#!/usr/bin/env bash
# Kullanim: dev/run_tests.sh <luau-yolu>
# mock + moduller + MapBuilder + sunucu scriptleri + MapFX birlestirilip gercek Luau'da calistirilir.
set -euo pipefail
LUAU="${1:?luau ikilisinin yolu}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
TMP="$(mktemp --suffix=.lua)"
{
  cat "$HERE/mock_roblox.lua"
  cat <<'LUA'
__SSS = Instance.new("Folder")
__SSS.Name = "ServerScriptService"
do
  local mods = Instance.new("Folder")
  mods.Name = "Modules"
  mods.Parent = __SSS
  for _, n in ipairs({ "Config", "Remotes", "BoothRegistry", "HatcheryService" }) do
    local m = Instance.new("ModuleScript")
    m.Name = n
    m.Parent = mods
  end
end
__scriptFns = {}
LUA
  for m in Config Remotes BoothRegistry HatcheryService; do
    echo "__moduleFns[\"$m\"] = function(script)"
    cat "$ROOT/ServerScriptService/Modules/$m.lua"
    echo
    echo "end"
  done
  for s in EconomyManager BoothManager MarketplaceHook; do
    echo "__scriptFns[\"$s\"] = function(script)"
    cat "$ROOT/ServerScriptService/$s.server.lua"
    echo
    echo "end"
  done
  cat "$ROOT/ServerScriptService/MapBuilder.server.lua"
  cat "$HERE/test_integration.lua"
  echo "do"
  cat "$ROOT/StarterPlayer/StarterPlayerScripts/MapFX.client.lua"
  echo "end"
  cat "$HERE/test_client.lua"
  cat "$HERE/test_scripts.lua"
} > "$TMP"
"$LUAU" "$TMP"
rm -f "$TMP"
