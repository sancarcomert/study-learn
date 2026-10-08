#!/usr/bin/env bash
# Kullanim: dev/run_tests.sh <luau-yolu>
# mock + moduller + Command Bar kurulum komutu (command_bar/InstallMap.lua) + sunucu scriptleri + MapFX
# birlestirilip gercek Luau'da calistirilir. Once: python3 dev/build_command_bar.py
set -euo pipefail
LUAU="${1:?luau ikilisinin yolu}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
TMP="$(mktemp --suffix=.lua)"
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
__scriptFns = {}
LUA
  for m in Config Remotes BoothRegistry Products BoothStyler EggModel HatcheryService; do
    echo "__moduleFns[\"$m\"] = function(script)"
    cat "$ROOT/ServerScriptService/Modules/$m.lua"
    echo
    echo "end"
  done
  for s in EconomyManager BoothManager MarketplaceHook LeaderboardService; do
    echo "__scriptFns[\"$s\"] = function(script)"
    cat "$ROOT/ServerScriptService/$s.server.lua"
    echo
    echo "end"
  done
  cat "$HERE/test_world.lua"
  cat "$HERE/test_integration.lua"
  cat "$HERE/test_egg.lua"
  cat "$HERE/test_styler.lua"
  echo "do"
  cat "$ROOT/StarterPlayer/StarterPlayerScripts/MapFX.client.lua"
  echo "end"
  cat "$HERE/test_client.lua"
  cat "$HERE/test_scripts.lua"
  echo "do"
  cat "$HERE/test_eggclient_pre.lua"
  cat "$ROOT/StarterGui/EggClient.client.lua"
  cat "$HERE/test_eggclient.lua"
  echo "end"
} > "$TMP"
"$LUAU" "$TMP"
rm -f "$TMP"
