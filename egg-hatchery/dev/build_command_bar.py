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
-- CELESTIAL HATCHERY - tek komutla kurulum (Studio Command Bar)
-- 1) Studio'da View > Command Bar'i ac (altta yazi kutusu cikar)
-- 2) Bu dosyanin TAMAMINI kopyala, kutuya yapistir, Enter'a bas
-- 3) Birkac saniye bekle; Output'ta "[Kurulum] Bitti" yazinca hazir
-- Ayarlari (stand sayisi, ruh hali, isik) asagidaki ilk satirlardan degistirip tekrar calistirabilirsin.
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
	Workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 175, 310), Vector3.new(0, 18, 0))
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
