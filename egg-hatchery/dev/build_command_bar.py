#!/usr/bin/env python3
"""dev/build_command_bar.py
MapBuilder + MapFX kaynaklarindan Studio Command Bar'a yapistirilacak TEK dosyayi uretir:
command_bar/InstallMap.lua

Komut: haritayi KALICI kurar (Play'e basmadan viewport'ta gorunur), MapFX LocalScript'ini olusturur,
eski MapBuilder scriptini siler, kamerayi adaya cevirir.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
builder = (ROOT / "ServerScriptService/MapBuilder.server.lua").read_text()
mapfx = (ROOT / "StarterPlayer/StarterPlayerScripts/MapFX.client.lua").read_text()
assert mapfx.endswith("\n")

# Tam satir yorumlari at (kisaltir); satir sonu yorumlari ve ayar aciklamalari kalir.
lines = [ln for ln in builder.splitlines() if not ln.lstrip().startswith("--")]
body = "\n".join(lines)
body = re.sub(r"\n{3,}", "\n\n", body).strip() + "\n"

# Uzun parantez seviyesi: mapfx icinde gecmeyen en kucuk seviye
level = 1
while ("]" + "=" * level + "]") in mapfx:
    level += 1
eq = "=" * level

header = """-- ============================================================
-- DOGAL PARK - tek komutla harita kurulumu (Studio Command Bar)
-- 1) Studio'da View > Command Bar'i ac (altta yazi kutusu cikar)
-- 2) Bu dosyanin TAMAMINI kopyala, kutuya yapistir, Enter'a bas
-- 3) Birkac saniye bekle; Output'ta "[Kurulum] Bitti" yazinca hazir
-- Ayarlari (stand sayisi, isik kalitesi, kilit) asagidaki ilk satirlardan degistirip tekrar calistirabilirsin.
-- ============================================================
"""

footer = f"""
local MAPFX_SOURCE = [{eq}[
{mapfx}]{eq}]

do
	local ok, err = pcall(function()
		local container = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts") or game:GetService("StarterGui")
		local old = container:FindFirstChild("MapFX")
		if old then
			old:Destroy()
		end
		local fx = Instance.new("LocalScript")
		fx.Name = "MapFX"
		fx.Source = MAPFX_SOURCE
		fx.Parent = container
	end)
	if ok then
		print("[Kurulum] MapFX kuruldu (StarterPlayerScripts).")
	else
		warn("[Kurulum] MapFX otomatik kurulamadi (" .. tostring(err) .. "). Asagidaki kodu elle bir LocalScript'e yapistir:")
		print(MAPFX_SOURCE)
	end

	local oldBuilder = game:GetService("ServerScriptService"):FindFirstChild("MapBuilder")
	if oldBuilder then
		oldBuilder:Destroy()
		print("[Kurulum] Eski MapBuilder scripti silindi (harita artik kalici).")
	end
end

pcall(function()
	Workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 210, 360), Vector3.new(0, 0, 10))
end)
pcall(function()
	game:GetService("Selection"):Set({{ map }})
end)
print("[Kurulum] Bitti. Play'e (F5) basip standlara gidebilirsin.")
"""

out = header + body + footer
dest = ROOT / "command_bar" / "InstallMap.lua"
dest.write_text(out)
non_ascii = sorted({c for c in out if ord(c) > 127})
print(f"yazildi: {dest}  ({len(out.splitlines())} satir, {len(out)} bayt, uzun-parantez seviyesi {level})")
if non_ascii:
    print("UYARI: ASCII disi karakterler:", non_ascii)


# ---------------------------------------------------------------------------
# Ikinci komut: oyun scriptlerini (Studio'da zaten kurulu olanlari) guncelle -> command_bar/UpdateScripts.lua
# ---------------------------------------------------------------------------
TARGETS = [
    # (Studio konumu: ebeveyn yolu, ad, sinif, depo dosyasi)
    ("ServerScriptService.Modules", "Config", "ModuleScript", "ServerScriptService/Modules/Config.lua"),
    ("ServerScriptService.Modules", "HatcheryService", "ModuleScript", "ServerScriptService/Modules/HatcheryService.lua"),
    ("ServerScriptService", "EconomyManager", "Script", "ServerScriptService/EconomyManager.server.lua"),
    ("ServerScriptService", "MarketplaceHook", "Script", "ServerScriptService/MarketplaceHook.server.lua"),
]

up_header = """-- ============================================================
-- OYUN SCRIPTLERINI GUNCELLE - tek komut (Studio Command Bar)
-- Config, HatcheryService, EconomyManager, MarketplaceHook scriptlerinin icerigini yeniler.
-- (Config.PRODUCTS icindeki Developer Product ID'lerini daha once girdiysen, bu komuttan SONRA tekrar gir.)
-- ============================================================
local function ensure(parentPath, name, className)
	local parent
	for part in string.gmatch(parentPath, "[^%.]+") do
		if parent == nil then
			parent = game:GetService(part) -- ilk parca bir servis (ServerScriptService)
		else
			local nxt = parent:FindFirstChild(part)
			if not nxt then
				nxt = Instance.new("Folder")
				nxt.Name = part
				nxt.Parent = parent
			end
			parent = nxt
		end
	end
	local inst = parent:FindFirstChild(name)
	if inst and inst.ClassName ~= className then
		inst:Destroy()
		inst = nil
	end
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	return inst
end

local failed = {}
local function install(parentPath, name, className, source)
	local ok, err = pcall(function()
		ensure(parentPath, name, className).Source = source
	end)
	if ok then
		print("[Guncelleme] " .. parentPath .. "." .. name .. " guncellendi (" .. #source .. " bayt)")
	else
		table.insert(failed, name)
		warn("[Guncelleme] " .. name .. " guncellenemedi: " .. tostring(err))
	end
end

"""
chunks = []
for parent, name, cls, rel in TARGETS:
    src = (ROOT / rel).read_text()
    assert src.endswith("\n")
    lv = 1
    while ("]" + "=" * lv + "]") in src:
        lv += 1
    e = "=" * lv
    chunks.append(f'install("{parent}", "{name}", "{cls}", [{e}[\n{src}]{e}])\n')
up_footer = """
if #failed > 0 then
	warn("[Guncelleme] Su scriptler elle yapistirilmali: " .. table.concat(failed, ", "))
else
	print("[Guncelleme] Bitti. Hepsi guncellendi.")
end
"""
up = up_header + "\n".join(chunks) + up_footer
udest = ROOT / "command_bar" / "UpdateScripts.lua"
udest.write_text(up)
print(f"yazildi: {udest}  ({len(up.splitlines())} satir, {len(up)} bayt)")
if sorted({c for c in up if ord(c) > 127}):
    print("UYARI: ASCII disi karakter (UpdateScripts):", sorted({c for c in up if ord(c) > 127}))
