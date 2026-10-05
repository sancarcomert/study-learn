local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TextService = game:GetService("TextService")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)
local Registry = require(Modules.BoothRegistry)
local Hatchery = require(Modules.HatcheryService)
local Products = require(Modules.Products)

local T = Config.TEXT
local boothFolder = Workspace:WaitForChild(Config.BOOTH_FOLDER_NAME)

local lastOwnFeed = {} -- [booth] = son kendi besleme zamani
local lastFeed = {} -- [player] = { global = zaman, [booth] = zaman }
local lastStyle = {} -- [player] = son stil degistirme zamani

local function notify(player, text)
	Remotes.Notify:FireClient(player, text)
end

local function nearBooth(player, booth)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and booth.PrimaryPart ~= nil
		and (root.Position - booth.PrimaryPart.Position).Magnitude <= Config.INTERACT_DISTANCE
end

---------------------------------------------------------------------
-- Panel verisi: istemcinin arayuzu icin tek bir tablo
---------------------------------------------------------------------
local function feedSeconds(booth, viewer, owner)
	local now = time()
	if viewer == owner then
		local last = lastOwnFeed[booth]
		return last and math.max(0, math.ceil(Config.FEED_COOLDOWN_OWN - (now - last))) or 0
	end
	local rec = lastFeed[viewer]
	if not rec then
		return 0
	end
	local wait = 0
	if rec[booth] then
		wait = math.max(wait, math.ceil(Config.FEED_COOLDOWN_OTHER - (now - rec[booth])))
	end
	if rec.global then
		wait = math.max(wait, math.ceil(Config.FEED_GLOBAL_COOLDOWN - (now - rec.global)))
	end
	return math.max(0, wait)
end

local function panelPayload(booth, viewer)
	local owner = Registry.GetOwner(booth)
	if not owner then
		return nil
	end
	local level = owner.leaderstats.Level.Value
	local xp = owner.EggData.EggXP.Value
	local rarity = Config.GetRarity(level)
	local isOwner = owner == viewer
	return {
		Booth = booth,
		OwnerName = owner.DisplayName,
		OwnerId = owner.UserId,
		IsOwner = isOwner,
		Level = level,
		XP = xp,
		Need = Config.XPRequired(level),
		Rarity = rarity.Name,
		RarityColor = rarity.Color,
		Message = owner:GetAttribute("BoothMessage") or "",
		Style = owner:GetAttribute("BoothStyle") or "classic",
		Color = owner:GetAttribute("BoothColor") or 1,
		FeedXP = isOwner and Config.FEED_XP_OWN or Config.FEED_XP_OTHER,
		FeedWait = feedSeconds(booth, viewer, owner),
		Products = isOwner and {} or Products.Catalog(),
		XPPerRobux = Config.XP_PER_ROBUX,
	}
end

local function openPanel(booth, player)
	Registry.SetViewing(player, booth)
	local payload = panelPayload(booth, player)
	if payload then
		Remotes.OpenPanel:FireClient(player, payload)
	end
end

---------------------------------------------------------------------
-- Sahiplenme / birakma
---------------------------------------------------------------------
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
		notify(player, T.Loading)
		return
	end
	if Registry.GetOwner(booth) then
		return
	end
	if Registry.GetBooth(player) then
		notify(player, T.AlreadyHave)
		return
	end
	Registry.Claim(booth, player)
	booth:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("HasBooth", true)
	Hatchery.SetClaimed(booth, player)
	notify(player, T.Claimed)
end

---------------------------------------------------------------------
-- Bedava XP: besleme
---------------------------------------------------------------------
local function feed(booth, player)
	local owner = Registry.GetOwner(booth)
	if not owner or not nearBooth(player, booth) then
		return
	end
	local now = time()
	if owner == player then
		local last = lastOwnFeed[booth]
		if last and now - last < Config.FEED_COOLDOWN_OWN then
			notify(player, string.format(T.Full, math.ceil(Config.FEED_COOLDOWN_OWN - (now - last))))
			return
		end
		lastOwnFeed[booth] = now
		Hatchery.AddXP(owner, Config.FEED_XP_OWN)
		notify(player, string.format(T.FedOwn, Config.FEED_XP_OWN))
		return
	end

	local rec = lastFeed[player] or {}
	lastFeed[player] = rec
	if rec.global and now - rec.global < Config.FEED_GLOBAL_COOLDOWN then
		return
	end
	if rec[booth] and now - rec[booth] < Config.FEED_COOLDOWN_OTHER then
		notify(player, string.format(T.Full, math.ceil(Config.FEED_COOLDOWN_OTHER - (now - rec[booth]))))
		return
	end
	rec.global, rec[booth] = now, now
	Hatchery.AddXP(owner, Config.FEED_XP_OTHER)
	if Registry.GetBooth(player) then
		Hatchery.AddXP(player, Config.FEED_XP_FEEDER) -- iyilik karsiliksiz kalmaz
	end
	notify(player, string.format(T.FedOther, owner.DisplayName))
	notify(owner, string.format(T.FedBy, player.DisplayName, Config.FEED_XP_OTHER))
end

---------------------------------------------------------------------
-- Stand ozellestirme: stil + renk + mesaj (mesaj Roblox filtresinden gecer)
---------------------------------------------------------------------
local function setStyle(player, data)
	if typeof(data.Style) ~= "string" or typeof(data.Color) ~= "number" or typeof(data.Text) ~= "string" then
		return
	end
	if not Registry.GetBooth(player) then
		return
	end
	local now = time()
	if lastStyle[player] and now - lastStyle[player] < Config.STYLE_COOLDOWN then
		notify(player, T.StyleTooFast)
		return
	end
	lastStyle[player] = now

	local style = Config.GetStyle(data.Style)
	if not style then
		return
	end
	local level = player.leaderstats.Level.Value
	if level < style.Level then
		notify(player, string.format(T.StyleLocked, style.Name, style.Level))
		return
	end
	local color = math.floor(data.Color)
	if color < 1 or color > #Config.STYLE_COLORS then
		return
	end
	local text = data.Text:gsub("[%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
	if utf8.len(text) == nil or utf8.len(text) > Config.STYLE_MAX_LENGTH then
		notify(player, string.format(T.StyleTooLong, Config.STYLE_MAX_LENGTH))
		return
	end
	if text ~= "" then
		local ok, filtered = pcall(function()
			return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
		end)
		if not ok or typeof(filtered) ~= "string" then
			notify(player, T.StyleFilterFail)
			return
		end
		text = filtered
	end
	if not Registry.GetBooth(player) then
		return -- filtre beklerken stand birakildi
	end
	player:SetAttribute("BoothMessage", text)
	player:SetAttribute("BoothColor", color)
	player:SetAttribute("BoothStyle", style.Id)
	Hatchery.Refresh(player)
	notify(player, T.StyleSaved)
end

---------------------------------------------------------------------
-- Baglantilar
---------------------------------------------------------------------
local function setupBooth(booth)
	if not booth:IsA("Model") then
		return
	end
	local prompt = Hatchery.BuildBooth(booth)
	prompt.Triggered:Connect(function(player)
		if Registry.GetOwner(booth) == nil then
			claim(booth, player)
		else
			openPanel(booth, player)
		end
	end)
end

for _, booth in ipairs(boothFolder:GetChildren()) do
	setupBooth(booth)
end
boothFolder.ChildAdded:Connect(setupBooth)

Remotes.PanelAction.OnServerEvent:Connect(function(player, data)
	if typeof(data) ~= "table" or typeof(data.Action) ~= "string" then
		return
	end
	if data.Action == "Close" then
		Registry.ClearViewing(player)
		return
	end
	local booth = Registry.GetViewing(player)
	if not booth or not booth.Parent or not nearBooth(player, booth) then
		Registry.ClearViewing(player)
		return
	end
	if data.Action == "Feed" then
		feed(booth, player)
	elseif data.Action == "Style" then
		if Registry.GetOwner(booth) ~= player then
			return -- sadece sahibi kendi standini ozellestirir
		end
		setStyle(player, data)
	else
		return
	end
	-- paneli guncel veriyle tazele
	if Registry.GetViewing(player) == booth then
		local payload = panelPayload(booth, player)
		if payload then
			Remotes.OpenPanel:FireClient(player, payload)
		else
			Registry.ClearViewing(player)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local booth = Registry.GetBooth(player)
	if booth then
		release(booth)
	end
	Registry.ClearViewing(player)
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
