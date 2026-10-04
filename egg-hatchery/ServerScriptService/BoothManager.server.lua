-- ServerScriptService/BoothManager  (Script)
-- Workspace layout: Workspace > Booths (Folder) > any number of Models (each with >= 1 BasePart).
-- Prompts, egg and billboard are auto-generated if missing.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)
local Registry = require(Modules.BoothRegistry)
local Hatchery = require(Modules.HatcheryService)

local boothFolder = Workspace:WaitForChild(Config.BOOTH_FOLDER_NAME)

local function release(booth: Model)
	Registry.Release(booth)
	booth:SetAttribute("OwnerUserId", nil)
	Hatchery.SetUnclaimed(booth)
end

local function claim(booth: Model, player: Player)
	-- Handlers run on one thread and nothing below yields, so double-claims can't race.
	if not player:GetAttribute("DataLoaded") then
		Remotes.Notify:FireClient(player, "Your data is still loading...")
		return
	end
	if Registry.GetOwner(booth) then
		return
	end
	if Registry.GetBooth(player) then
		Remotes.Notify:FireClient(player, "You already own a booth!")
		return
	end

	Registry.Claim(booth, player)
	booth:SetAttribute("OwnerUserId", player.UserId)
	Hatchery.SetClaimed(booth, player)
	Remotes.Notify:FireClient(player, "Booth claimed! Your egg grows while you stay.")
end

local function setupBooth(booth: Instance)
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

-- Immediate reset when the owner leaves.
Players.PlayerRemoving:Connect(function(player)
	local booth = Registry.GetBooth(player)
	if booth then
		release(booth)
	end
end)

-- Periodic safety net: frees booths whose owner is gone/invalid (crashes, teleports, etc.).
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
