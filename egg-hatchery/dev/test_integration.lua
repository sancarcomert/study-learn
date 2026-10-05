-- dev/test_integration.lua : MapBuilder + HatcheryService + MapFX birlikte calisiyor mu?
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end

	print("== Booth yapisi ==")
	local booths = workspace.Booths:GetChildren()
	check(#booths == 24, "24 stand uretildi")
	for _, b in ipairs(booths) do
		assert(b.PrimaryPart and b.PrimaryPart.Name == "Base", b.Name .. " PrimaryPart=Base degil")
		assert(b:FindFirstChild("Egg"), b.Name .. " Egg yok")
	end
	check(true, "her standda Base(PrimaryPart) ve Egg var")
	check(#workspace:GetChildren() > 0 and workspace:FindFirstChild("Spawn1") ~= nil, "SpawnLocation'lar var")

	print("== HatcheryService entegrasyonu ==")
	local modules = __SSS.Modules
	local Config = require(modules.Config)
	local Registry = require(modules.BoothRegistry)
	local Remotes = require(modules.Remotes)
	local Hatchery = require(modules.HatcheryService)

	for _, b in ipairs(booths) do
		local claim, donate = Hatchery.BuildBooth(b)
		assert(claim.Parent == b.PrimaryPart and donate.Parent == b.PrimaryPart, "prompt'lar Base'e baglanmadi")
	end
	local b1 = workspace.Booths.Booth_1
	check(b1.Egg:FindFirstChild("HatcheryGui") ~= nil, "Egg uzerinde HatcheryGui olustu")
	check(b1.Egg.HatcheryGui.Title.Text:find("Unclaimed") ~= nil, "bos stand yazisi 'Unclaimed'")
	check(b1.PrimaryPart.ClaimPrompt.Enabled == true and b1.PrimaryPart.DonatePrompt.Enabled == false, "bos standda Claim acik, Donate kapali")

	local player = Instance.new("Player")
	player.Name = "Tester"
	player.Parent = game:GetService("Players")
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	for _, n in ipairs({ "TimePoints", "EggLevel" }) do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = ls
	end
	ls.EggLevel.Value = 1
	local data = Instance.new("Folder")
	data.Name = "EggData"
	data.Parent = player
	local xp = Instance.new("IntValue")
	xp.Name = "EggXP"
	xp.Parent = data
	player:SetAttribute("DataLoaded", true)

	Registry.Claim(b1, player)
	Hatchery.SetClaimed(b1, player)
	check(b1.Egg.HatcheryGui.Title.Text == "Tester's Hatchery - Level 1", "sahiplenince baslik: " .. b1.Egg.HatcheryGui.Title.Text)
	check(b1.PrimaryPart.ClaimPrompt.Enabled == false and b1.PrimaryPart.DonatePrompt.Enabled == true, "sahipli standda Claim kapali, Donate acik")

	Hatchery.AddXP(player, 250)
	check(ls.EggLevel.Value == 2 and xp.Value == 150, "250 XP: seviye 2, kalan 150 (gercek: " .. ls.EggLevel.Value .. "/" .. xp.Value .. ")")
	local colorBefore = b1.Egg.Color
	Hatchery.AddXP(player, 200000)
	check(ls.EggLevel.Value >= 20, "buyuk XP coklu evrim: seviye " .. ls.EggLevel.Value)
	check(Config.GetRarity(ls.EggLevel.Value).Name == "Mythic", "Mythic nadirlige ulasildi")
	check(b1.Egg.Color ~= colorBefore, "yumurta rengi nadirlige gore degisti")
	local fired = rawget(Remotes.EggFeedback, "_d").fired
	check(fired ~= nil and #fired >= 2, "EggFeedback duyurulari gonderildi (" .. tostring(fired and #fired) .. ")")
	check(rawget(b1.Egg:FindFirstChild("ParticleEmitter") or b1.Egg:FindFirstChildOfClass("ParticleEmitter"), "_d") ~= nil, "yumurtada ParticleEmitter var")

	Registry.Release(b1)
	Hatchery.SetUnclaimed(b1)
	check(b1.Egg.HatcheryGui.Title.Text:find("Unclaimed") ~= nil, "stand sifirlaninca tekrar 'Unclaimed'")
	player:Destroy()
end
