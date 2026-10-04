-- ServerScriptService/Modules/Config  (ModuleScript)
-- Central tuning file. Every number in the game economy lives here.

local Config = {}

Config.DATASTORE_NAME = "EggHatchery_v1"
Config.AUTOSAVE_INTERVAL = 120       -- seconds between autosaves
Config.PASSIVE_XP_PER_SECOND = 1     -- egg XP while the owner idles at a claimed booth
Config.XP_PER_ROBUX = 20             -- "massive" boost: 100 R$ = 2000 XP
Config.MAX_LEVEL = 100
Config.INTERACT_DISTANCE = 25        -- studs; server-side anti-exploit check
Config.OWNER_CHECK_INTERVAL = 5      -- seconds between booth-owner sanity checks
Config.BOOTH_FOLDER_NAME = "Booths"  -- Workspace folder holding one Model per booth
Config.PURCHASE_TIMEOUT = 300        -- seconds before a pending purchase is discarded

-- Gamepasses sold at every booth. REPLACE the Ids with your real gamepass Ids.
Config.GAMEPASSES = {
	{ Id = 0, Name = "Egg Snack" },
	{ Id = 0, Name = "Egg Feast" },
	{ Id = 0, Name = "Egg Banquet" },
	{ Id = 0, Name = "Egg Jackpot" },
}

-- Ascending by MinLevel. BurstCount = particles fired on evolution.
Config.RARITIES = {
	{ Name = "Common",    MinLevel = 1,  Color = Color3.fromRGB(200, 200, 200), BurstCount = 40  },
	{ Name = "Rare",      MinLevel = 5,  Color = Color3.fromRGB(60, 140, 255),  BurstCount = 80  },
	{ Name = "Legendary", MinLevel = 10, Color = Color3.fromRGB(255, 190, 40),  BurstCount = 150 },
	{ Name = "Mythic",    MinLevel = 20, Color = Color3.fromRGB(255, 60, 220),  BurstCount = 300 },
}

-- XP needed to go from `level` to `level + 1`.
function Config.XPRequired(level: number): number
	return math.floor(100 * level ^ 1.5)
end

-- Returns the rarity table for a given level.
function Config.GetRarity(level: number)
	local result = Config.RARITIES[1]
	for _, rarity in ipairs(Config.RARITIES) do
		if level >= rarity.MinLevel then
			result = rarity
		end
	end
	return result
end

return Config
