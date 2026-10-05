local Config = {}

---------------------------------------------------------------------
-- Genel
---------------------------------------------------------------------
Config.DATASTORE_NAME = "EggHatchery_v1"
Config.PENDING_STORE = "EggPending_v1" -- sahibi cevrimdisiyken gelen bagislar burada bekler
Config.AUTOSAVE_INTERVAL = 120
Config.BOOTH_FOLDER_NAME = "Booths"
Config.INTERACT_DISTANCE = 25 -- panel/aksiyon icin standa en fazla bu kadar uzaklik
Config.OWNER_CHECK_INTERVAL = 5

---------------------------------------------------------------------
-- XP ve seviye
-- Seviye atlamak icin gereken XP: XP_BASE * seviye ^ XP_EXP
-- (40 XP ile 2. seviye, 113 XP ile 3., 208 ile 4., ... ilk acilimlar hizli gelir)
---------------------------------------------------------------------
Config.MAX_LEVEL = 50
Config.XP_BASE = 40
Config.XP_EXP = 1.5
Config.XP_PER_ROBUX = 20 -- 1 Robux bagis = stand sahibine 20 XP

-- Oynama suresi XP'si: her PLAY_INTERVAL saniyede PLAY_XP (hareket ediyorsan; AFK sayilmaz)
-- 1 Robux bagis = 5 dk oynama: 300 sn / 15 sn * 1 XP = 20 XP = XP_PER_ROBUX
Config.PLAY_XP = 1
Config.PLAY_INTERVAL = 15
Config.PLAY_MIN_MOVE = 2 -- bu aralikta en az bu kadar stud yer degistirmeli
-- Bagis yapan kisiye gelen XP (her Robux icin) = 5 dk oynama
Config.DONOR_XP_PER_ROBUX = 20

function Config.XPRequired(level)
	return math.floor(Config.XP_BASE * level ^ Config.XP_EXP)
end

-- Bedava XP: yumurtayi beslemek
Config.FEED_XP_OWN = 5 -- kendi yumurtani beslersen
Config.FEED_COOLDOWN_OWN = 20
Config.FEED_XP_OTHER = 3 -- baskasinin yumurtasini beslersen, sahibine gider
Config.FEED_XP_FEEDER = 1 -- baskasini besleyen kendi yumurtasina da bu kadar alir (standi varsa)
Config.FEED_COOLDOWN_OTHER = 30 -- ayni oyuncu ayni standi bu surede bir besleyebilir
Config.FEED_GLOBAL_COOLDOWN = 3 -- bir oyuncu herhangi bir stand icin en az bu aralikla besleyebilir

-- Nadirlik: seviyeye gore
Config.RARITIES = {
	{ Name = "Yaygın", MinLevel = 1, Color = Color3.fromRGB(200, 205, 214), BurstCount = 40, AuraRate = 0 },
	{ Name = "Nadir", MinLevel = 5, Color = Color3.fromRGB(70, 150, 255), BurstCount = 80, AuraRate = 5 },
	{ Name = "Efsanevi", MinLevel = 10, Color = Color3.fromRGB(255, 190, 40), BurstCount = 150, AuraRate = 10 },
	{ Name = "Mitik", MinLevel = 20, Color = Color3.fromRGB(255, 80, 225), BurstCount = 300, AuraRate = 18 },
}

function Config.GetRarity(level)
	local result = Config.RARITIES[1]
	for _, rarity in ipairs(Config.RARITIES) do
		if level >= rarity.MinLevel then
			result = rarity
		end
	end
	return result
end

-- Yumurta gorsel buyuklugu: seviye arttikca buyur, 2.2 kat ustune cikmaz
function Config.EggScale(level)
	return math.min(1 + (level - 1) * 0.04, 2.2)
end

---------------------------------------------------------------------
-- Stand stilleri: seviye ile acilir, standin uzerinde gorsel olarak belirir
---------------------------------------------------------------------
Config.STYLES = {
	{ Id = "classic", Name = "Klasik", Level = 1, Desc = "Sade ve temiz bir başlangıç." },
	{ Id = "rug", Name = "Halı", Level = 2, Desc = "Standının önüne renkli bir halı serilir." },
	{ Id = "flags", Name = "Bayraklı", Level = 3, Desc = "Köşelere direk, aralarına renkli bayraklar." },
	{ Id = "lantern", Name = "Fenerli", Level = 5, Desc = "Sıcak ışıklı iki fener standını aydınlatır." },
	{ Id = "garden", Name = "Çiçekli", Level = 7, Desc = "Köşelerde çiçek saksıları." },
	{ Id = "gold", Name = "Altın", Level = 10, Desc = "Altın direkler, yumurtanın altında parlak zemin." },
	{ Id = "legend", Name = "Efsane", Level = 20, Desc = "Altın süs, ışık sütunu ve parıltı." },
}

function Config.GetStyle(id)
	for _, s in ipairs(Config.STYLES) do
		if s.Id == id then
			return s
		end
	end
	return nil
end

-- Bu seviyede secilebilen stil mi?
function Config.IsStyleUnlocked(id, level)
	local s = Config.GetStyle(id)
	return s ~= nil and level >= s.Level
end

-- Verilen seviyeden sonra acilacak ilk stil (yoksa nil)
function Config.NextUnlock(level)
	for _, s in ipairs(Config.STYLES) do
		if s.Level > level then
			return s
		end
	end
	return nil
end

-- Iki seviye arasinda (eski, yeni] yeni acilan stiller
function Config.NewUnlocks(oldLevel, newLevel)
	local list = {}
	for _, s in ipairs(Config.STYLES) do
		if s.Level > oldLevel and s.Level <= newLevel then
			table.insert(list, s)
		end
	end
	return list
end

Config.STYLE_COLORS = {
	{ Name = "Kırmızı", Color = Color3.fromRGB(255, 99, 99) },
	{ Name = "Turuncu", Color = Color3.fromRGB(255, 160, 70) },
	{ Name = "Sarı", Color = Color3.fromRGB(255, 224, 90) },
	{ Name = "Yeşil", Color = Color3.fromRGB(110, 230, 130) },
	{ Name = "Turkuaz", Color = Color3.fromRGB(80, 220, 210) },
	{ Name = "Mavi", Color = Color3.fromRGB(100, 160, 255) },
	{ Name = "Mor", Color = Color3.fromRGB(190, 140, 255) },
	{ Name = "Pembe", Color = Color3.fromRGB(255, 130, 200) },
}
Config.STYLE_MAX_LENGTH = 40
Config.STYLE_COOLDOWN = 2

---------------------------------------------------------------------
-- Bagis urunleri (Developer Product). Creator Hub'da olustur, ID'yi buraya yaz.
---------------------------------------------------------------------
Config.PRODUCTS = {
	{ Id = 0, Name = "Atıştırmalık" },
	{ Id = 0, Name = "Ziyafet" },
	{ Id = 0, Name = "Şölen" },
	{ Id = 0, Name = "Büyük İkram" },
}
Config.PURCHASE_COOLDOWN = 2

---------------------------------------------------------------------
-- Liderlik panolari: Studio'da Board_Raised, Board_Donated, Board_Level adli Part'lar
---------------------------------------------------------------------
Config.LEADERBOARD_REFRESH = 60
Config.LEADERBOARD_SIZE = 10
Config.LEADERBOARDS = {
	Raised = { Store = "EggLB_Raised_v1", Title = "EN ÇOK TOPLAYAN" },
	Donated = { Store = "EggLB_Donated_v1", Title = "EN ÇOK BAĞIŞLAYAN" },
	Level = { Store = "EggLB_Level_v1", Title = "EN YÜKSEK YUMURTA" },
}

---------------------------------------------------------------------
-- Metinler (tek yerden duzenlenir)
---------------------------------------------------------------------
Config.TEXT = {
	Unclaimed = "Boş Stand",
	ClaimHint = "Almak için E'ye bas",
	PromptClaim = "Standı Al",
	PromptView = "Standa Bak",
	PromptObject = "Yumurta Standı",
	Claimed = "Stand senin! Yumurtana bakmak için standa yaklaş ve E'ye bas.",
	AlreadyHave = "Zaten bir standın var!",
	Loading = "Verilerin yükleniyor...",
	NotNear = "Standa biraz daha yaklaş.",
	FedOwn = "Yumurtanı besledin (+%d XP)",
	FedOther = "%s oyuncusunun yumurtasını besledin!",
	FedBy = "%s yumurtanı besledi (+%d XP)",
	Full = "Yumurta tok! %d sn sonra tekrar dene.",
	StyleSaved = "Stand ayarların kaydedildi!",
	StyleLocked = "%s stili Seviye %d'de açılır.",
	StyleTooFast = "Biraz yavaş! Birkaç saniye sonra tekrar dene.",
	StyleTooLong = "Mesaj en fazla %d karakter olabilir.",
	StyleFilterFail = "Mesaj şu an kontrol edilemedi, tekrar dene.",
	Unlocked = "Yeni stil açıldı: %s",
	Tip = "Bir stand sahiplen: boş bir standa yaklaş ve E'ye bas.",
}

return Config
