local Config = {}

Config.DATASTORE_NAME = "EggHatchery_v1"
Config.AUTOSAVE_INTERVAL = 120
Config.PASSIVE_XP_PER_SECOND = 1
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
	{ Name = "Common",    MinLevel = 1,  Color = Color3.fromRGB(200, 200, 200), BurstCount = 40  },
	{ Name = "Rare",      MinLevel = 5,  Color = Color3.fromRGB(60, 140, 255),  BurstCount = 80  },
	{ Name = "Legendary", MinLevel = 10, Color = Color3.fromRGB(255, 190, 40),  BurstCount = 150 },
	{ Name = "Mythic",    MinLevel = 20, Color = Color3.fromRGB(255, 60, 220),  BurstCount = 300 },
}

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
