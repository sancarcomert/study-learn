-- dev/test_installer.lua : Command Bar kurulum komutu beklenen sonucu uretti mi?
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== Command Bar kurulumu ==")
	local container = game:GetService("StarterPlayer").StarterPlayerScripts
	local fxs = {}
	for _, c in ipairs(container:GetChildren()) do
		if c.Name == "MapFX" then
			table.insert(fxs, c)
		end
	end
	check(#fxs == 1, "StarterPlayerScripts'te tek bir MapFX var (eski olan degistirildi)")
	check(fxs[1].ClassName == "LocalScript", "MapFX bir LocalScript")
	check(fxs[1].Source == __EXPECTED_MAPFX, "MapFX kaynagi depodaki dosyayla BIREBIR ayni (" .. #fxs[1].Source .. " bayt)")
	check(__SSS:FindFirstChild("MapBuilder") == nil, "eski MapBuilder scripti silindi")
	check(workspace:FindFirstChild("Baseplate") == nil, "eski Baseplate silindi")
	check(workspace:FindFirstChild("SpawnLocation") == nil, "eski SpawnLocation silindi")
	check(workspace.Booths:FindFirstChild("OldBooth") == nil and #workspace.Booths:GetChildren() == 16, "eski stand modelleri silindi, 16 yeni stand var")
	local atm = 0
	for _, c in ipairs(game:GetService("Lighting"):GetChildren()) do
		if c:IsA("Atmosphere") then
			atm = atm + 1
		end
	end
	check(atm == 1, "Lighting'te tek Atmosphere var (eski EH_Atmosphere silindi)")
	check(workspace.Map.Floor.Floor.Locked == true and workspace.Spawn1.Locked == true, "parcalar kilitli")
	local cp = workspace.CurrentCamera.CFrame.Position
	check(cp.X == 0 and cp.Y == 175 and cp.Z == 310, "kamera adaya cevrildi")
	check(selectionSet ~= nil and selectionSet[1] == workspace.Map, "Map klasoru secildi (F ile odaklanilir)")
	local tagged = game:GetService("CollectionService"):GetTagged("FX_Spin")
	check(#tagged == 5, "kalici haritada FX_Spin etiketli 5 model var (3 jiroskop + 2 gokyuzu halkasi)")
end
