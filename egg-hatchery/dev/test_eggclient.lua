	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== EggClient (istemci arayuzu) ==")
	local Config = require(__SSS.Modules.Config)
	local remotes = game:GetService("ReplicatedStorage").EggRemotes
	local gui = __pg:FindFirstChild("EggGui")
	check(gui ~= nil, "EggGui olustu")
	local function walk(root, fn)
		for _, c in ipairs(root:GetDescendants()) do
			if fn(c) then
				return c
			end
		end
	end
	local function byName(root, name)
		return walk(root, function(c) return c.Name == name end)
	end
	local function sent(remote)
		return rawget(remote, "_d").firedServer or {}
	end

	-- HUD
	local hud = gui.Hud
	check(hud.Visible == true and hud.Title.Text == "Yumurtanı bekliyor" and hud.Sub.Text == Config.TEXT.Tip, "stand yokken HUD ipucu gosterir: " .. hud.Sub.Text)
	__lp:SetAttribute("HasBooth", true)
	__lp.leaderstats.Level.Value = 3
	__lp.EggData.EggXP.Value = 60
	check(hud.Title.Text == "Seviye 3  •  Yaygın", "HUD seviye ve nadirlik: " .. hud.Title.Text)
	check(math.abs(hud.BarBack.Fill.Size.XS - 60 / Config.XPRequired(3)) < 1e-9, string.format("XP cubugu dolulugu %.3f", hud.BarBack.Fill.Size.XS))
	check(hud.Sub.Text:find("60 / 207 XP") ~= nil and hud.Sub.Text:find("Sonraki stil: Fenerli %(Sv. 5%)") ~= nil, "HUD: XP sayisi ve sonraki stil: " .. hud.Sub.Text)
	__lp.leaderstats.Level.Value = 50
	check(hud.Title.Text:find("Mitik") ~= nil and hud.Sub.Text:find("Sonraki") == nil, "Seviye 50: Mitik, sonraki stil yok")
	__lp.leaderstats.Level.Value = 3

	-- bildirim ve stil acilimi
	__fire(remotes.Notify, "OnClientEvent", "Merhaba bildirim")
	local toast = byName(gui.Toasts, "Toast")
	check(toast ~= nil and toast.Text.Text == "Merhaba bildirim", "bildirim kartinda yazi: " .. tostring(toast and toast.Text.Text))
	__fire(remotes.EggFeedback, "OnClientEvent", { Kind = "Unlock", Styles = { "Fenerli", "Çiçekli" }, Level = 7 })
	local banner = gui:FindFirstChild("UnlockBanner")
	check(banner ~= nil, "stil acilimi kutlama kutusu acildi")
	local bannerText = {}
	for _, c in ipairs(banner:GetChildren()) do
		if c.ClassName == "TextLabel" then
			table.insert(bannerText, c.Text)
		end
	end
	check(table.concat(bannerText, "|"):find("YENİ STİL AÇILDI!") ~= nil and table.concat(bannerText, "|"):find("Fenerli  •  Çiçekli") ~= nil, "kutlama yazisi acilan stilleri listeler")

	-- Panel: sahibi
	local booth = workspace.Booths.Booth_5
	local payload = {
		Booth = booth, OwnerName = "LocalGuy", OwnerId = 9, IsOwner = true, Level = 3, XP = 60, Need = 207, Rarity = "Yaygın",
		RarityColor = Config.RARITIES[1].Color, Message = "Merhaba", Style = "rug", Color = 2,
		Products = {}, XPPerRobux = 20,
	}
	__fire(remotes.OpenPanel, "OnClientEvent", payload)
	local panel = gui:FindFirstChild("BoothPanel")
	check(panel ~= nil and panel.Head.BarBack.Fill ~= nil, "panel acildi")
	check(byName(panel, "FeedButton") == nil, "panelde besle dugmesi yok")
	check(byName(gui.Hud, "Info").Text == "Her 15 sn: +1 XP   •   1 Robux destek: +20 XP", "HUD: otomatik XP bilgisi: " .. byName(gui.Hud, "Info").Text)
	local cards = 0
	for _, s in ipairs(Config.STYLES) do
		if byName(panel, "Style_" .. s.Id) then
			cards = cards + 1
		end
	end
	check(cards == 7, "7 stil karti (sunucu ayarindan)")
	local lantern, rug, flags = byName(panel, "Style_lantern"), byName(panel, "Style_rug"), byName(panel, "Style_flags")
	check(lantern.Sub.Text == "Seviye 5'de açılır" and rug.Sub.Text ~= "Seviye 2'de açılır", "kilitli stil 'Seviye 5'de açılır' der, acik olan aciklama gosterir")
	check(rug.UIStroke.Color ~= lantern.UIStroke.Color, "secili stil (halı) yesil cerceveli")
	check(panel.Content.Message.Text == "“Merhaba”" and byName(panel, "MessageBox").Text == "Merhaba", "mevcut mesaj panelde ve kutuda")
	check(byName(panel, "StyleGrid").Parent.Visible == true and byName(panel, "SaveButton") ~= nil, "sahibe stil bolumu gorunur")
	check(byName(panel, "DESTEK OL").Visible == false, "sahibine 'destek ol' bolumu gizli")

	-- kilitli stile tikla -> bildirim, secim degismez
	__fire(lantern, "Activated")
	local lastToast
	for _, c in ipairs(gui.Toasts:GetChildren()) do
		if c.Name == "Toast" then
			lastToast = c.Text.Text
		end
	end
	check(lastToast == "Fenerli stili Seviye 5'de açılır.", "kilitli stile tiklayinca uyari: " .. tostring(lastToast))
	-- acik stil + renk sec, mesaj yaz, kaydet
	__fire(flags, "Activated")
	__fire(byName(panel, "Color_6"), "Activated")
	byName(panel, "MessageBox").Text = string.rep("b", 60)
	__fire(byName(panel, "SaveButton"), "Activated")
	local pa = sent(remotes.PanelAction)
	local style = pa[#pa][1]
	check(style.Action == "Style" and style.Style == "flags" and style.Color == 6 and #style.Text == 40, "Kaydet: {Style='flags', Color=6, Text 40 karaktere kisaltildi}")
	__fire(remotes.OpenPanel, "OnClientEvent", payload)
	check(gui:FindFirstChild("BoothPanel") == panel, "ayni standa gelen guncelleme paneli yeniden olusturmaz (yazilan mesaj kaybolmaz)")
	-- kapat
	__fire(byName(panel, "CloseButton"), "Activated")
	check(gui:FindFirstChild("BoothPanel") == nil and sent(remotes.PanelAction)[#sent(remotes.PanelAction)][1].Action == "Close", "X: panel kapanir, sunucuya Close gider")

	-- Panel: ziyaretci (destek urunleri)
	local visitor = {
		Booth = booth, OwnerName = "Ayşe", OwnerId = 55, IsOwner = false, Level = 12, XP = 5, Need = 5000, Rarity = "Efsanevi",
		RarityColor = Config.RARITIES[3].Color, Message = "", Style = "gold", Color = 1,
		Products = { { Id = 111, Name = "Atıştırmalık", Price = 25 }, { Id = 222, Name = "Ziyafet", Price = 100 } }, XPPerRobux = 20,
	}
	__fire(remotes.OpenPanel, "OnClientEvent", visitor)
	local vp = gui.BoothPanel
	check(byName(vp, "DESTEK OL").Visible == true and byName(vp, "STAND STİLLERİ").Visible == false, "ziyaretciye destek bolumu gorunur, stil bolumu gizli")
	local pbtn = byName(vp, "Product_222")
	check(pbtn ~= nil and pbtn.Text == "Ziyafet   •   R$ 100   (+2000 XP)", "urun dugmesi: " .. tostring(pbtn and pbtn.Text))
	__fire(pbtn, "Activated")
	local rp = sent(remotes.RequestPurchase)
	check(rp[#rp][1] == 222, "urun dugmesi RequestPurchase(222) yollar")
	check(byName(vp, "FeedButton") == nil, "ziyaretcide de besle dugmesi yok")
	visitor.Products = {}
	__fire(remotes.OpenPanel, "OnClientEvent", visitor)
	check(byName(gui.BoothPanel, "Product_222") == nil and byName(gui.BoothPanel, "Note").Text:find("yakında") ~= nil, "urun yoksa 'yakinda' notu")

	-- standi birakinca HUD ipucuna doner
	__lp:SetAttribute("HasBooth", nil)
	check(hud.Title.Text == "Yumurtanı bekliyor", "stand birakilinca HUD tekrar ipucu gosterir")
