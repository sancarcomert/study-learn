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
	if data.Action == "Style" then
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
