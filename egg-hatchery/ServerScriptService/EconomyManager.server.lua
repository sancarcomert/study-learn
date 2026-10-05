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
