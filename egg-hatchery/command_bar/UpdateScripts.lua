-- ============================================================
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

install("ServerScriptService.Modules", "Config", "ModuleScript", [=[
local Config = {}

Config.DATASTORE_NAME = "EggHatchery_v1"
Config.AUTOSAVE_INTERVAL = 120
Config.XP_PER_ROBUX = 20
Config.MAX_LEVEL = 100
Config.INTERACT_DISTANCE = 25
Config.OWNER_CHECK_INTERVAL = 5
Config.BOOTH_FOLDER_NAME = "Booths"

-- Developer Product ID'lerini buraya yaz (Roblox Creator Hub > Monetization > Developer Products)
Config.PRODUCTS = {
	{ Id = 0, Name = "Snack" },
	{ Id = 0, Name = "Feast" },
	{ Id = 0, Name = "Banquet" },
	{ Id = 0, Name = "Jackpot" },
}

Config.RARITIES = {
	{ Name = "Common",    MinLevel = 1,  Color = Color3.fromRGB(200, 200, 200), BurstCount = 40,  AuraRate = 0  },
	{ Name = "Rare",      MinLevel = 5,  Color = Color3.fromRGB(60, 140, 255),  BurstCount = 80,  AuraRate = 5  },
	{ Name = "Legendary", MinLevel = 10, Color = Color3.fromRGB(255, 190, 40),  BurstCount = 150, AuraRate = 10 },
	{ Name = "Mythic",    MinLevel = 20, Color = Color3.fromRGB(255, 60, 220),  BurstCount = 300, AuraRate = 18 },
}

-- Yumurta gorsel buyuklugu: seviye arttikca buyur, 2.2 kat ustune cikmaz
function Config.EggScale(level)
	return math.min(1 + (level - 1) * 0.04, 2.2)
end

function Config.XPRequired(level)
	return math.floor(100 * level ^ 1.5)
end

function Config.GetRarity(level)
	local result = Config.RARITIES[1]
	for _, rarity in ipairs(Config.RARITIES) do
		if level >= rarity.MinLevel then
			result = rarity
		end
	end
	return result
end

return Config
]=])

install("ServerScriptService.Modules", "HatcheryService", "ModuleScript", [=[
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Modules = script.Parent
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)
local Registry = require(Modules.BoothRegistry)

local HatcheryService = {}

local DEFAULT_COLOR = Config.RARITIES[1].Color

local function makePrompt(parent, name, action, enabled)
	local prompt = parent:FindFirstChild(name)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.Parent = parent
	end
	prompt.ActionText = action
	prompt.ObjectText = "Mystic Hatchery"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = enabled
	return prompt
end

-- sahipsiz stand: tek satir; sahipli stand: baslik + XP cubugu + ilerleme
local function layoutGui(gui, claimed)
	gui.BarBack.Visible = claimed
	gui.Progress.Visible = claimed
	gui.Title.Size = claimed and UDim2.fromScale(1, 0.45) or UDim2.fromScale(1, 0.6)
	gui.Title.Position = claimed and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 0.2)
end

local function makeLabel(parent, name, pos, size)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = parent
	return label
end

function HatcheryService.BuildBooth(booth)
	local base = booth.PrimaryPart or booth:FindFirstChildWhichIsA("BasePart", true)
	assert(base, booth:GetFullName() .. " icinde en az bir Part olmali")
	booth.PrimaryPart = base

	local egg = booth:FindFirstChild("Egg")
	if not egg then
		egg = Instance.new("Part")
		egg.Name = "Egg"
		egg.Shape = Enum.PartType.Ball
		egg.Size = Vector3.new(3, 4, 3)
		egg.Material = Enum.Material.Neon
		egg.CFrame = base.CFrame * CFrame.new(0, base.Size.Y / 2 + 3, 0)
		egg.Parent = booth
	end
	egg.Anchored = true
	egg.CanCollide = false
	egg.Color = DEFAULT_COLOR
	if egg:GetAttribute("BaseSize") == nil then
		egg:SetAttribute("BaseSize", egg.Size) -- 1. seviye boyutu; buyume buna gore hesaplanir
	end

	if not egg:FindFirstChild("Glow") then
		local glow = Instance.new("PointLight")
		glow.Name = "Glow"
		glow.Range = 14
		glow.Brightness = 0
		glow.Color = DEFAULT_COLOR
		glow.Shadows = false
		glow.Parent = egg
	end
	if not egg:FindFirstChild("Aura") then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "Aura"
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.LightEmission = 1
		aura.Lifetime = NumberRange.new(1.2, 2)
		aura.Speed = NumberRange.new(1, 3)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		aura.Rate = 0
		aura.Enabled = false
		aura.Parent = egg
	end

	if not egg:FindFirstChild("HatcheryGui") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "HatcheryGui"
		gui.Size = UDim2.fromOffset(260, 66)
		gui.StudsOffset = Vector3.new(0, 3.4, 0) -- ApplyGrowth seviyeye gore ayarlar
		gui.MaxDistance = 45 -- uzaktan 24 yazi ust uste binmesin
		gui.Parent = egg

		makeLabel(gui, "Title", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.45))

		local back = Instance.new("Frame")
		back.Name = "BarBack"
		back.Position = UDim2.fromScale(0.05, 0.52)
		back.Size = UDim2.fromScale(0.9, 0.2)
		back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		back.BorderSizePixel = 0
		back.Parent = gui
		Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = DEFAULT_COLOR
		fill.BorderSizePixel = 0
		fill.Parent = back
		Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

		makeLabel(gui, "Progress", UDim2.fromScale(0, 0.76), UDim2.fromScale(1, 0.24))
	end

	local claim = makePrompt(base, "ClaimPrompt", "Claim Booth", true)
	local donate = makePrompt(base, "DonatePrompt", "Support Egg", false)
	CollectionService:AddTag(donate, "DonatePrompt")

	HatcheryService.SetUnclaimed(booth)
	return claim, donate
end

local function getStats(player)
	local ls = player:FindFirstChild("leaderstats")
	local data = player:FindFirstChild("EggData")
	if not (ls and data) then
		return nil, nil
	end
	return ls:FindFirstChild("Level"), data:FindFirstChild("EggXP")
end

function HatcheryService.Refresh(player)
	local booth = Registry.GetBooth(player)
	local levelVal, xpVal = getStats(player)
	if not (booth and levelVal and xpVal) then
		return
	end
	local egg = booth:FindFirstChild("Egg")
	local gui = egg and egg:FindFirstChild("HatcheryGui")
	if not (egg and gui) then
		return
	end

	local level, xp = levelVal.Value, xpVal.Value
	local need = Config.XPRequired(level)
	local rarity = Config.GetRarity(level)

	layoutGui(gui, true)
	gui.Title.Text = string.format("%s's Hatchery - Level %d", player.Name, level)
	gui.Progress.Text = string.format("%s  |  %d / %d XP", rarity.Name, xp, need)
	gui.BarBack.Fill.BackgroundColor3 = rarity.Color
	TweenService:Create(gui.BarBack.Fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1),
	}):Play()
	egg.Color = rarity.Color

	HatcheryService.ApplyGrowth(egg, level, rarity)
end

-- Yumurta seviye ile buyur; nadirlige gore parlar (Rare+ surekli kivilcim)
function HatcheryService.ApplyGrowth(egg, level, rarity)
	local base = egg:GetAttribute("BaseSize")
	if base then
		TweenService:Create(egg, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = base * Config.EggScale(level),
		}):Play()
		local gui = egg:FindFirstChild("HatcheryGui")
		if gui then
			gui.StudsOffset = Vector3.new(0, base.Y * Config.EggScale(level) / 2 + 1.6, 0) -- yazi yumurtanin ustunde kalsin
		end
	end
	local aura = egg:FindFirstChild("Aura")
	if aura then
		aura.Color = ColorSequence.new(rarity.Color, Color3.new(1, 1, 1))
		aura.Rate = rarity.AuraRate or 0
		aura.Enabled = (rarity.AuraRate or 0) > 0
	end
	local glow = egg:FindFirstChild("Glow")
	if glow then
		glow.Color = rarity.Color
		glow.Brightness = (rarity.AuraRate or 0) > 0 and 0.6 or 0
	end
end

function HatcheryService.SetClaimed(booth, player)
	local base = booth.PrimaryPart
	base.ClaimPrompt.Enabled = false
	base.DonatePrompt.Enabled = true
	HatcheryService.Refresh(player)
end

function HatcheryService.SetUnclaimed(booth)
	local base = booth.PrimaryPart
	base.ClaimPrompt.Enabled = true
	base.DonatePrompt.Enabled = false

	local egg = booth:FindFirstChild("Egg")
	local gui = egg.HatcheryGui
	layoutGui(gui, false)
	gui.Title.Text = "Unclaimed - Press E to claim!"
	gui.Progress.Text = ""
	gui.BarBack.Fill.Size = UDim2.fromScale(0, 1)
	gui.BarBack.Fill.BackgroundColor3 = DEFAULT_COLOR
	egg.Color = DEFAULT_COLOR
	HatcheryService.ApplyGrowth(egg, 1, Config.RARITIES[1])
end

function HatcheryService.BurstParticles(egg, rarity)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(rarity.Color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(15, 35)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Rate = 0
	emitter.Parent = egg
	emitter:Emit(rarity.BurstCount)
	Debris:AddItem(emitter, 3)

	-- kisa isik patlamasi (boyut animasyonu buyume ile carpismasin diye isikla)
	local glow = egg:FindFirstChild("Glow")
	if glow then
		glow.Color = rarity.Color
		glow.Brightness = 6
		TweenService:Create(glow, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Brightness = (rarity.AuraRate or 0) > 0 and 0.6 or 0,
		}):Play()
	end
end

function HatcheryService.AddXP(player, amount)
	if not player:GetAttribute("DataLoaded") then
		return
	end
	local levelVal, xpVal = getStats(player)
	if not (levelVal and xpVal) or amount <= 0 then
		return
	end

	local startLevel = levelVal.Value
	xpVal.Value += math.floor(amount)

	while levelVal.Value < Config.MAX_LEVEL do
		local need = Config.XPRequired(levelVal.Value)
		if xpVal.Value < need then
			break
		end
		xpVal.Value -= need
		levelVal.Value += 1
	end
	if levelVal.Value >= Config.MAX_LEVEL then
		xpVal.Value = math.min(xpVal.Value, Config.XPRequired(Config.MAX_LEVEL) - 1)
	end

	HatcheryService.Refresh(player)

	if levelVal.Value > startLevel then
		HatcheryService.OnEvolve(player, startLevel, levelVal.Value)
	end
end

function HatcheryService.OnEvolve(player, oldLevel, newLevel)
	local booth = Registry.GetBooth(player)
	local oldRarity, newRarity = Config.GetRarity(oldLevel), Config.GetRarity(newLevel)
	local rarityUp = newRarity ~= oldRarity

	if booth then
		local egg = booth:FindFirstChild("Egg")
		if egg then
			HatcheryService.BurstParticles(egg, newRarity)
			if rarityUp then
				task.delay(0.35, function()
					if egg.Parent then
						HatcheryService.BurstParticles(egg, newRarity)
					end
				end)
			end
		end
	end

	Remotes.EggFeedback:FireAllClients({
		Kind = "Evolve",
		Owner = player.Name,
		Level = newLevel,
		Rarity = newRarity.Name,
		RarityUp = rarityUp,
		Color = newRarity.Color,
	})
end

return HatcheryService
]=])

install("ServerScriptService", "EconomyManager", "Script", [=[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(Modules.Config)

local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)

local pendingSaves = 0
local finalSaveStarted = {}
local autosaveBusy = {}

local function keyFor(userId)
	return "Player_" .. userId
end

local function withRetry(fn, attempts)
	local result
	for i = 1, attempts do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		result = res
		warn(string.format("[Economy] DataStore deneme %d/%d basarisiz: %s", i, attempts, tostring(res)))
		task.wait(i * 1.5)
	end
	return false, result
end

local function newValue(name, parent, default)
	local v = Instance.new("IntValue")
	v.Name = name
	v.Value = default or 0
	v.Parent = parent
	return v
end

local function createValues(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player

	-- Siralama: Roblox liderlik tablosu ilk degere gore dizer
	newValue("Raised", ls, 0) -- standina gelen destek (Robux)
	newValue("Donated", ls, 0) -- baskalarina verdigin destek (Robux)
	newValue("Level", ls, 1) -- yumurta seviyesi

	local data = Instance.new("Folder")
	data.Name = "EggData"
	data.Parent = player
	newValue("EggXP", data, 0)
end

local function onPlayerAdded(player)
	createValues(player)

	local ok, saved = withRetry(function()
		return store:GetAsync(keyFor(player.UserId))
	end, 3)

	if not player.Parent then
		return
	end

	if ok then
		saved = saved or {}
		player.leaderstats.Raised.Value = saved.Raised or 0
		player.leaderstats.Donated.Value = saved.Donated or 0
		player.leaderstats.Level.Value = math.max(saved.Level or saved.EggLevel or 1, 1)
		player.EggData.EggXP.Value = saved.EggXP or 0
		player:SetAttribute("DataLoaded", true)
	else
		warn("[Economy] " .. player.Name .. " verisi yuklenemedi, bu oturumda kayit kapali.")
	end
end

local function save(player)
	if not player:GetAttribute("DataLoaded") then
		return false
	end
	local data = {
		Raised = player.leaderstats.Raised.Value,
		Donated = player.leaderstats.Donated.Value,
		Level = player.leaderstats.Level.Value,
		EggXP = player.EggData.EggXP.Value,
	}
	local ok = withRetry(function()
		return store:UpdateAsync(keyFor(player.UserId), function()
			return data
		end)
	end, 3)
	return ok
end

local function finalSave(player)
	if finalSaveStarted[player.UserId] then
		return
	end
	finalSaveStarted[player.UserId] = true
	pendingSaves += 1
	save(player)
	pendingSaves -= 1
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	finalSave(player)
	finalSaveStarted[player.UserId] = nil
	autosaveBusy[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(finalSave, player)
	end
	local deadline = os.clock() + (RunService:IsStudio() and 3 or 25)
	while pendingSaves > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			local uid = player.UserId
			if not autosaveBusy[uid] and not finalSaveStarted[uid] then
				autosaveBusy[uid] = true
				task.spawn(function()
					save(player)
					autosaveBusy[uid] = nil
				end)
				task.wait(0.5)
			end
		end
	end
end)
]=])

install("ServerScriptService", "MarketplaceHook", "Script", [=[
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)
local Registry = require(Modules.BoothRegistry)
local Hatchery = require(Modules.HatcheryService)

-- Ayni makbuz iki kere islenmesin diye kayit tutulur
local receiptStore = DataStoreService:GetDataStore("EggReceipts_v1")

local productById = {}
for _, product in ipairs(Config.PRODUCTS) do
	if product.Id > 0 then
		productById[product.Id] = product
	end
end

local priceCache = {}
local menuBooth = {}
local pending = {}

local function getPrice(productId)
	if priceCache[productId] then
		return priceCache[productId]
	end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, productId, Enum.InfoType.Product)
	if ok and info and info.PriceInRobux then
		priceCache[productId] = info.PriceInRobux
		return info.PriceInRobux
	end
	return nil
end

local function nearBooth(player, booth)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and booth.PrimaryPart ~= nil
		and (root.Position - booth.PrimaryPart.Position).Magnitude <= Config.INTERACT_DISTANCE
end

-- 1) Bagis butonuna basinca menu acilir
local function onDonateTriggered(prompt, donor)
	local booth = prompt:FindFirstAncestorOfClass("Model")
	local owner = booth and Registry.GetOwner(booth)
	if not owner then
		return
	end
	if owner == donor then
		Remotes.Notify:FireClient(donor, "Bu senin kendi yumurtan! Arkadaslarin bagis yapsin.")
		return
	end

	local items = {}
	for _, product in ipairs(Config.PRODUCTS) do
		local price = product.Id > 0 and getPrice(product.Id)
		if price then
			table.insert(items, { Id = product.Id, Name = product.Name, Price = price })
		end
	end
	if #items == 0 then
		Remotes.Notify:FireClient(donor, "Su an bagis secenegi yok.")
		return
	end

	menuBooth[donor] = booth
	Remotes.OpenDonateMenu:FireClient(donor, { Owner = owner.Name, Passes = items })
end

local function hookPrompt(prompt)
	if prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(donor)
			onDonateTriggered(prompt, donor)
		end)
	end
end

for _, prompt in ipairs(CollectionService:GetTagged("DonatePrompt")) do
	hookPrompt(prompt)
end
CollectionService:GetInstanceAddedSignal("DonatePrompt"):Connect(hookPrompt)

-- 2) Oyuncu secenegi secer, sunucu satin alma penceresini acar
Remotes.RequestPurchase.OnServerEvent:Connect(function(donor, productId)
	if typeof(productId) ~= "number" or not productById[productId] then
		return
	end
	local booth = menuBooth[donor]
	local owner = booth and Registry.GetOwner(booth)
	if not (booth and owner) or owner == donor or not nearBooth(donor, booth) then
		return
	end

	pending[donor.UserId] = {
		ProductId = productId,
		OwnerUserId = owner.UserId,
		Booth = booth,
	}
	MarketplaceService:PromptProductPurchase(donor, productId)
end)

-- Pencere kapatildiysa (satin alinmadiysa) bekleyen kaydi temizle
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
	if not isPurchased then
		pending[userId] = nil
	end
end)

-- 3) Satin alma tamamlaninca: XP + Raised (sahip) + Donated (bagisci) (Roblox makbuz sistemi)
MarketplaceService.ProcessReceipt = function(info)
	-- Bu makbuz daha once islendi mi?
	local alreadyDone = false
	local ok = pcall(function()
		receiptStore:UpdateAsync(tostring(info.PurchaseId), function(old)
			if old then
				alreadyDone = true
				return nil
			end
			return true
		end)
	end)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox tekrar dener
	end
	if alreadyDone then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local donor = Players:GetPlayerByUserId(info.PlayerId)
	local record = donor and pending[donor.UserId]
	pending[info.PlayerId] = nil
	if not (donor and record and record.ProductId == info.ProductId) then
		warn("[Marketplace] Bekleyen bagis kaydi yok, makbuz onaylandi: " .. tostring(info.PurchaseId))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local robux = info.CurrencySpent or getPrice(info.ProductId) or 0
	if donor:FindFirstChild("leaderstats") then
		donor.leaderstats.Donated.Value += robux
	end

	local owner = Registry.GetOwner(record.Booth)
	if not owner or owner.UserId ~= record.OwnerUserId then
		warn("[Marketplace] Stand sahibi cikmis, XP verilemedi.")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local xp = robux * Config.XP_PER_ROBUX

	owner.leaderstats.Raised.Value += robux

	Remotes.EggFeedback:FireAllClients({
		Kind = "Donation",
		Donor = donor.Name,
		Owner = owner.Name,
		Robux = robux,
		XP = xp,
	})
	Hatchery.AddXP(owner, xp)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

Players.PlayerRemoving:Connect(function(player)
	menuBooth[player] = nil
	pending[player.UserId] = nil
end)
]=])

if #failed > 0 then
	warn("[Guncelleme] Su scriptler elle yapistirilmali: " .. table.concat(failed, ", "))
else
	print("[Guncelleme] Bitti. Hepsi guncellendi.")
end
