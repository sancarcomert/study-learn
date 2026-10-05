local Config = {}

Config.DATASTORE_NAME = "EggHatchery_v1"
Config.AUTOSAVE_INTERVAL = 120
Config.XP_PER_ROBUX = 20
Config.MAX_LEVEL = 100
Config.INTERACT_DISTANCE = 25
Config.OWNER_CHECK_INTERVAL = 5
Config.BOOTH_FOLDER_NAME = "Booths"
Config.PURCHASE_COOLDOWN = 2 -- ayni oyuncu bu kadar saniyede bir satin alma baslatabilir
Config.PENDING_STORE = "EggPending_v1" -- sahibi cevrimdisiyken gelen bagislar burada bekler
Config.LEADERBOARD_REFRESH = 60 -- pano yenileme sikligi (sn)
Config.LEADERBOARD_SIZE = 10
-- Kucuk harf: Studio'da panoya bu adlarla Part koy (Board_Raised, Board_Donated, Board_Level)
Config.LEADERBOARDS = {
	Raised = { Store = "EggLB_Raised_v1", Title = "EN COK TOPLAYAN" },
	Donated = { Store = "EggLB_Donated_v1", Title = "EN COK BAGISLAYAN" },
	Level = { Store = "EggLB_Level_v1", Title = "EN YUKSEK YUMURTA" },
}

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
