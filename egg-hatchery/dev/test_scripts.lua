-- dev/test_scripts.lua : EconomyManager + BoothManager + MarketplaceHook + LeaderboardService birlikte (sanal zamanla)
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
	local Hatchery = require(__SSS.Modules.HatcheryService)
	local T = Config.TEXT

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
	local function placeChar(player, booth, dist)
		if player.Character then
			player.Character:Destroy()
		end
		local c = Instance.new("Model")
		c.Name = player.Name .. "Char"
		local r = Instance.new("Part")
		r.Name = "HumanoidRootPart"
		r.Size = Vector3.new(2, 2, 1)
		r.CFrame = booth.PrimaryPart.CFrame + Vector3.new(0, 0, -(dist or 3))
		r.Parent = c
		c.Parent = workspace
		player.Character = c
	end
	local function press(player, booth)
		__fire(booth.PrimaryPart.BoothPrompt, "Triggered", player)
	end
	local function act(player, data)
		__fire(Remotes.PanelAction, "OnServerEvent", player, data)
	end
	local function lastPanel(player)
		local last
		for _, f in ipairs(firedOf(Remotes.OpenPanel)) do
			if f[1] == player then
				last = f[2]
			end
		end
		return last
	end
	local function lastNotify(player)
		local last
		for _, f in ipairs(firedOf(Remotes.Notify)) do
			if f[1] == player then
				last = f[2]
			end
		end
		return last
	end
	local function feedbackFor(player, kind)
		local out = {}
		for _, f in ipairs(firedOf(Remotes.EggFeedback)) do
			if f[1] == player and f[2] and f[2].Kind == kind then
				table.insert(out, f[2])
			end
		end
		return out
	end

	print("== Kurulum ==")
	local ids = { 111, 222, 333, 444 }
	local prices = { 25, 100, 500, 1000 }
	for i = 1, 4 do
		Config.PRODUCTS[i].Id = ids[i]
		__setProductPrice(ids[i], prices[i])
	end
	local st = __store(Config.DATASTORE_NAME)
	st.data["Player_1001"] = { EggLevel = 3, EggXP = 12, Raised = 7, BoothStyle = "rug", BoothColor = 2 } -- eski kayit bicimi (EggLevel) yeni Level'e tasinmali
	runScript("EconomyManager")
	runScript("BoothManager")
	runScript("MarketplaceHook")

	print("== EconomyManager: yukleme ==")
	local alice = newPlayer("Alice", 1001)
	check(alice:GetAttribute("DataLoaded") == true, "kayitli veri yuklendi, DataLoaded=true")
	check(alice.leaderstats.Level.Value == 3 and alice.leaderstats.Donated.Value == 0, "eski EggLevel=3 -> Level=3, Donated=0")
	check(alice.leaderstats.Raised.Value == 7 and alice.EggData.EggXP.Value == 12, "Raised=7, EggXP=12")
	check(alice:GetAttribute("BoothStyle") == "rug" and alice:GetAttribute("BoothColor") == 2, "kayitli stand stili ve rengi yuklendi")
	local order = {}
	for _, c in ipairs(alice.leaderstats:GetChildren()) do
		table.insert(order, c.Name)
	end
	check(table.concat(order, ",") == "Raised,Donated,Level", "liderlik tablosu sirasi: " .. table.concat(order, ","))
	__advance(Config.PLAY_INTERVAL - 1)
	check(alice.EggData.EggXP.Value == 12, "aralik dolmadan XP gelmez")
	__advance(Config.PLAY_INTERVAL * 4)
	check(alice.EggData.EggXP.Value == 12 + Config.PLAY_XP * 4, "oynama suresi XP'si otomatik gelir (AFK dahil): " .. alice.EggData.EggXP.Value)

	print("== BoothManager: sahiplenme ve panel ==")
	local b2, b3, b4 = workspace.Booths.Booth_2, workspace.Booths.Booth_3, workspace.Booths.Booth_4
	press(alice, b2)
	check(Registry.GetOwner(b2) == alice, "bos standa E: Alice Booth_2'yi sahiplendi")
	check(b2:GetAttribute("OwnerUserId") == 1001 and alice:GetAttribute("HasBooth") == true, "OwnerUserId ve HasBooth attribute'lari")
	local card = b2.Egg.HatcheryGui.Card
	check(card.NameLabel.Text == "Alice" and card.LevelLabel.Text == "Seviye 3  •  Yaygın", "kart: " .. card.NameLabel.Text .. " / " .. card.LevelLabel.Text)
	check(lastNotify(alice) == T.Claimed, "sahiplenme bildirimi: " .. tostring(lastNotify(alice)))
	check(b2:FindFirstChild("StyleDecor") ~= nil and b2.StyleDecor:FindFirstChild("Rug") ~= nil, "kayitli 'Halı' stili standda gorunur")
	check(b2.PrimaryPart.BoothPrompt.ActionText == T.PromptView, "dolu standda buton 'Standa Bak'")

	local bob = newPlayer("Bob", 2002)
	placeChar(bob, b2)
	press(bob, b2)
	check(Registry.GetOwner(b2) == alice, "dolu standa E sahiplenmez, panel acar")
	local pb = lastPanel(bob)
	check(pb ~= nil and pb.IsOwner == false and pb.OwnerName == "Alice" and pb.Level == 3, "Bob'a Alice'in paneli gitti (sahip degil, Seviye 3)")
	check(#pb.Products == 4 and pb.Products[2].Price == 100 and pb.Products[2].Id == 222, "panel: 4 bagis urunu, fiyat Roblox'tan okundu")
	check(Registry.GetViewing(bob) == b2, "Bob'un baktigi stand kaydedildi")
	placeChar(alice, b2)
	press(alice, b2)
	local pa = lastPanel(alice)
	check(pa.IsOwner == true and #pa.Products == 0 and pa.FeedXP == nil and pa.FeedWait == nil, "sahibin paneli: kendi stand, urun listesi yok, besleme alani yok")
	check(pa.Style == "rug" and pa.Color == 2, "panel mevcut stili ve rengi gosterir")

	press(bob, b3)
	check(Registry.GetOwner(b3) == bob, "Bob Booth_3'u sahiplendi")
	press(bob, b4)
	check(Registry.GetOwner(b4) == nil and lastNotify(bob) == T.AlreadyHave, "ayni oyuncu ikinci stand alamaz: " .. tostring(lastNotify(bob)))

	print("== Besleme kaldirildi: sunucu eski Feed istegini yok sayar ==")
	placeChar(alice, b2)
	press(alice, b2)
	local xp0 = alice.EggData.EggXP.Value
	act(alice, { Action = "Feed" })
	check(alice.EggData.EggXP.Value == xp0, "Feed istegi XP vermez")
	local eve = newPlayer("Eve", 7007)
	act(eve, { Action = "Feed" })
	check(Registry.GetViewing(eve) == nil and eve.EggData.EggXP.Value == 0, "paneli acmadan Feed istegi yok sayildi")
	placeChar(alice, b2, 80)
	act(alice, { Action = "Close" })
	placeChar(alice, b2)
	press(alice, b2)
	act(alice, { Action = "Close" })
	check(Registry.GetViewing(alice) == nil, "Close eylemi paneli kapatir")
	local axp = alice.EggData.EggXP.Value
	press(bob, b2)
	act(bob, { Action = "Feed" })
	check(alice.EggData.EggXP.Value == axp, "baskasi Feed gonderse bile sahibe XP gitmez")
	placeChar(eve, b2)
	press(eve, b2)

	print("== Stand stilleri (seviye ile acilir) ==")
	local lvl = alice.leaderstats.Level.Value
	placeChar(alice, b2)
	press(alice, b2)
	__advance(3)
	act(alice, { Action = "Style", Style = "lantern", Color = 1, Text = "x" })
	check(alice:GetAttribute("BoothStyle") == "rug" and lastNotify(alice) == string.format(T.StyleLocked, "Fenerli", 5), "Seviye 5'te acilan stil Seviye " .. lvl .. "'te reddedildi: " .. tostring(lastNotify(alice)))
	__advance(3)
	act(alice, { Action = "Style", Style = "flags", Color = 5, Text = "  Pet için   biriktiriyorum  " })
	check(alice:GetAttribute("BoothStyle") == "flags" and alice:GetAttribute("BoothColor") == 5, "acik stil (Bayraklı, Sv.3) ve renk kaydedildi")
	check(alice:GetAttribute("BoothMessage") == "Pet için biriktiriyorum", "mesaj kirpildi, bosluklar toplandi: " .. tostring(alice:GetAttribute("BoothMessage")))
	check(b2:FindFirstChild("StyleDecor") ~= nil and b2.StyleDecor:FindFirstChild("Flag") ~= nil and b2.StyleDecor:FindFirstChild("Rug") == nil, "stand gorunumu halidan bayraga degisti")
	check(b2.Egg.HatcheryGui.Card.MessageLabel.Text == "Pet için biriktiriyorum" and lastNotify(alice) == T.StyleSaved, "kartta mesaj, bildirim: kaydedildi")
	check(lastPanel(alice).Style == "flags" and lastPanel(alice).Message == "Pet için biriktiriyorum", "panel yeni stille tazelendi")
	act(bob, { Action = "Style", Style = "flags", Color = 1, Text = "ele gecirme" })
	check(alice:GetAttribute("BoothMessage") == "Pet için biriktiriyorum" and bob:GetAttribute("BoothMessage") == nil, "sahip olmayan baskasinin standini ozellestiremez")
	act(alice, { Action = "Style", Style = "flags", Color = 1, Text = "hizli" })
	check(alice:GetAttribute("BoothColor") == 5, "ayar spam'i (2 sn bekleme) yok sayildi")
	__advance(3)
	act(alice, { Action = "Style", Style = "flags", Color = 1, Text = "BadWord burada" })
	check(alice:GetAttribute("BoothMessage") == "####### burada", "Roblox filtresinden gecen yazi saklandi: " .. tostring(alice:GetAttribute("BoothMessage")))
	__advance(3)
	act(alice, { Action = "Style", Style = "flags", Color = 1, Text = string.rep("a", Config.STYLE_MAX_LENGTH + 1) })
	check(alice:GetAttribute("BoothMessage") == "####### burada", "cok uzun mesaj reddedildi")
	__advance(3)
	act(alice, { Action = "Style", Style = "flags", Color = 99, Text = "ok" })
	__advance(3)
	act(alice, { Action = "Style", Style = "yok-boyle-stil", Color = 1, Text = "ok" })
	check(alice:GetAttribute("BoothMessage") == "####### burada", "gecersiz renk / bilinmeyen stil reddedildi")
	__advance(3)
	act(alice, { Action = "Style", Style = "flags", Color = 1, Text = 123 })
	act(alice, "hile")
	act(alice, { Action = 5 })
	act(alice, { Action = "Style", Style = "flags" })
	check(alice:GetAttribute("BoothMessage") == "####### burada", "yanlis turdeki veriler (sayi/string/eksik) reddedildi")
	__textFilterFail = true
	__advance(3)
	act(alice, { Action = "Style", Style = "flags", Color = 1, Text = "yeni" })
	check(alice:GetAttribute("BoothMessage") == "####### burada" and lastNotify(alice) == T.StyleFilterFail, "filtre hata verirse mesaj KAYDEDILMEZ")
	__textFilterFail = false
	__advance(3)
	act(alice, { Action = "Style", Style = "flags", Color = 6, Text = "satir\nsonu\tsekme" })
	check(alice:GetAttribute("BoothMessage") == "satir sonu sekme", "satir sonu/tab bosluga cevrildi")
	__advance(3)
	act(alice, { Action = "Style", Style = "flags", Color = 2, Text = "" })
	check(alice:GetAttribute("BoothMessage") == "" and b2.Egg.HatcheryGui.Card.MessageLabel.Visible == false, "bos mesaj: yazi gizlenir")

	-- seviye atlayinca yeni stil acilir
	local before = #feedbackFor(alice, "Unlock")
	Hatchery.AddXP(alice, 600) -- Seviye 5'i gecer
	check(alice.leaderstats.Level.Value >= 5, "600 XP sonrasi Seviye " .. alice.leaderstats.Level.Value)
	local unlocks = feedbackFor(alice, "Unlock")
	check(#unlocks == before + 1 and table.concat(unlocks[#unlocks].Styles, ",") == "Fenerli", "'Fenerli' acildi bildirimi sahibe gitti")
	__advance(3)
	act(alice, { Action = "Style", Style = "lantern", Color = 3, Text = "Fenerim yandi" })
	check(alice:GetAttribute("BoothStyle") == "lantern", "yeni acilan stil secilebildi")
	local lights = 0
	for _, d in ipairs(b2.StyleDecor:GetDescendants()) do
		if d.ClassName == "PointLight" then
			lights = lights + 1
		end
	end
	check(lights == 2, "fenerli stil standa 2 gercek isik ekledi")

	print("== MarketplaceHook: bagis akisi ==")
	local donor = newPlayer("Carol", 3003)
	placeChar(donor, b2, 4)
	check(Registry.GetViewing(donor) == nil, "donor paneli acmadan satin alma baslatamaz")
	__fire(Remotes.RequestPurchase, "OnServerEvent", donor, 222)
	check(#MS.prompts == 0, "paneli acmadan RequestPurchase yok sayildi")
	press(donor, b2)
	check(lastPanel(donor).IsOwner == false and #lastPanel(donor).Products == 4, "donor paneli acti: 4 urun")
	__fire(Remotes.RequestPurchase, "OnServerEvent", alice, 222)
	check(#MS.prompts == 0, "sahip kendi yumurtasina bagis yapamaz (kendi stand)")
	__fire(Remotes.RequestPurchase, "OnServerEvent", donor, 999)
	check(#MS.prompts == 0, "gecersiz urun ID'si reddedildi")
	__fire(Remotes.RequestPurchase, "OnServerEvent", donor, "222")
	check(#MS.prompts == 0, "sayi olmayan urun ID'si reddedildi")
	__fire(Remotes.RequestPurchase, "OnServerEvent", donor, 222)
	check(#MS.prompts == 1 and MS.prompts[1].id == 222 and MS.prompts[1].player == donor, "satin alma penceresi sunucudan acildi")

	local levelBefore, raisedBefore = alice.leaderstats.Level.Value, alice.leaderstats.Raised.Value
	local d1 = MS.ProcessReceipt({ PlayerId = 3003, ProductId = 222, PurchaseId = "p1", CurrencySpent = 100 })
	check(d1 == Enum.ProductPurchaseDecision.PurchaseGranted, "makbuz onaylandi")
	check(alice.leaderstats.Raised.Value == raisedBefore + 100 and donor.leaderstats.Donated.Value == 100, "Raised +100 (sahip), Donated +100 (bagisci)")
	check(alice.leaderstats.Level.Value > levelBefore, "2000 XP: yumurta evrildi (seviye " .. levelBefore .. " -> " .. alice.leaderstats.Level.Value .. ")")
	local sawDonation = false
	for _, f in ipairs(firedOf(Remotes.EggFeedback)) do
		local data = f[2] or f[1]
		if type(data) == "table" and data.Kind == "Donation" and data.Donor == "Carol" and data.XP == 2000 then
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
	local raisedBeforeLeave = alice.leaderstats.Raised.Value
	leave(alice)
	check(Registry.GetOwner(b2) == nil and b2.Egg.HatcheryGui.Card.NameLabel.Text == T.Unclaimed, "sahip cikinca stand sifirlandi, kart 'Boş Stand'")
	check(b2:FindFirstChild("StyleDecor") == nil and b2:GetAttribute("OwnerUserId") == nil, "stil susleri ve OwnerUserId temizlendi")
	local pst = __store(Config.PENDING_STORE)
	local rs2 = __store("EggReceipts_v1")
	pst.fail = true
	local dFail = MS.ProcessReceipt({ PlayerId = 3003, ProductId = 333, PurchaseId = "p4", CurrencySpent = 500 })
	check(dFail == Enum.ProductPurchaseDecision.NotProcessedYet and rs2.data["p4"] == nil, "sahip cikmis + biriktirme coktu: NotProcessedYet ve makbuz kaydi geri alindi")
	check(donor.leaderstats.Donated.Value == 100, "basarisiz denemede bagiscinin Donated'i artmadi")
	pst.fail = false
	local d5 = MS.ProcessReceipt({ PlayerId = 3003, ProductId = 333, PurchaseId = "p4", CurrencySpent = 500 })
	check(d5 == Enum.ProductPurchaseDecision.PurchaseGranted, "sahibi cikmis standa bagis: cokmedi, makbuz onaylandi (tekrar deneme kaydi korundu)")
	check(donor.leaderstats.Donated.Value == 600, "sahibi cikmis olsa da bagiscinin Donated'i artti (100+500)")
	local saved = st.data["Player_1001"]
	check(saved ~= nil and saved.Raised == raisedBeforeLeave and saved.Level == alice.leaderstats.Level.Value and saved.BoothStyle == "lantern", "ayrilan oyuncunun verisi (stil dahil) kaydedildi")
	local pend = pst.data["1001"]
	check(pend ~= nil and pend.XP == 10000 and pend.Raised == 500, "sahibi cikmis bagis kaybolmadi: bekleyen XP=10000, Raised=500")
	local alice2 = newPlayer("Alice", 1001)
	check(alice2.leaderstats.Raised.Value == saved.Raised + 500, "geri donen sahibe bekleyen Raised eklendi (" .. alice2.leaderstats.Raised.Value .. ")")
	check(alice2.leaderstats.Level.Value > saved.Level, "bekleyen XP ile yumurta evrildi: Level " .. saved.Level .. " -> " .. alice2.leaderstats.Level.Value)
	check(pst.data["1001"].XP == 0 and pst.data["1001"].Raised == 0, "bekleyen kayit sifirlandi")
	leave(alice2)
	local alice3 = newPlayer("Alice", 1001)
	check(alice3.leaderstats.Raised.Value == alice2.leaderstats.Raised.Value, "ikinci girista bagis tekrar EKLENMEDI")
	check(alice3:GetAttribute("BoothStyle") == "lantern" and alice3:GetAttribute("BoothColor") == 3 and alice3:GetAttribute("BoothMessage") == "Fenerim yandi", "stand stili, rengi ve mesaji kayitla geri geldi")
	leave(alice3)

	st.fail = true
	local savesBefore = st.saves
	local dave = newPlayer("Dave", 4004)
	__advance(10)
	check(dave:GetAttribute("DataLoaded") == nil, "3 denemede de yukleme basarisiz: DataLoaded ayarlanmadi")
	press(dave, b4)
	check(Registry.GetOwner(b4) == nil and lastNotify(dave) == T.Loading, "veri yuklenmemis oyuncu stand alamaz: " .. tostring(lastNotify(dave)))
	st.fail = false
	leave(dave)
	check(st.saves == savesBefore, "yuklenemeyen oyuncu icin kayit YAPILMADI")

	bob.Parent = nil
	__advance(6)
	check(Registry.GetOwner(b3) == nil, "periyodik kontrol: sahibi giden stand bosaltildi")

	local erin = newPlayer("Erin", 5005)
	__advance(125)
	erin.leaderstats.Donated.Value = 42
	__advance(125)
	check(st.data["Player_5005"] ~= nil and st.data["Player_5005"].Donated == 42, "otomatik kayit (120 sn) calisti: Donated=" .. tostring(st.data["Player_5005"] and st.data["Player_5005"].Donated))
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
	local p1 = Instance.new("Part") p1.Name = "Board_Raised" p1.Parent = workspace
	local p2 = Instance.new("Part") p2.Name = "Wall" p2.Parent = workspace
	local p3 = Instance.new("Part") p3.Name = "Whatever" p3.Parent = workspace
	game:GetService("CollectionService"):AddTag(p3, "LeaderboardBoard")
	p3:SetAttribute("Stat", "Level")
	runScript("LeaderboardService")
	local body = p1.LB.Frame.Body.Text
	local lines = {}
	for l in body:gmatch("[^\n]+") do table.insert(lines, l) end
	check(lines[1]:find("User5005") ~= nil and lines[1]:find("777") ~= nil, "1. sirada en cok toplayan: " .. lines[1])
	check(#lines >= 2 and lines[2]:find("User1001") ~= nil, "2. sirada Alice: " .. (lines[2] or "yok"))
	check(p2:FindFirstChild("LB") == nil, "pano olmayan Part'a dokunulmadi")
	check(p3.LB.Frame.Title.Text == Config.LEADERBOARDS.Level.Title and p3.LB.Frame.Body.Text ~= "Yukleniyor...", "etiketli (Stat=Level) pano da dolduruldu")
	lb.fail = true
	__advance(Config.LEADERBOARD_REFRESH + 1)
	check(p1.LB.Frame.Body.Text == body, "okuma hatasinda pano eski yaziyi korudu")
	lb.fail = false
end
