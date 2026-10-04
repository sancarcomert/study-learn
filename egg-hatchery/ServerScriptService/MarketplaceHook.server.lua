-- ServerScriptService/MarketplaceHook  (Script)
-- Donate prompt -> menu -> server-initiated gamepass prompt -> verified XP award.
-- The client only *requests* a prompt; XP is awarded here after PromptGamePassPurchaseFinished.
-- Note: gamepasses are one-time per donor. For repeat donations, add Developer Products + ProcessReceipt.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)
local Registry = require(Modules.BoothRegistry)
local Hatchery = require(Modules.HatcheryService)

local passById = {}                -- whitelist: [passId] = config entry
for _, pass in ipairs(Config.GAMEPASSES) do
	if pass.Id > 0 then
		passById[pass.Id] = pass
	end
end

local priceCache = {}              -- [passId] = Robux price
local menuBooth = {}               -- [donor] = booth whose menu they have open
local pending = {}                 -- [donor.UserId] = { PassId, OwnerUserId, Booth, Expires }

-- Fetches (and caches) a gamepass's Robux price; nil if unavailable/off-sale.
local function getPrice(passId: number): number?
	if priceCache[passId] then
		return priceCache[passId]
	end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, passId, Enum.InfoType.GamePass)
	if ok and info and info.PriceInRobux then
		priceCache[passId] = info.PriceInRobux
		return info.PriceInRobux
	end
	return nil
end

local function nearBooth(player: Player, booth: Model): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and booth.PrimaryPart ~= nil
		and (root.Position - booth.PrimaryPart.Position).Magnitude <= Config.INTERACT_DISTANCE
end

---------------------------------------------------------------------
-- 1) Donate prompt opens the menu on the donor's client
---------------------------------------------------------------------

local function onDonateTriggered(prompt: ProximityPrompt, donor: Player)
	local booth = prompt:FindFirstAncestorOfClass("Model")
	local owner = booth and Registry.GetOwner(booth)
	if not owner then
		return
	end
	if owner == donor then
		Remotes.Notify:FireClient(donor, "That's your own egg! Ask friends to donate.")
		return
	end

	local passes = {}
	for _, pass in ipairs(Config.GAMEPASSES) do
		local price = pass.Id > 0 and getPrice(pass.Id)
		if price then
			table.insert(passes, { Id = pass.Id, Name = pass.Name, Price = price })
		end
	end
	if #passes == 0 then
		Remotes.Notify:FireClient(donor, "No donation items are available right now.")
		return
	end

	menuBooth[donor] = booth
	Remotes.OpenDonateMenu:FireClient(donor, { Owner = owner.Name, Passes = passes })
end

local function hookPrompt(prompt: Instance)
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

---------------------------------------------------------------------
-- 2) Client picks a pass -> server validates -> server prompts purchase
---------------------------------------------------------------------

Remotes.RequestPurchase.OnServerEvent:Connect(function(donor, passId)
	if typeof(passId) ~= "number" or not passById[passId] then
		return
	end
	local booth = menuBooth[donor]
	local owner = booth and Registry.GetOwner(booth)
	if not (booth and owner) or owner == donor or not nearBooth(donor, booth) then
		return
	end
	local existing = pending[donor.UserId]
	if existing and os.clock() < existing.Expires then
		return -- a prompt is already open
	end

	pending[donor.UserId] = {
		PassId = passId,
		OwnerUserId = owner.UserId,
		Booth = booth,
		Expires = os.clock() + Config.PURCHASE_TIMEOUT,
	}
	MarketplaceService:PromptGamePassPurchase(donor, passId)
end)

---------------------------------------------------------------------
-- 3) Purchase result -> award XP to the booth owner's egg
---------------------------------------------------------------------

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(donor, passId, wasPurchased)
	local record = pending[donor.UserId]
	pending[donor.UserId] = nil
	if not record or record.PassId ~= passId or not wasPurchased then
		return -- cancelled, or not a booth purchase
	end

	local owner = Registry.GetOwner(record.Booth)
	if not owner or owner.UserId ~= record.OwnerUserId then
		return -- owner left mid-purchase; nobody to credit
	end

	local robux = getPrice(passId) or 0
	local xp = robux * Config.XP_PER_ROBUX

	-- Server -> clients: show the donation banner (purely cosmetic; XP is already server-side).
	Remotes.EggFeedback:FireAllClients({
		Kind = "Donation",
		Donor = donor.Name,
		Owner = owner.Name,
		Robux = robux,
		XP = xp,
	})
	Hatchery.AddXP(owner, xp) -- may trigger evolution + particle burst
end)

Players.PlayerRemoving:Connect(function(player)
	menuBooth[player] = nil
	pending[player.UserId] = nil
end)
