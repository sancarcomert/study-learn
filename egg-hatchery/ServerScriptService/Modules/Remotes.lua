local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Config)

local folder = ReplicatedStorage:FindFirstChild("EggRemotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "EggRemotes"
	folder.Parent = ReplicatedStorage
end

-- Istemci Config'e erisemez; stand ayari paneli icin gereken degerler burada yayinlanir
folder:SetAttribute("StyleMaxLength", Config.STYLE_MAX_LENGTH)
folder:SetAttribute("StyleColorCount", #Config.STYLE_COLORS)
for i, c in ipairs(Config.STYLE_COLORS) do
	folder:SetAttribute("StyleColor" .. i, c.Color)
	folder:SetAttribute("StyleName" .. i, c.Name)
end

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
	Notify = remote("Notify"),
	OpenDonateMenu = remote("OpenDonateMenu"),
	RequestPurchase = remote("RequestPurchase"),
	EggFeedback = remote("EggFeedback"),
	SetBoothStyle = remote("SetBoothStyle"),
}
