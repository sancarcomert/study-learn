-- dev/test_scripts.lua : EconomyManager + BoothManager + MarketplaceHook birlikte (sanal zamanla)
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	local Players = game:GetService("Players")
	local MS = game:GetService("MarketplaceService")
	local Config = require(__SSS.Modules.Config)
	local Registry = require(__SSS.Modules.BoothRegistry)
	local Remotes = require(__SSS.Modules.Remotes)

	local function firedOf(remote)
		return rawget(remote, "_d").fired or {}
	end
	local function runScript(name)
		local inst = Instance.new("Script")
		inst.Name = name
		inst.Parent = __SSS
		__scriptFns[name](inst)
	end
	local function newPlayer(name, uid)
		local p = Instance.new("Player")
		p.Name = name
		p.UserId = uid
		p.Parent = Players
		__fire(Players, "PlayerAdded", p)
		return p
	end
	local function leave(p)
		__fire(Players, "PlayerRemoving", p)
		p.Parent = nil
	end

	print("== Kurulum ==")
	local ids = { 111, 222, 333, 444 }
	local prices = { 25, 100, 500, 1000 }
	for i = 1, 4 do
		Config.PRODUCTS[i].Id = ids[i]
		__setProductPrice(ids[i], prices[i])
	end
	local st = __store(Config.DATASTORE_NAME)
	st.data["Player_1001"] = { EggLevel = 3, EggXP = 12, Raised = 7 } -- eski kayit bicimi (EggLevel) yeni Level'e tasinmali
	runScript("EconomyManager")
	runScript("BoothManager")
	runScript("MarketplaceHook")

	print("== EconomyManager: yukleme ==")
	local alice = newPlayer("Alice", 1001)
	check(alice:GetAttribute("DataLoaded") == true, "kayitli veri yuklendi, DataLoaded=true")
	check(alice.leaderstats.Level.Value == 3 and alice.leaderstats.Donated.Value == 0, "eski EggLevel=3 -> Level=3, Donated=0")
	check(alice.leaderstats.Raised.Value == 7 and alice.EggData.EggXP.Value == 12, "Raised=7, EggXP=12")
	check(alice.leaderstats:FindFirstChild("TimePoints") == nil, "TimePoints artik yok")
	local order = {}
	for _, c in ipairs(alice.leaderstats:GetChildren()) do
		table.insert(order, c.Name)
	end
	check(table.concat(order, ",") == "Raised,Donated,Level", "liderlik tablosu sirasi: " .. table.concat(order, ","))
	__advance(5)
	check(alice.EggData.EggXP.Value == 12, "sure gecmekle XP artmaz (yalnizca bagis buyutur)")

	print("== BoothManager: sahiplenme ==")
	local b2 = workspace.Booths.Booth_2
	__fire(b2.PrimaryPart.ClaimPrompt, "Triggered", alice)
	check(Registry.GetOwner(b2) == alice, "Alice Booth_2'yi sahiplendi")
	check(b2:GetAttribute("OwnerUserId") == 1001, "Booth_2 OwnerUserId attribute'u (MapFX huzmesi icin)")
	check(b2.Egg.HatcheryGui.Title.Text == "Alice's Hatchery - Level 3", "baslik: " .. b2.Egg.HatcheryGui.Title.Text)
	__advance(10)
	check(alice.EggData.EggXP.Value == 12, "standi varken de sure XP vermez")

	local bob = newPlayer("Bob", 2002)
	__fire(b2.PrimaryPart.ClaimPrompt, "Triggered", bob)
	check(Registry.GetOwner(b2) == alice, "dolu standi baskasi sahiplenemez")
	local b3, b4 = workspace.Booths.Booth_3, workspace.Booths.Booth_4
	__fire(b3.PrimaryPart.ClaimPrompt, "Triggered", bob)
	check(Registry.GetOwner(b3) == bob, "Bob Booth_3'u sahiplendi")
	__fire(b4.PrimaryPart.ClaimPrompt, "Triggered", bob)
	check(Registry.GetOwner(b4) == nil, "ayni oyuncu ikinci stand alamaz")
	local lastNotify = firedOf(Remotes.Notify)
	check(lastNotify[#lastNotify][2] == "Zaten bir standin var!", "uyari bildirimi gonderildi")

	print("== Bedava XP (besleme) ve stand ayari ==")
	local function placeChar(player, booth)
		local c = Instance.new("Model")
		c.Name = player.Name .. "Char"
		local r = Instance.new("Part")
		r.Name = "HumanoidRootPart"
		r.Size = Vector3.new(2, 2, 1)
		r.CFrame = booth.PrimaryPart.CFrame + Vector3.new(0, 0, -3)
		r.Parent = c
		c.Parent = workspace
		player.Character = c
	end
	check(alice:GetAttribute("HasBooth") == true, "sahip oyuncunun HasBooth attribute'u true (istemci ayar dugmesi icin)")
	check(b2.PrimaryPart.FeedPrompt.Enabled == true and b4.PrimaryPart.FeedPrompt.Enabled == false, "besleme butonu sadece sahipli standda acik")
	local xp0 = alice.EggData.EggXP.Value
	__fire(b2.PrimaryPart.FeedPrompt, "Triggered", alice)
	check(alice.EggData.EggXP.Value == xp0, "karakteri standdan uzak/yok: besleme yok sayildi")
	placeChar(alice, b2)
	__fire(b2.PrimaryPart.FeedPrompt, "Triggered", alice)
	check(alice.EggData.EggXP.Value == xp0 + Config.FEED_XP_OWN, "kendi yumurtani beslemek +" .. Config.FEED_XP_OWN .. " XP")
	__fire(b2.PrimaryPart.FeedPrompt, "Triggered", alice)
	check(alice.EggData.EggXP.Value == xp0 + Config.FEED_XP_OWN, "bekleme suresinde tekrar besleme XP vermedi")
	local nf = firedOf(Remotes.Notify)
	check(nf[#nf][2]:find("tok") ~= nil, "bekleme uyarisi: " .. nf[#nf][2])
	__advance(Config.FEED_COOLDOWN_OWN + 1)
	__fire(b2.PrimaryPart.FeedPrompt, "Triggered", alice)
	check(alice.EggData.EggXP.Value == xp0 + 2 * Config.FEED_XP_OWN, "bekleme bitince tekrar +XP")

	placeChar(bob, b2)
	local xp1 = alice.EggData.EggXP.Value
	__fire(b2.PrimaryPart.FeedPrompt, "Triggered", bob)
	check(alice.EggData.EggXP.Value == xp1 + Config.FEED_XP_OTHER, "baskasinin yumurtasini beslemek sahibine +" .. Config.FEED_XP_OTHER .. " XP")
	local na = firedOf(Remotes.Notify)
	local sawOwnerMsg = false
	for _, f in ipairs(na) do
		if f[1] == alice and tostring(f[2]):find("Bob yumurtani besledi") then
			sawOwnerMsg = true
		end
	end
	check(sawOwnerMsg, "sahibe 'Bob yumurtani besledi' bildirimi gitti")
	__fire(b2.PrimaryPart.FeedPrompt, "Triggered", bob)
	check(alice.EggData.EggXP.Value == xp1 + Config.FEED_XP_OTHER, "3 sn kuresel bekleme: spam yok sayildi")
	__advance(Config.FEED_GLOBAL_COOLDOWN + 1)
	__fire(b2.PrimaryPart.FeedPrompt, "Triggered", bob)
	check(alice.EggData.EggXP.Value == xp1 + Config.FEED_XP_OTHER, "ayni standi 30 sn icinde tekrar beslemek XP vermedi")
	__advance(Config.FEED_COOLDOWN_OTHER)
	__fire(b2.PrimaryPart.FeedPrompt, "Triggered", bob)
	check(alice.EggData.EggXP.Value == xp1 + 2 * Config.FEED_XP_OTHER, "bekleme bitince tekrar +XP")
	local xpb4 = bob.EggData.EggXP.Value
	__fire(b4.PrimaryPart.FeedPrompt, "Triggered", bob)
	check(bob.EggData.EggXP.Value == xpb4, "sahipsiz standi beslemek bir sey yapmaz")

	-- stand ayari (mesaj + renk)
	local style = Remotes.SetBoothStyle
	__fire(style, "OnServerEvent", alice, { Text = "  Pet icin   biriktiriyorum  ", Color = 3 })
	check(alice:GetAttribute("BoothMessage") == "Pet icin biriktiriyorum" and alice:GetAttribute("BoothColor") == 3, "mesaj kirpildi/bosluklar toplandi, renk 3 kaydedildi")
	local g = b2.Egg.HatcheryGui
	check(g.Message.Text == "Pet icin biriktiriyorum" and g.Message.Visible == true, "mesaj yumurtanin ustundeki yaziya basildi")
	check(g.Message.TextColor3 == Config.STYLE_COLORS[3].Color, "mesaj rengi secilen renk")
	__fire(style, "OnServerEvent", alice, { Text = "baska", Color = 1 })
	check(alice:GetAttribute("BoothMessage") == "Pet icin biriktiriyorum", "3 sn bekleme: ayar spam'i yok sayildi")
	__advance(4)
	__fire(style, "OnServerEvent", alice, { Text = "BadWord burada", Color = 1 })
	check(alice:GetAttribute("BoothMessage") == "####### burada", "Roblox filtresinden gecen yazi saklandi: " .. tostring(alice:GetAttribute("BoothMessage")))
	__advance(4)
	__fire(style, "OnServerEvent", alice, { Text = string.rep("a", Config.STYLE_MAX_LENGTH + 1), Color = 1 })
	check(alice:GetAttribute("BoothMessage") == "####### burada", "cok uzun mesaj reddedildi")
	__advance(4)
	__fire(style, "OnServerEvent", alice, { Text = "ok", Color = 99 })
	check(alice:GetAttribute("BoothMessage") == "####### burada", "gecersiz renk reddedildi")
	__advance(4)
	__fire(style, "OnServerEvent", alice, { Text = 123, Color = 1 })
	__fire(style, "OnServerEvent", alice, "hile")
	__fire(style, "OnServerEvent", alice, { Text = "x" })
	check(alice:GetAttribute("BoothMessage") == "####### burada", "yanlis turdeki veri (sayi/string/eksik) reddedildi")
	__textFilterFail = true
	__advance(4)
	__fire(style, "OnServerEvent", alice, { Text = "yeni", Color = 1 })
	check(alice:GetAttribute("BoothMessage") == "####### burada", "filtre hata verirse mesaj KAYDEDILMEZ")
	__textFilterFail = false
	__advance(4)
	__fire(style, "OnServerEvent", alice, { Text = "satir\nsonu\tsekme", Color = 6 })
	check(alice:GetAttribute("BoothMessage") == "satir sonu sekme" and alice:GetAttribute("BoothColor") == 6, "satir sonu/tab bosluga cevrildi")
	__advance(4)
	__fire(style, "OnServerEvent", alice, { Text = "", Color = 2 })
	check(alice:GetAttribute("BoothMessage") == "" and b2.Egg.HatcheryGui.Message.Visible == false, "bos mesaj: yazi gizlenir")
	__advance(4)
	__fire(style, "OnServerEvent", alice, { Text = "Kalici mesaj", Color = 4 })
	local dan = newPlayer("Dan", 6006)
	__fire(style, "OnServerEvent", dan, { Text = "stand yok", Color = 1 })
	check(dan:GetAttribute("BoothMessage") == nil, "standi olmayan oyuncu ayar yapamaz")
	__fire(style, "OnServerEvent", bob, { Text = "Bob mesaji", Color = 2 })
	check(bob:GetAttribute("BoothMessage") == "Bob mesaji" and alice:GetAttribute("BoothMessage") == "Kalici mesaj", "her sahip kendi standinin ayarini yapar")
	leave(dan)

	print("== MarketplaceHook: bagis akisi ==")
	local donor = newPlayer("Carol", 3003)
	local ch = Instance.new("Model")
	ch.Name = "CarolChar"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = b2.PrimaryPart.CFrame + Vector3.new(0, 0, -4)
	root.Parent = ch
	ch.Parent = workspace
	donor.Character = ch

	__fire(b2.PrimaryPart.DonatePrompt, "Triggered", donor)
	local menus = firedOf(Remotes.OpenDonateMenu)
	local menu = menus[#menus]
	check(menu ~= nil and menu[1] == donor, "bagis menusu donor'a gonderildi")
	check(menu[2].Owner == "Alice" and #menu[2].Passes == 4, "menu: sahip Alice, 4 urun")
	check(menu[2].Passes[2].Price == 100 and menu[2].Passes[2].Id == 222, "fiyat Roblox'tan okundu (100 R$)")

	__fire(b2.PrimaryPart.DonatePrompt, "Triggered", alice)
	local n = firedOf(Remotes.Notify)
	check(n[#n][2]:find("kendi yumurtan") ~= nil, "sahip kendi yumurtasina bagis yapamaz")

	__fire(Remotes.RequestPurchase, "OnServerEvent", donor, 999)
	check(#MS.prompts == 0, "gecersiz urun ID'si reddedildi")
	__fire(Remotes.RequestPurchase, "OnServerEvent", donor, "222")
	check(#MS.prompts == 0, "sayi olmayan urun ID'si reddedildi")
	__fire(Remotes.RequestPurchase, "OnServerEvent", donor, 222)
	check(#MS.prompts == 1 and MS.prompts[1].id == 222 and MS.prompts[1].player == donor, "satin alma penceresi sunucudan acildi")

	local levelBefore, raisedBefore = alice.leaderstats.Level.Value, alice.leaderstats.Raised.Value
	local d1 = MS.ProcessReceipt({ PlayerId = 3003, ProductId = 222, PurchaseId = "p1", CurrencySpent = 100 })
	check(d1 == Enum.ProductPurchaseDecision.PurchaseGranted, "makbuz onaylandi")
	check(alice.leaderstats.Raised.Value == raisedBefore + 100, "Raised +100 (ego sayaci)")
	check(donor.leaderstats.Donated.Value == 100, "bagiscinin Donated'i +100")
	check(alice.leaderstats.Level.Value > levelBefore, "2000 XP: yumurta evrildi (seviye " .. levelBefore .. " -> " .. alice.leaderstats.Level.Value .. ")")
	local feed = firedOf(Remotes.EggFeedback)
	local sawDonation = false
	for _, f in ipairs(feed) do
		if f[1].Kind == "Donation" and f[1].Donor == "Carol" and f[1].XP == 2000 then
			sawDonation = true
		end
	end
	check(sawDonation, "bagis duyurusu gonderildi (Carol, +2000 XP)")

	local raisedNow = alice.leaderstats.Raised.Value
	local d2 = MS.ProcessReceipt({ PlayerId = 3003, ProductId = 222, PurchaseId = "p1", CurrencySpent = 100 })
	check(d2 == Enum.ProductPurchaseDecision.PurchaseGranted and alice.leaderstats.Raised.Value == raisedNow, "ayni makbuz ikinci kez ISLENMEDI (cift odeme yok)")
	check(donor.leaderstats.Donated.Value == 100, "ayni makbuz Donated'i ikinci kez artirmadi")

	local d3 = MS.ProcessReceipt({ PlayerId = 3003, ProductId = 222, PurchaseId = "p2", CurrencySpent = 100 })
	check(d3 == Enum.ProductPurchaseDecision.PurchaseGranted and alice.leaderstats.Raised.Value == raisedNow, "bekleyen kaydi olmayan makbuz: onaylandi, XP verilmedi")

	local rs = __store("EggReceipts_v1")
	rs.fail = true
	local d4 = MS.ProcessReceipt({ PlayerId = 3003, ProductId = 222, PurchaseId = "p3", CurrencySpent = 100 })
	check(d4 == Enum.ProductPurchaseDecision.NotProcessedYet, "makbuz DataStore'u coktu: NotProcessedYet (Roblox tekrar dener)")
	rs.fail = false

	print("== Uc durumlar ==")
	__fire(Remotes.RequestPurchase, "OnServerEvent", donor, 333)
	check(#MS.prompts == 1, "spam korumasi: 2 sn dolmadan ikinci istek yok sayildi")
	__advance(Config.PURCHASE_COOLDOWN + 0.5)
	__fire(Remotes.RequestPurchase, "OnServerEvent", donor, 333)
	check(#MS.prompts == 2, "bekleme bitince ikinci satin alma serbest")
	__advance(3)
	__fire(Remotes.RequestPurchase, "OnServerEvent", donor, 333)
	check(#MS.prompts == 3, "3. satin alma baslatildi (sahip cikmadan hemen once)")
	local raisedBeforeLeave = alice.leaderstats.Raised.Value
	leave(alice)
	check(Registry.GetOwner(b2) == nil, "sahip cikinca stand sifirlandi")
	check(b2.Egg.HatcheryGui.Title.Text:find("Unclaimed") ~= nil, "baslik tekrar 'Unclaimed'")
	check(b2:GetAttribute("OwnerUserId") == nil, "OwnerUserId temizlendi")
	local pst = __store(Config.PENDING_STORE)
	local rs2 = __store("EggReceipts_v1")
	pst.fail = true
	local dFail = MS.ProcessReceipt({ PlayerId = 3003, ProductId = 333, PurchaseId = "p4", CurrencySpent = 500 })
	check(dFail == Enum.ProductPurchaseDecision.NotProcessedYet and rs2.data["p4"] == nil, "sahip cikmis + biriktirme coktu: NotProcessedYet ve makbuz kaydi geri alindi")
	check(donor.leaderstats.Donated.Value == 100, "basarisiz denemede bagiscinin Donated'i artmadi")
	pst.fail = false
	local d5 = MS.ProcessReceipt({ PlayerId = 3003, ProductId = 333, PurchaseId = "p4", CurrencySpent = 500 })
	check(d5 == Enum.ProductPurchaseDecision.PurchaseGranted, "sahibi cikmis standa bagis: cokmedi, makbuz onaylandi")
	check(donor.leaderstats.Donated.Value == 600, "sahibi cikmis olsa da bagiscinin Donated'i artti (100+500)")
	local saved = st.data["Player_1001"]
	check(saved ~= nil and saved.Raised == raisedBeforeLeave and saved.Level == alice.leaderstats.Level.Value, "ayrilan oyuncunun verisi kaydedildi (Raised=" .. tostring(saved and saved.Raised) .. ")")

	local pend = pst.data["1001"]
	check(pend ~= nil and pend.XP == 10000 and pend.Raised == 500, "sahibi cikmis bagis kaybolmadi: bekleyen XP=10000, Raised=500")
	-- sahip geri gelir: bekleyen bagis uygulanir, bir kere
	local alice2 = newPlayer("Alice", 1001)
	check(alice2.leaderstats.Raised.Value == saved.Raised + 500, "geri donen sahibe bekleyen Raised eklendi (" .. alice2.leaderstats.Raised.Value .. ")")
	check(alice2.leaderstats.Level.Value > saved.Level, "bekleyen XP ile yumurta evrildi: Level " .. saved.Level .. " -> " .. alice2.leaderstats.Level.Value)
	check(pst.data["1001"].XP == 0 and pst.data["1001"].Raised == 0, "bekleyen kayit sifirlandi")
	leave(alice2)
	local alice3 = newPlayer("Alice", 1001)
	check(alice3.leaderstats.Raised.Value == alice2.leaderstats.Raised.Value, "ikinci girista bagis tekrar EKLENMEDI")
	check(alice3:GetAttribute("BoothMessage") == "Kalici mesaj" and alice3:GetAttribute("BoothColor") == 4, "stand mesaji ve rengi kayitla geri geldi")
	leave(alice3)

	-- veri yuklenemezse kayit KAPALI olmali (eski veri silinmesin)
	st.fail = true
	local savesBefore = st.saves
	local dave = newPlayer("Dave", 4004)
	__advance(10) -- 3 yeniden deneme de basarisiz olsun (1.5 + 3 sn bekleme)
	check(dave:GetAttribute("DataLoaded") == nil, "3 denemede de yukleme basarisiz: DataLoaded ayarlanmadi")
	st.fail = false
	leave(dave)
	check(st.saves == savesBefore, "yuklenemeyen oyuncu icin kayit YAPILMADI")

	-- sahibi sessizce giderse periyodik kontrol standi bosaltir
	bob.Parent = nil
	__advance(6)
	check(Registry.GetOwner(b3) == nil, "periyodik kontrol: sahibi giden stand bosaltildi")

	-- otomatik kayit
	local erin = newPlayer("Erin", 5005)
	__advance(125)
	erin.leaderstats.Donated.Value = 42
	__advance(125)
	check(st.data["Player_5005"] ~= nil and st.data["Player_5005"].Donated == 42, "otomatik kayit (120 sn) calisti: Donated=" .. tostring(st.data["Player_5005"] and st.data["Player_5005"].Donated))

	-- sunucu kapanisi
	erin.leaderstats.Raised.Value = 777
	__advance(7)
	for _, fn in ipairs(__closeFns) do
		fn()
	end
	check(st.data["Player_5005"].Raised == 777, "BindToClose: acik oyuncular kaydedildi")

	print("== Liderlik panolari ==")
	local lb = __store("EggLB_Raised_v1")
	check(lb.data["5005"] == 777 and lb.data["1001"] ~= nil, "Raised siralamasi OrderedDataStore'a yazildi (Erin=777)")
	check(__store("EggLB_Level_v1").data["5005"] ~= nil and __store("EggLB_Donated_v1").data["5005"] ~= nil, "Donated ve Level siralamalari da yazildi")
	local b1 = Instance.new("Part") b1.Name = "Board_Raised" b1.Parent = workspace
	local b2 = Instance.new("Part") b2.Name = "Wall" b2.Parent = workspace
	local b3 = Instance.new("Part") b3.Name = "Whatever" b3.Parent = workspace
	game:GetService("CollectionService"):AddTag(b3, "LeaderboardBoard")
	b3:SetAttribute("Stat", "Level")
	runScript("LeaderboardService")
	local body = b1.LB.Frame.Body.Text
	local lines = {}
	for l in body:gmatch("[^\n]+") do table.insert(lines, l) end
	check(lines[1]:find("User5005") ~= nil and lines[1]:find("777") ~= nil, "1. sirada en cok toplayan: " .. lines[1])
	check(#lines >= 2 and lines[2]:find("User1001") ~= nil, "2. sirada Alice: " .. (lines[2] or "yok"))
	check(b2:FindFirstChild("LB") == nil, "pano olmayan Part'a dokunulmadi")
	check(b3.LB.Frame.Title.Text == Config.LEADERBOARDS.Level.Title and b3.LB.Frame.Body.Text ~= "Yukleniyor...", "etiketli (Stat=Level) pano da dolduruldu")
	lb.fail = true
	__advance(Config.LEADERBOARD_REFRESH + 1)
	check(b1.LB.Frame.Body.Text == body, "okuma hatasinda pano eski yaziyi korudu")
	lb.fail = false
end
