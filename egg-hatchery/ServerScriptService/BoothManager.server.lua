local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)
local Registry = require(Modules.BoothRegistry)
local Hatchery = require(Modules.HatcheryService)

local boothFolder = Workspace:WaitForChild(Config.BOOTH_FOLDER_NAME)

local function release(booth)
	Registry.Release(booth)
	booth:SetAttribute("OwnerUserId", nil)
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
	Hatchery.SetClaimed(booth, player)
	Remotes.Notify:FireClient(player, "Stand senin! Yumurtan sen oldukca buyur.")
end

local function setupBooth(booth)
	if not booth:IsA("Model") then
		return
	end
	local claimPrompt = Hatchery.BuildBooth(booth)
	claimPrompt.Triggered:Connect(function(player)
		claim(booth, player)
	end)
end

for _, booth in ipairs(boothFolder:GetChildren()) do
	setupBooth(booth)
end
boothFolder.ChildAdded:Connect(setupBooth)

-- Sahibi cikinca stand sifirlanir
Players.PlayerRemoving:Connect(function(player)
	local booth = Registry.GetBooth(player)
	if booth then
		release(booth)
	end
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
