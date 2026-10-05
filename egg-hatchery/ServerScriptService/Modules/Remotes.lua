local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(script.Parent.Config)

local folder = ReplicatedStorage:FindFirstChild("EggRemotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "EggRemotes"
	folder.Parent = ReplicatedStorage
end

-- Istemci Config'e erisemez: arayuzun ihtiyaci olan degerler burada (JSON olarak) yayinlanir
local function rgb(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end
local styles, colors, rarities = {}, {}, {}
for _, s in ipairs(Config.STYLES) do
	table.insert(styles, { id = s.Id, name = s.Name, level = s.Level, desc = s.Desc })
end
for _, c in ipairs(Config.STYLE_COLORS) do
	table.insert(colors, { name = c.Name, rgb = rgb(c.Color) })
end
for _, r in ipairs(Config.RARITIES) do
	table.insert(rarities, { name = r.Name, min = r.MinLevel, rgb = rgb(r.Color) })
end
folder:SetAttribute("StylesJSON", HttpService:JSONEncode(styles))
folder:SetAttribute("ColorsJSON", HttpService:JSONEncode(colors))
folder:SetAttribute("RaritiesJSON", HttpService:JSONEncode(rarities))
folder:SetAttribute("XPBase", Config.XP_BASE)
folder:SetAttribute("XPExp", Config.XP_EXP)
folder:SetAttribute("MaxLevel", Config.MAX_LEVEL)
folder:SetAttribute("MaxMessage", Config.STYLE_MAX_LENGTH)
folder:SetAttribute("TipText", Config.TEXT.Tip)
folder:SetAttribute("PlayXP", Config.PLAY_XP)
folder:SetAttribute("PlayInterval", Config.PLAY_INTERVAL)
folder:SetAttribute("XPPerRobux", Config.XP_PER_ROBUX)
folder:SetAttribute("DonorXPPerRobux", Config.DONOR_XP_PER_ROBUX)

local function remote(name)
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = folder
	return ev
end

return {
	Notify = remote("Notify"), -- sunucu -> istemci: kisa bildirim
	OpenPanel = remote("OpenPanel"), -- sunucu -> istemci: stand paneli verisi
	PanelAction = remote("PanelAction"), -- istemci -> sunucu: {Action = "Style" | "Close", ...}
	RequestPurchase = remote("RequestPurchase"), -- istemci -> sunucu: bagis urunu ID'si
	EggFeedback = remote("EggFeedback"), -- sunucu -> istemci: seviye atlama / stil acilimi duyurulari
}
