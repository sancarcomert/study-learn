-- ServerScriptService/BoothAdapter (Script)
--
-- Haritadaki "propy's booth" modellerini oyuna baglar (Pls Donate haritasi icin):
--   1) Her stand modelini Workspace.Booths klasorune tasir (BoothManager buradan okur)
--   2) PrimaryPart yoksa en buyuk parcayi PrimaryPart yapar (istem butonlari buraya baglanir)
-- Yumurtayi ve karti HatcheryService kurar (BoothManager acilista her stand icin cagirir).
-- BoothManager klasorun var olmasini bekler; bu script onu olusturur.

local Workspace = game:GetService("Workspace")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(Modules.Config)

local BOOTH_NAME = "propy's booth"

local folder = Workspace:FindFirstChild(Config.BOOTH_FOLDER_NAME)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = Config.BOOTH_FOLDER_NAME
	folder.Parent = Workspace
end

local function adapt(model)
	local hasPart = false
	local best, bestVolume = nil, -1
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			hasPart = true
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestVolume then
				best, bestVolume = d, v
			end
		end
	end
	if not hasPart then
		warn("[BoothAdapter] Bos stand atlandi: " .. model:GetFullName())
		return false
	end
	if not model.PrimaryPart then
		model.PrimaryPart = best
	end
	model.Parent = folder
	return true
end

local found = {}
for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("Model") and d.Name == BOOTH_NAME and d.Parent ~= folder then
		table.insert(found, d)
	end
end
local ok = 0
for _, m in ipairs(found) do
	if adapt(m) then
		ok = ok + 1
	end
end
print(string.format("[BoothAdapter] %d stand oyuna baglandi (%d bulundu)", ok, #found))
