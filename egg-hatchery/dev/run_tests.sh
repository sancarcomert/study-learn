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
  for _, n in ipairs({ "Config", "Remotes", "BoothRegistry", "Products", "BoothStyler", "HatcheryService" }) do
    local m = Instance.new("ModuleScript")
    m.Name = n
    m.Parent = mods
  end
end
__scriptFns = {}
-- Eski durum: kurulum komutu bunlari temizlemeli
do
  local bp = Instance.new("Part")
  bp.Name = "Baseplate"
  bp.Size = Vector3.new(512, 20, 512)
  bp.CFrame = CFrame.new(0, -10, 0)
  bp.Parent = workspace
  local sl = Instance.new("SpawnLocation")
  sl.Name = "SpawnLocation"
  sl.Size = Vector3.new(6, 1, 6)
  sl.CFrame = CFrame.new(0, 0.5, 0)
  sl.Parent = workspace
  local booths = Instance.new("Folder")
  booths.Name = "Booths"
  booths.Parent = workspace
  local ob = Instance.new("Model")
  ob.Name = "OldBooth"
  ob.Parent = booths
  local atm = Instance.new("Atmosphere")
  atm.Name = "EH_Atmosphere"
  atm.Parent = game:GetService("Lighting")
  local oldBuilder = Instance.new("Script")
  oldBuilder.Name = "MapBuilder"
  oldBuilder.Parent = __SSS
  local oldFx = Instance.new("LocalScript")
  oldFx.Name = "MapFX"
  oldFx.Source = "print('eski')"
  oldFx.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
end
LUA
  for m in Config Remotes BoothRegistry Products BoothStyler HatcheryService; do
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
  echo "__EXPECTED_MAPFX = [=====["
  cat "$ROOT/StarterPlayer/StarterPlayerScripts/MapFX.client.lua"
  echo "]=====]"
  echo "do"
  cat "$ROOT/command_bar/InstallMap.lua"
  echo "end"
  cat "$HERE/test_installer.lua"
  cat "$HERE/test_layout.lua"
  cat "$HERE/test_integration.lua"
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
