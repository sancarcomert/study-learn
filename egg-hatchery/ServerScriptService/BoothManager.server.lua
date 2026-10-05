local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TextService = game:GetService("TextService")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)
local Registry = require(Modules.BoothRegistry)
local Hatchery = require(Modules.HatcheryService)

local boothFolder = Workspace:WaitForChild(Config.BOOTH_FOLDER_NAME)

local lastOwnFeed = {} -- [booth] = son kendi besleme zamani
local lastFeed = {} -- [player] = { global = zaman, [booth] = zaman }
local lastStyle = {} -- [player] = son stil degistirme zamani

local function release(booth)
	local owner = Registry.GetOwner(booth)
	if owner then
		owner:SetAttribute("HasBooth", nil)
	end
	Registry.Release(booth)
	booth:SetAttribute("OwnerUserId", nil)
	lastOwnFeed[booth] = nil
	Hatchery.SetUnclaimed(booth)
end

local function claim(booth, player)
	if not player:GetAttribute("DataLoaded") then
		Remotes.Notify:FireClient(player, "Verilerin yukleniyor...")
		return
	end
	if Registry.GetOwner(booth) then
		return
	end
	if Registry.GetBooth(player) then
		Remotes.Notify:FireClient(player, "Zaten bir standin var!")
		return
	end

	Registry.Claim(booth, player)
	booth:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("HasBooth", true)
	Hatchery.SetClaimed(booth, player)
	Remotes.Notify:FireClient(player, "Stand senin! Yumurtani F ile besle, mesajini ayarla.")
end

local function nearBooth(player, booth)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and booth.PrimaryPart ~= nil
		and (root.Position - booth.PrimaryPart.Position).Magnitude <= Config.INTERACT_DISTANCE
end

-- Bedava XP: yumurtayi besle
local function feed(booth, player)
	local owner = Registry.GetOwner(booth)
	if not owner or not nearBooth(player, booth) then
		return
	end
	local now = time()
	if owner == player then
		local last = lastOwnFeed[booth]
		if last and now - last < Config.FEED_COOLDOWN_OWN then
			Remotes.Notify:FireClient(player, string.format("Yumurtan tok! %d sn sonra tekrar besle.", math.ceil(Config.FEED_COOLDOWN_OWN - (now - last))))
			return
		end
		lastOwnFeed[booth] = now
		Hatchery.AddXP(owner, Config.FEED_XP_OWN)
		Remotes.Notify:FireClient(player, string.format("Yumurtani besledin (+%d XP)", Config.FEED_XP_OWN))
		return
	end

	local rec = lastFeed[player] or {}
	lastFeed[player] = rec
	if rec.global and now - rec.global < Config.FEED_GLOBAL_COOLDOWN then
		return
	end
	if rec[booth] and now - rec[booth] < Config.FEED_COOLDOWN_OTHER then
		Remotes.Notify:FireClient(player, string.format("Bu yumurta tok! %d sn sonra tekrar besleyebilirsin.", math.ceil(Config.FEED_COOLDOWN_OTHER - (now - rec[booth]))))
		return
	end
	rec.global, rec[booth] = now, now
	Hatchery.AddXP(owner, Config.FEED_XP_OTHER)
	Remotes.Notify:FireClient(player, string.format("%s oyuncusunun yumurtasini besledin!", owner.Name))
	Remotes.Notify:FireClient(owner, string.format("%s yumurtani besledi (+%d XP)", player.Name, Config.FEED_XP_OTHER))
end

local function setupBooth(booth)
	if not booth:IsA("Model") then
		return
	end
	local claimPrompt, _, feedPrompt = Hatchery.BuildBooth(booth)
	claimPrompt.Triggered:Connect(function(player)
		claim(booth, player)
	end)
	feedPrompt.Triggered:Connect(function(player)
		feed(booth, player)
	end)
end

for _, booth in ipairs(boothFolder:GetChildren()) do
	setupBooth(booth)
end
boothFolder.ChildAdded:Connect(setupBooth)

-- Stand ozellestirme: sahibi mesaj + renk secer. Mesaj Roblox filtresinden gecer (zorunlu), sadece filtrelenmis hali saklanir.
Remotes.SetBoothStyle.OnServerEvent:Connect(function(player, data)
	if typeof(data) ~= "table" or typeof(data.Text) ~= "string" or typeof(data.Color) ~= "number" then
		return
	end
	if not Registry.GetBooth(player) then
		return
	end
	local now = time()
	if lastStyle[player] and now - lastStyle[player] < Config.STYLE_COOLDOWN then
		Remotes.Notify:FireClient(player, "Biraz yavas! Birkac saniye sonra tekrar dene.")
		return
	end
	lastStyle[player] = now

	local color = math.floor(data.Color)
	if color < 1 or color > #Config.STYLE_COLORS then
		return
	end
	local text = data.Text:gsub("[%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
	if utf8.len(text) == nil or utf8.len(text) > Config.STYLE_MAX_LENGTH then
		Remotes.Notify:FireClient(player, "Mesaj en fazla " .. Config.STYLE_MAX_LENGTH .. " karakter olabilir.")
		return
	end
	if text ~= "" then
		local ok, filtered = pcall(function()
			return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
		end)
		if not ok or typeof(filtered) ~= "string" then
			Remotes.Notify:FireClient(player, "Mesaj su an kontrol edilemedi, tekrar dene.")
			return
		end
		text = filtered
	end
	if not Registry.GetBooth(player) then
		return -- filtre beklerken stand birakildi
	end
	player:SetAttribute("BoothMessage", text)
	player:SetAttribute("BoothColor", color)
	Hatchery.Refresh(player)
	Remotes.Notify:FireClient(player, "Stand ayarlarin kaydedildi!")
end)

-- Sahibi cikinca stand sifirlanir
Players.PlayerRemoving:Connect(function(player)
	local booth = Registry.GetBooth(player)
	if booth then
		release(booth)
	end
	lastFeed[player] = nil
	lastStyle[player] = nil
end)

-- Periyodik kontrol: sahibi gitmis standlari bosaltir
task.spawn(function()
	while true do
		task.wait(Config.OWNER_CHECK_INTERVAL)
		for booth, owner in pairs(Registry.AllClaimed()) do
			if owner.Parent ~= Players or not booth.Parent then
				release(booth)
			end
		end
	end
end)
