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
local pendingStore = DataStoreService:GetDataStore(Config.PENDING_STORE)

local productById = {}
for _, product in ipairs(Config.PRODUCTS) do
	if product.Id > 0 then
		productById[product.Id] = product
	end
end

local priceCache = {}
local menuBooth = {}
local pending = {}
local lastRequest = {} -- [player] = son satin alma istegi zamani (spam korumasi)

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
	local now = time()
	if lastRequest[donor] and now - lastRequest[donor] < Config.PURCHASE_COOLDOWN then
		return -- cok sik istek (spam)
	end
	local booth = menuBooth[donor]
	local owner = booth and Registry.GetOwner(booth)
	if not (booth and owner) or owner == donor or not nearBooth(donor, booth) then
		return
	end
	lastRequest[donor] = now

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
	pending[info.PlayerId] = nil -- kesin sonuc cikinca temizlenir; gecici hatada asagida geri konur
	if not (donor and record and record.ProductId == info.ProductId) then
		warn("[Marketplace] Bekleyen bagis kaydi yok, makbuz onaylandi: " .. tostring(info.PurchaseId))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local robux = info.CurrencySpent or getPrice(info.ProductId) or 0
	local xp = robux * Config.XP_PER_ROBUX
	local owner = Registry.GetOwner(record.Booth)

	if not owner or owner.UserId ~= record.OwnerUserId then
		-- Sahibi satin alma sirasinda cikti: bagis kaybolmasin, sahip tekrar girince uygulanir
		local queued = false
		for attempt = 1, 3 do
			local ok = pcall(function()
				pendingStore:UpdateAsync(tostring(record.OwnerUserId), function(old)
					old = old or { XP = 0, Raised = 0 }
					old.XP = (old.XP or 0) + xp
					old.Raised = (old.Raised or 0) + robux
					return old
				end)
			end)
			if ok then
				queued = true
				break
			end
			task.wait(attempt)
		end
		if not queued then
			pcall(function()
				receiptStore:RemoveAsync(tostring(info.PurchaseId))
			end)
			pending[info.PlayerId] = record -- Roblox makbuzu tekrar gonderecek; kayit korunmali
			return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox tekrar dener
		end
		if donor:FindFirstChild("leaderstats") then
			donor.leaderstats.Donated.Value += robux
		end
		warn("[Marketplace] Stand sahibi cikmis; bagis sahibine biriktirildi (+" .. xp .. " XP).")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if donor:FindFirstChild("leaderstats") then
		donor.leaderstats.Donated.Value += robux
	end
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
	lastRequest[player] = nil
end)
