-- StarterGui/EggClient (LocalScript)
-- Oyun arayuzu: bildirimler, alt XP cubugu (HUD), stand paneli (destek ol / stil sec), stil acilim kutlamasi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("EggRemotes")

---------------------------------------------------------------------
-- Sunucunun yayinladigi ayarlar
---------------------------------------------------------------------
local STYLES = HttpService:JSONDecode(remotes:GetAttribute("StylesJSON"))
local COLORS = HttpService:JSONDecode(remotes:GetAttribute("ColorsJSON"))
local RARITIES = HttpService:JSONDecode(remotes:GetAttribute("RaritiesJSON"))
local XP_BASE, XP_EXP = remotes:GetAttribute("XPBase"), remotes:GetAttribute("XPExp")
local MAX_MESSAGE = remotes:GetAttribute("MaxMessage") or 40
local TIP_TEXT = remotes:GetAttribute("TipText") or ""

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end
local function xpNeeded(level)
	return math.floor(XP_BASE * level ^ XP_EXP)
end
local function rarityOf(level)
	local result = RARITIES[1]
	for _, r in ipairs(RARITIES) do
		if level >= r.min then
			result = r
		end
	end
	return result
end
local function nextStyle(level)
	for _, s in ipairs(STYLES) do
		if s.level > level then
			return s
		end
	end
	return nil
end

---------------------------------------------------------------------
-- Tema
---------------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(22, 26, 38),
	panel = Color3.fromRGB(32, 38, 56),
	card = Color3.fromRGB(42, 49, 72),
	cardHover = Color3.fromRGB(54, 62, 90),
	text = Color3.fromRGB(245, 247, 252),
	muted = Color3.fromRGB(160, 169, 190),
	green = Color3.fromRGB(74, 196, 112),
	greenDark = Color3.fromRGB(48, 140, 80),
	gold = Color3.fromRGB(255, 200, 70),
	red = Color3.fromRGB(235, 90, 90),
	line = Color3.fromRGB(70, 80, 112),
}
local F = { title = Enum.Font.GothamBlack, bold = Enum.Font.GothamBold, body = Enum.Font.GothamMedium }

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end
local function corner(inst, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
end
local function stroke(inst, color, thickness)
	return new("UIStroke", { Color = color, Thickness = thickness or 1.5 }, inst)
end
local function label(parent, text, font, size, color, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = font,
		TextSize = size,
		TextColor3 = color,
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

-- Cizilmis ikonlar (resim dosyasi gerekmez)
local function eggIcon(parent, color, w, h, pos)
	local egg = new("Frame", { Size = UDim2.fromOffset(w, h), Position = pos, BackgroundColor3 = color, BorderSizePixel = 0 }, parent)
	corner(egg, math.floor(w / 2))
	new("Frame", {
		Size = UDim2.fromOffset(math.floor(w * 0.22), math.floor(h * 0.26)),
		Position = UDim2.fromOffset(math.floor(w * 0.22), math.floor(h * 0.2)),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
	}, egg)
	return egg
end
local function lockIcon(parent, pos, color)
	local box = new("Frame", { Size = UDim2.fromOffset(18, 20), Position = pos, BackgroundTransparency = 1 }, parent)
	local shackle = new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(4, 0), BackgroundTransparency = 1 }, box)
	corner(shackle, 5)
	stroke(shackle, color, 2)
	local body = new("Frame", { Size = UDim2.fromOffset(18, 12), Position = UDim2.fromOffset(0, 8), BackgroundColor3 = color, BorderSizePixel = 0 }, box)
	corner(body, 3)
	return box
end

-- Stil kartlarindaki kucuk cizimler (her stilin standda gercekte nasil gorundugunu hatirlatir)
local function px(parent, x, y, w, h, color, radius, rotation, transparency)
	local f = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		Rotation = rotation or 0,
	}, parent)
	if radius then
		corner(f, radius)
	end
	return f
end

local ICON_CREAM = Color3.fromRGB(248, 242, 224)
local ICON_WOOD = Color3.fromRGB(150, 108, 70)
local ICON_DARK = Color3.fromRGB(58, 62, 72)
local ICON_RED = Color3.fromRGB(235, 90, 90)
local ICON_WARM = Color3.fromRGB(255, 226, 150)
local ICON_LEAF = Color3.fromRGB(86, 164, 66)

local iconDrawers = {
	classic = function(t)
		px(t, 6, 12, 34, 6, ICON_WOOD, 2)
		px(t, 9, 18, 28, 18, ICON_CREAM, 2)
		px(t, 14, 22, 18, 5, ICON_WOOD, 1)
	end,
	rug = function(t)
		px(t, 4, 13, 38, 22, ICON_CREAM, 2)
		px(t, 7, 16, 32, 16, ICON_RED, 2)
		px(t, 18, 19, 10, 10, ICON_CREAM, 1, 45)
		px(t, 21, 22, 4, 4, ICON_RED, 0, 45)
	end,
	flags = function(t)
		px(t, 6, 8, 3, 32, ICON_WOOD)
		px(t, 37, 8, 3, 32, ICON_WOOD)
		px(t, 8, 12, 30, 2, ICON_DARK)
		for k = 0, 3 do
			px(t, 11 + k * 7, 15 + (k % 2), 6, 6, (k % 2 == 0) and ICON_RED or ICON_CREAM, 0, 45)
		end
	end,
	lantern = function(t)
		px(t, 21, 20, 4, 22, ICON_DARK)
		px(t, 14, 8, 18, 4, ICON_DARK, 2)
		px(t, 17, 12, 12, 12, ICON_WARM, 2)
		px(t, 16, 36, 14, 4, ICON_DARK, 1)
	end,
	garden = function(t)
		px(t, 7, 29, 32, 11, ICON_WOOD, 2)
		px(t, 12, 22, 10, 10, ICON_LEAF, 5)
		px(t, 24, 22, 10, 10, ICON_LEAF, 5)
		px(t, 10, 14, 8, 8, Color3.fromRGB(255, 128, 170), 4)
		px(t, 21, 11, 8, 8, Color3.fromRGB(255, 224, 90), 4)
		px(t, 31, 15, 8, 8, ICON_CREAM, 4)
	end,
	gold = function(t)
		px(t, 7, 12, 7, 28, C.gold, 2)
		px(t, 32, 12, 7, 28, C.gold, 2)
		px(t, 5, 9, 36, 5, C.gold, 2)
		px(t, 4, 38, 11, 4, C.gold, 1)
		px(t, 31, 38, 11, 4, C.gold, 1)
	end,
	legend = function(t)
		px(t, 7, 14, 6, 26, C.gold, 2)
		px(t, 33, 14, 6, 26, C.gold, 2)
		px(t, 5, 12, 36, 4, C.gold, 2)
		px(t, 8, 0, 4, 14, Color3.fromRGB(190, 220, 255), 2, 0, 0.35)
		px(t, 34, 0, 4, 14, Color3.fromRGB(190, 220, 255), 2, 0, 0.35)
		px(t, 15, 17, 6, 14, Color3.fromRGB(255, 130, 200), 1)
		px(t, 25, 17, 6, 14, Color3.fromRGB(255, 130, 200), 1)
	end,
}

local function styleIcon(parent, id)
	local tile = new("Frame", {
		Name = "Icon",
		Position = UDim2.fromOffset(10, 16),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.fromRGB(26, 31, 46),
		BorderSizePixel = 0,
	}, parent)
	corner(tile, 8)
	local draw = iconDrawers[id]
	if draw then
		draw(tile)
	end
	-- kilitliyken soluklastirir
	local dim = new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(26, 31, 46), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, ZIndex = 5 }, tile)
	corner(dim, 8)
	return tile, dim
end

local gui = new("ScreenGui", { Name = "EggGui", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

---------------------------------------------------------------------
-- Bildirimler (ust orta, sirayla)
---------------------------------------------------------------------
local toastBox = new("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.new(1, -24, 0, 220),
	BackgroundTransparency = 1,
}, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(420, 220), MinSize = Vector2.new(240, 0) }, toastBox)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, toastBox)

local toastCount = 0
local function showToast(text, color)
	toastCount += 1
	local t = new("Frame", {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 44),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		LayoutOrder = toastCount,
	}, toastBox)
	corner(t, 12)
	stroke(t, color or C.line, 2)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, t)
	label(t, text, F.bold, 16, C.text, {
		Name = "Text",
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
	})
	task.delay(4, function()
		if t.Parent then
			t:Destroy()
		end
	end)
end
remotes.Notify.OnClientEvent:Connect(function(text)
	showToast(tostring(text))
end)

---------------------------------------------------------------------
-- Stil acilimi kutlamasi
---------------------------------------------------------------------
local banner
local function showUnlock(names, level)
	if banner then
		banner:Destroy()
	end
	banner = new("Frame", {
		Name = "UnlockBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.new(0.92, 0, 0, 96),
		BackgroundColor3 = C.bg,
		BorderSizePixel = 0,
	}, gui)
	new("UISizeConstraint", { MaxSize = Vector2.new(380, 96), MinSize = Vector2.new(240, 96) }, banner)
	corner(banner, 16)
	stroke(banner, C.gold, 3)
	label(banner, "YENİ STİL AÇILDI!", F.title, 22, C.gold, {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	label(banner, table.concat(names, "  •  "), F.bold, 20, C.text, {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	label(banner, "Seviye " .. level .. "  -  Stand Stilleri'nden seç", F.body, 14, C.muted, {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local mine = banner
	task.delay(6, function()
		if banner == mine and mine.Parent then
			mine:Destroy()
			banner = nil
		end
	end)
end

remotes.EggFeedback.OnClientEvent:Connect(function(data)
	if data.Kind == "Unlock" then
		showUnlock(data.Styles, data.Level)
	elseif data.Kind == "Evolve" then
		showToast(string.format("%s oyuncusunun yumurtası Seviye %d oldu  •  %s", data.Owner, data.Level, data.Rarity), data.Color)
	elseif data.Kind == "Donation" then
		showToast(string.format("%s, %s oyuncusunu destekledi! (+%d XP)", data.Donor, data.Owner, data.XP), C.green)
	end
end)

---------------------------------------------------------------------
-- HUD: alt orta XP cubugu (standi olmayana ipucu)
---------------------------------------------------------------------
local hud = new("Frame", {
	Name = "Hud",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.new(1, -24, 0, 92),
	BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
}, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(400, 92), MinSize = Vector2.new(260, 92) }, hud)
corner(hud, 16)
local hudStroke = stroke(hud, C.line, 2)
local hudEgg = eggIcon(hud, C.muted, 30, 38, UDim2.fromOffset(16, 16))
local hudTitle = label(hud, "", F.bold, 17, C.text, { Name = "Title", Position = UDim2.fromOffset(60, 8), Size = UDim2.new(1, -76, 0, 24) })
local hudBarBack = new("Frame", { Name = "BarBack", Position = UDim2.fromOffset(60, 36), Size = UDim2.new(1, -76, 0, 10), BackgroundColor3 = Color3.fromRGB(56, 63, 88), BorderSizePixel = 0 }, hud)
corner(hudBarBack, 5)
local hudFill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green, BorderSizePixel = 0 }, hudBarBack)
corner(hudFill, 5)
local hudSub = label(hud, "", F.body, 13, C.muted, { Name = "Sub", Position = UDim2.fromOffset(60, 49), Size = UDim2.new(1, -76, 0, 18) })

local PLAY_XP = remotes:GetAttribute("PlayXP") or 1
local PLAY_INTERVAL = remotes:GetAttribute("PlayInterval") or 15
local DONOR_XP = remotes:GetAttribute("DonorXPPerRobux") or 20
label(hud, string.format("Her %d sn: +%d XP   •   1 Robux destek: +%d XP", PLAY_INTERVAL, PLAY_XP, DONOR_XP), F.body, 13, C.green, { Name = "Info", Position = UDim2.fromOffset(60, 68), Size = UDim2.new(1, -76, 0, 18) })

local function refreshHud()
	local ls = player:FindFirstChild("leaderstats")
	local data = player:FindFirstChild("EggData")
	local hasBooth = player:GetAttribute("HasBooth") == true
	if not (ls and data and ls:FindFirstChild("Level") and data:FindFirstChild("EggXP")) then
		hud.Visible = false
		return
	end
	hud.Visible = true
	local level, xp = ls.Level.Value, data.EggXP.Value
	local r = rarityOf(level)
	local col = rgb(r.rgb)
	hudEgg.BackgroundColor3 = hasBooth and col or C.muted
	hudStroke.Color = hasBooth and col or C.line
	if not hasBooth then
		hudTitle.Text = "Yumurtanı bekliyor"
		hudSub.Text = TIP_TEXT
		hudFill.Size = UDim2.fromScale(0, 1)
		return
	end
	local need = xpNeeded(level)
	hudTitle.Text = string.format("Seviye %d  •  %s", level, r.name)
	hudTitle.TextColor3 = col
	hudFill.BackgroundColor3 = col
	hudFill.Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1)
	local ns = nextStyle(level)
	hudSub.Text = string.format("%d / %d XP", xp, need) .. (ns and string.format("   •   Sonraki stil: %s (Sv. %d)", ns.name, ns.level) or "")
end

task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	local data = player:WaitForChild("EggData")
	local lvl = ls:WaitForChild("Level")
	local xpv = data:WaitForChild("EggXP")
	lvl.Changed:Connect(refreshHud)
	xpv.Changed:Connect(refreshHud)
	refreshHud()
end)
player:GetAttributeChangedSignal("HasBooth"):Connect(refreshHud)
refreshHud()

---------------------------------------------------------------------
-- Stand paneli
---------------------------------------------------------------------
local panel -- { frame, booth, widgets }
local selectedStyle, selectedColor = "classic", 1

local function closePanel(notifyServer)
	if panel then
		panel.frame:Destroy()
		panel = nil
		if notifyServer then
			remotes.PanelAction:FireServer({ Action = "Close" })
		end
	end
end

local function button(parent, text, color, props)
	local b = new("TextButton", {
		BackgroundColor3 = color,
		Font = F.bold,
		TextSize = 17,
		TextColor3 = C.text,
		Text = text,
		AutoButtonColor = true,
	}, parent)
	corner(b, 12)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	return b
end

local function section(parent, title, order)
	local s = new("Frame", { Name = title, Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, LayoutOrder = order }, parent)
	s.AutomaticSize = Enum.AutomaticSize.Y
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	label(s, title, F.bold, 14, C.muted, { Name = "Header", Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0 })
	return s
end

local function buildPanel(p)
	closePanel(false)
	local frame = new("Frame", {
		Name = "BoothPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(0.92, 0.84),
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
	}, gui)
	corner(frame, 18)
	stroke(frame, C.line, 2)
	new("UISizeConstraint", { MaxSize = Vector2.new(460, 660), MinSize = Vector2.new(280, 300) }, frame)
	panel = { frame = frame, booth = p.Booth, w = {} }
	local w = panel.w

	-- Ust bilgi
	local head = new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1 }, frame)
	w.egg = eggIcon(head, C.muted, 36, 46, UDim2.fromOffset(20, 18))
	w.name = label(head, "", F.title, 22, C.text, { Position = UDim2.fromOffset(70, 12), Size = UDim2.new(1, -120, 0, 28), TextTruncate = Enum.TextTruncate.AtEnd })
	w.level = label(head, "", F.bold, 16, C.muted, { Position = UDim2.fromOffset(70, 40), Size = UDim2.new(1, -120, 0, 22) })
	local barBack = new("Frame", { Name = "BarBack", Position = UDim2.fromOffset(20, 72), Size = UDim2.new(1, -40, 0, 12), BackgroundColor3 = Color3.fromRGB(56, 63, 88), BorderSizePixel = 0 }, head)
	corner(barBack, 6)
	w.fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green, BorderSizePixel = 0 }, barBack)
	corner(w.fill, 6)
	local close = button(head, "X", C.card, { Name = "CloseButton", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(34, 34), TextSize = 16 })
	close.Activated:Connect(function()
		closePanel(true)
	end)

	-- Kaydirilabilir icerik
	local scroll = new("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 1, -100),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, frame)
	new("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingBottom = UDim.new(0, 16) }, scroll)
	new("UIListLayout", { Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

	w.message = label(scroll, "", F.body, 16, C.gold, { Name = "Message", Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, TextWrapped = true })

	-- Destek ol (sahibi degilse)
	w.supportSec = section(scroll, "DESTEK OL", 3)
	w.supportSec.Visible = false
	w.supportNote = label(w.supportSec, "", F.body, 14, C.muted, { Name = "Note", Size = UDim2.new(1, 0, 0, 36), TextWrapped = true, LayoutOrder = 1 })

	-- Stiller (sahibi ise)
	w.styleSec = section(scroll, "STAND STİLLERİ", 4)
	w.styleSec.Visible = false
	local grid = new("Frame", { Name = "StyleGrid", Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, LayoutOrder = 1 }, w.styleSec)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 78), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	w.styleCards = {}
	for i, s in ipairs(STYLES) do
		local card = new("TextButton", { Name = "Style_" .. s.id, BackgroundColor3 = C.card, Text = "", LayoutOrder = i, AutoButtonColor = true }, grid)
		corner(card, 12)
		local st = stroke(card, C.card, 2)
		local _, dim = styleIcon(card, s.id)
		label(card, s.name, F.bold, 16, C.text, { Name = "StyleName", Position = UDim2.fromOffset(64, 10), Size = UDim2.new(1, -92, 0, 22) })
		local sub = label(card, "", F.body, 12, C.muted, { Name = "Sub", Position = UDim2.fromOffset(64, 34), Size = UDim2.new(1, -72, 0, 36), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		local lock = lockIcon(card, UDim2.new(1, -28, 0, 10), C.muted)
		w.styleCards[s.id] = { card = card, stroke = st, sub = sub, lock = lock, dim = dim, style = s }
		card.Activated:Connect(function()
			if panel and panel.level and panel.level >= s.level then
				selectedStyle = s.id
				panel.refreshStyles()
			else
				showToast(string.format("%s stili Seviye %d'de açılır.", s.name, s.level), C.red)
			end
		end)
	end

	w.colorHeader = label(w.styleSec, "RENK", F.bold, 14, C.muted, { Name = "ColorHeader", Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 2 })
	local colorRow = new("Frame", { Name = "ColorRow", Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 3 }, w.styleSec)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, colorRow)
	w.colorButtons = {}
	for i, c in ipairs(COLORS) do
		local sw = new("TextButton", { Name = "Color_" .. i, Size = UDim2.fromOffset(36, 36), BackgroundColor3 = rgb(c.rgb), Text = "", LayoutOrder = i }, colorRow)
		corner(sw, 18)
		local st = stroke(sw, C.panel, 3)
		w.colorButtons[i] = st
		sw.Activated:Connect(function()
			selectedColor = i
			panel.refreshStyles()
		end)
	end

	w.msgHeader = label(w.styleSec, "MESAJ (herkese görünür)", F.bold, 14, C.muted, { Name = "MsgHeader", Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 4 })
	w.box = new("TextBox", {
		Name = "MessageBox",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = C.card,
		Font = F.body,
		TextSize = 16,
		TextColor3 = C.text,
		PlaceholderText = "Mesajın (en fazla " .. MAX_MESSAGE .. " karakter)",
		PlaceholderColor3 = C.muted,
		ClearTextOnFocus = false,
		Text = "",
		LayoutOrder = 5,
	}, w.styleSec)
	corner(w.box, 10)
	w.save = button(w.styleSec, "Kaydet", C.green, { Name = "SaveButton", Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 6 })
	w.save.Activated:Connect(function()
		local text = w.box.Text
		local cut = utf8.len(text) and utf8.len(text) > MAX_MESSAGE and utf8.offset(text, MAX_MESSAGE + 1)
		if cut then
			text = string.sub(text, 1, cut - 1)
		end
		remotes.PanelAction:FireServer({ Action = "Style", Style = selectedStyle, Color = selectedColor, Text = text })
	end)

	-- secili stil/renk gorunumunu tazele
	function panel.refreshStyles()
		for id, sc in pairs(w.styleCards) do
			local unlocked = panel.level and panel.level >= sc.style.level
			sc.lock.Visible = not unlocked
			sc.dim.Visible = not unlocked
			sc.sub.Text = unlocked and sc.style.desc or string.format("Seviye %d'de açılır", sc.style.level)
			sc.sub.TextColor3 = unlocked and C.muted or C.gold
			sc.card.BackgroundColor3 = unlocked and C.card or Color3.fromRGB(34, 39, 58)
			sc.stroke.Color = (id == selectedStyle) and C.green or C.card
		end
		for i, st in ipairs(w.colorButtons) do
			st.Color = (i == selectedColor) and C.text or C.panel
		end
	end
	return panel
end

local function updatePanel(p)
	local w = panel.w
	panel.level = p.Level
	local col = p.RarityColor
	w.egg.BackgroundColor3 = col
	w.name.Text = p.OwnerName
	w.level.Text = string.format("Seviye %d  •  %s", p.Level, p.Rarity)
	w.level.TextColor3 = col
	w.fill.BackgroundColor3 = col
	w.fill.Size = UDim2.fromScale(math.clamp(p.XP / p.Need, 0, 1), 1)
	w.message.Text = (p.Message ~= "") and ("“" .. p.Message .. "”") or ""
	w.message.Visible = p.Message ~= ""

	-- destek
	w.supportSec.Visible = not p.IsOwner
	if not p.IsOwner then
		for _, c in ipairs(w.supportSec:GetChildren()) do
			if c.Name:sub(1, 8) == "Product_" then
				c:Destroy()
			end
		end
		if #p.Products == 0 then
			w.supportNote.Text = "Destek ürünleri yakında burada olacak."
		else
			w.supportNote.Text = "Her Robux standın sahibine " .. p.XPPerRobux .. " XP kazandırır, sana da +" .. DONOR_XP .. " XP."
			for i, prod in ipairs(p.Products) do
				local b = button(w.supportSec, string.format("%s   •   R$ %d   (+%d XP)", prod.Name, prod.Price, prod.Price * p.XPPerRobux), C.gold, {
					Name = "Product_" .. prod.Id,
					Size = UDim2.new(1, 0, 0, 46),
					LayoutOrder = i + 1,
					TextColor3 = Color3.fromRGB(50, 36, 10),
				})
				b.Activated:Connect(function()
					remotes.RequestPurchase:FireServer(prod.Id)
				end)
			end
		end
	end

	-- stiller
	w.styleSec.Visible = p.IsOwner
	if p.IsOwner then
		if not panel.initialized then
			panel.initialized = true
			selectedStyle, selectedColor = p.Style, p.Color
			w.box.Text = p.Message
		end
		panel.refreshStyles()
	end
end

remotes.OpenPanel.OnClientEvent:Connect(function(p)
	if not panel or panel.booth ~= p.Booth then
		buildPanel(p)
	end
	updatePanel(p)
end)

-- paneli sunucunun dogruladigi mesafeden once kapat; geri sayimi tazele
task.spawn(function()
	while true do
		task.wait(0.25)
		if panel then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local part = panel.booth and panel.booth.PrimaryPart
			if root and part and (root.Position - part.Position).Magnitude > 22 then
				closePanel(true)
			end
		end
	end
end)
