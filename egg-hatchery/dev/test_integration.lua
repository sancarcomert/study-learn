-- dev/test_integration.lua : HatcheryService + BoothStyler dogrudan (gercek stand modeli uzerinde)
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== HatcheryService entegrasyonu ==")
	local Config = require(__SSS.Modules.Config)
	local Registry = require(__SSS.Modules.BoothRegistry)
	local Hatchery = require(__SSS.Modules.HatcheryService)
	local Remotes = require(__SSS.Modules.Remotes)
	local T = Config.TEXT

	local b1 = workspace.Booths.Booth_1
	local prompt = Hatchery.BuildBooth(b1)
	check(prompt.Name == "BoothPrompt" and prompt.Parent == b1.PrimaryPart, "tek etkilesim butonu (BoothPrompt) PrimaryPart'a baglandi")
	check(prompt.KeyboardKeyCode == Enum.KeyCode.E and prompt.HoldDuration == 0 and prompt.ActionText == T.PromptClaim, "bos standda 'Standı Al', E tusu, anlik")
	check(b1.PrimaryPart:FindFirstChild("ClaimPrompt") == nil and b1.PrimaryPart:FindFirstChild("FeedPrompt") == nil, "eski cift/uclu buton yok")
	local card = b1.Egg.HatcheryGui.Card
	check(card.NameLabel.Text == T.Unclaimed and card.LevelLabel.Text == T.ClaimHint, "bos stand karti: '" .. card.NameLabel.Text .. "' / '" .. card.LevelLabel.Text .. "'")
	check(card.BarBack.Visible == false and card.MessageLabel.Visible == false, "bos standda cubuk ve mesaj gizli")
	check(b1.Egg.HatcheryGui.MaxDistance == 60, "kart sadece yakindan gorunur (60 stud)")

	local player = Instance.new("Player")
	player.Name = "Tester"
	player.UserId = 424242
	player.Parent = game:GetService("Players")
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	for _, n in ipairs({ "Raised", "Donated", "Level" }) do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = ls
	end
	ls.Level.Value = 1
	local data = Instance.new("Folder")
	data.Name = "EggData"
	data.Parent = player
	local xp = Instance.new("IntValue")
	xp.Name = "EggXP"
	xp.Parent = data
	player:SetAttribute("DataLoaded", true)

	Registry.Claim(b1, player)
	Hatchery.SetClaimed(b1, player)
	check(card.NameLabel.Text == "Tester" and card.LevelLabel.Text == "Seviye 1  •  Yaygın", "sahipli kart: " .. card.NameLabel.Text .. " / " .. card.LevelLabel.Text)
	check(prompt.ActionText == T.PromptView and prompt.ObjectText == "Tester", "buton 'Standa Bak', nesne metni sahibin adi")
	check(card.BarBack.Visible == true, "sahipli standda XP cubugu gorunur")

	-- XP -> seviye (40 * 1^1.5 = 40 XP ile Seviye 2)
	Hatchery.AddXP(player, 100)
	check(ls.Level.Value == 2 and xp.Value == 60, "100 XP: Seviye 2, kalan 60 (gercek " .. ls.Level.Value .. "/" .. xp.Value .. ")")
	local feedback = rawget(Remotes.EggFeedback, "_d").fired
	local sawUnlock
	for _, f in ipairs(feedback or {}) do
		if f[1] == player and f[2].Kind == "Unlock" then
			sawUnlock = f[2]
		end
	end
	check(sawUnlock ~= nil and sawUnlock.Styles[1] == "Halı", "Seviye 2'de 'Halı' stili acildi bildirimi sahibe gitti")
	check(Config.XPRequired(1) == 40 and Config.XPRequired(2) == 113 and Config.XPRequired(10) == 1264, "XP egrisi: 40 / 113 / 1264")

	-- stil uygulanir (acik olan), kilitli olan 'classic'e duser
	player:SetAttribute("BoothStyle", "rug")
	player:SetAttribute("BoothColor", 3)
	Hatchery.Refresh(player)
	local decor = b1:FindFirstChild("StyleDecor")
	check(decor ~= nil and decor:FindFirstChild("Rug") ~= nil, "Seviye 2'de 'rug' stili standda gorunur")
	check(decor.Rug.Color == Config.STYLE_COLORS[3].Color, "halinin rengi secilen renk")
	local decorBefore = decor
	Hatchery.Refresh(player)
	check(b1:FindFirstChild("StyleDecor") == decorBefore, "stil degismediyse yeniden kurulmaz (performans)")
	player:SetAttribute("BoothStyle", "gold") -- Seviye 10 gerekir
	Hatchery.Refresh(player)
	check(b1:FindFirstChild("StyleDecor") == nil, "kilitli stil secili olsa bile uygulanmaz (classic'e duser)")
	player:SetAttribute("BoothStyle", "rug")

	-- mesaj
	player:SetAttribute("BoothMessage", "Pet icin")
	Hatchery.Refresh(player)
	check(card.MessageLabel.Visible == true and card.MessageLabel.Text == "Pet icin", "mesaj kartta gorunur")
	check(card.MessageLabel.TextColor3 == Config.STYLE_COLORS[3].Color, "mesaj secilen renkte")
	check(b1.Egg.HatcheryGui.Size.YO > 76, "mesaj varken kart uzar")

	-- cok yuksek XP: tum nadirlikler
	local colorBefore = b1.Egg.Color
	Hatchery.AddXP(player, 5000000)
	check(ls.Level.Value == Config.MAX_LEVEL, "cok buyuk XP seviyeyi MAX_LEVEL'de tutar (" .. ls.Level.Value .. ")")
	check(Config.GetRarity(ls.Level.Value).Name == "Mitik" and b1.Egg.Color ~= colorBefore, "Mitik nadirlige ulasildi, yumurta rengi degisti")
	check(xp.Value < Config.XPRequired(Config.MAX_LEVEL), "MAX seviyede XP tasmaz")
	__advance(1)
	local base = b1.Egg:GetAttribute("BaseSize")
	check(math.abs(b1.Egg.Size.Y - base.Y * Config.EggScale(ls.Level.Value)) < 0.05, string.format("yumurta seviyeyle buyudu: x%.2f", b1.Egg.Size.Y / base.Y))
	check(b1.Egg.Aura.Enabled == true and b1.Egg.Aura.Rate == 18, "Mitik yumurtada surekli kivilcim")
	local unlockCount = 0
	for _, f in ipairs(rawget(Remotes.EggFeedback, "_d").fired or {}) do
		if f[1] == player and f[2].Kind == "Unlock" then
			unlockCount = unlockCount + 1
		end
	end
	check(unlockCount == 2, "Seviye 2 ve sonrasi iki ayri Unlock bildirimi (" .. unlockCount .. ")")

	-- stil kilitleri
	check(Config.IsStyleUnlocked("rug", 2) and not Config.IsStyleUnlocked("lantern", 4) and Config.IsStyleUnlocked("lantern", 5), "stil kilitleri seviyeye gore")
	check(Config.NextUnlock(5).Id == "garden" and Config.NextUnlock(20) == nil, "sonraki acilim: Sv.5'ten sonra 'Çiçekli', Sv.20'den sonra yok")
	check(#Config.NewUnlocks(1, 10) == 5 and #Config.NewUnlocks(10, 10) == 0, "NewUnlocks aralik hesabi")

	-- birakinca sifirlanir
	Registry.Release(b1)
	Hatchery.SetUnclaimed(b1)
	check(card.NameLabel.Text == T.Unclaimed and b1:FindFirstChild("StyleDecor") == nil and prompt.ActionText == T.PromptClaim, "stand birakilinca kart, stil ve buton sifirlandi")
	check(math.abs(b1.Egg.Color.R - Config.RARITIES[1].Color.R) < 1e-6, "yumurta rengi varsayilana dondu")
end
