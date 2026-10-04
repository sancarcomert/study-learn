-- ServerScriptService/EconomyManager  (Script)
-- Leaderstats (TimePoints, EggLevel), hidden EggXP, DataStore load/save, per-second ticker.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(Modules.Config)
local Registry = require(Modules.BoothRegistry)
local Hatchery = require(Modules.HatcheryService)

local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)

local pendingSaves = 0                       -- in-flight final saves (for BindToClose)
local finalSaveStarted: { [number]: boolean } = {}
local autosaveBusy: { [number]: boolean } = {}

local function keyFor(userId: number): string
	return "Player_" .. userId
end

-- Retries a DataStore call with backoff; returns (ok, result).
local function withRetry(fn: () -> any, attempts: number)
	local result
	for i = 1, attempts do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		result = res
		warn(string.format("[Economy] DataStore attempt %d/%d failed: %s", i, attempts, tostring(res)))
		task.wait(i * 1.5)
	end
	return false, result
end

---------------------------------------------------------------------
-- Setup / load
---------------------------------------------------------------------

local function createValues(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player

	local points = Instance.new("IntValue")
	points.Name = "TimePoints"
	points.Parent = ls

	local level = Instance.new("IntValue")
	level.Name = "EggLevel"
	level.Value = 1
	level.Parent = ls

	local data = Instance.new("Folder")
	data.Name = "EggData"
	data.Parent = player

	local xp = Instance.new("IntValue")
	xp.Name = "EggXP"
	xp.Parent = data
end

local function onPlayerAdded(player: Player)
	createValues(player)

	local ok, saved = withRetry(function()
		return store:GetAsync(keyFor(player.UserId))
	end, 3)

	if not player.Parent then
		return -- left while loading
	end

	if ok then
		saved = saved or {}
		player.leaderstats.TimePoints.Value = saved.TimePoints or 0
		player.leaderstats.EggLevel.Value = math.max(saved.EggLevel or 1, 1)
		player.EggData.EggXP.Value = saved.EggXP or 0
		player:SetAttribute("DataLoaded", true) -- gates XP, claiming and saving
	else
		-- Never save defaults over a failed load; player simply can't progress this session.
		warn("[Economy] Load failed for " .. player.Name .. "; saving disabled for this session.")
	end
end

---------------------------------------------------------------------
-- Save
---------------------------------------------------------------------

local function snapshot(player: Player)
	return {
		TimePoints = player.leaderstats.TimePoints.Value,
		EggLevel = player.leaderstats.EggLevel.Value,
		EggXP = player.EggData.EggXP.Value,
	}
end

local function save(player: Player): boolean
	if not player:GetAttribute("DataLoaded") then
		return false
	end
	local data = snapshot(player)
	local ok = withRetry(function()
		return store:UpdateAsync(keyFor(player.UserId), function()
			return data
		end)
	end, 3)
	return ok
end

local function finalSave(player: Player)
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

-- Autosave loop (staggered so we stay inside DataStore budgets).
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

---------------------------------------------------------------------
-- Ticker: +1 TimePoint per second; passive egg XP while the owner has a booth
---------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("DataLoaded") then
				player.leaderstats.TimePoints.Value += 1
				if Registry.GetBooth(player) then
					Hatchery.AddXP(player, Config.PASSIVE_XP_PER_SECOND)
				end
			end
		end
	end
end)
