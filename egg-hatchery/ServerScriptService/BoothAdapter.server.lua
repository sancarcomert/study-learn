-- ServerScriptService/BoothAdapter (Script)
--
-- Haritadaki "propy's booth" modellerini oyuna baglar (Pls Donate haritasi icin):
--   1) Her stand modelini Workspace.Booths klasorune tasir (BoothManager buradan okur)
--   2) PrimaryPart yoksa en buyuk parcayi PrimaryPart yapar (istem butonlari buraya baglanir)
--   3) Standin ustune "Egg" yumurtasini ekler (yoksa) ve yuzme etiketi (FX_Bob) koyar
-- BoothManager klasorun var olmasini bekler; bu script onu olusturur.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(Modules.Config)

local BOOTH_NAME = "propy's booth"

local folder = Workspace:FindFirstChild(Config.BOOTH_FOLDER_NAME)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = Config.BOOTH_FOLDER_NAME
	folder.Parent = Workspace
end

-- standin eksen hizali sinirlari (butun parcalarin koselerinden)
local function bounds(model)
	local x0, x1, y0, y1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	local count = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			count = count + 1
			for _, sx in ipairs({ -0.5, 0.5 }) do
				for _, sy in ipairs({ -0.5, 0.5 }) do
					for _, sz in ipairs({ -0.5, 0.5 }) do
						local c = d.CFrame * Vector3.new(sx * d.Size.X, sy * d.Size.Y, sz * d.Size.Z)
						x0, x1 = math.min(x0, c.X), math.max(x1, c.X)
						y0, y1 = math.min(y0, c.Y), math.max(y1, c.Y)
						z0, z1 = math.min(z0, c.Z), math.max(z1, c.Z)
					end
				end
			end
		end
	end
	return count, x0, x1, y0, y1, z0, z1
end

local function adapt(model)
	local count, x0, x1, y0, y1, z0, z1 = bounds(model)
	if count == 0 then
		warn("[BoothAdapter] Bos stand atlandi: " .. model:GetFullName())
		return false
	end

	if not model.PrimaryPart then
		local best, bestVolume = nil, -1
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				local v = d.Size.X * d.Size.Y * d.Size.Z
				if v > bestVolume then
					best, bestVolume = d, v
				end
			end
		end
		model.PrimaryPart = best
	end

	if not model:FindFirstChild("Egg") then
		local egg = Instance.new("Part")
		egg.Name = "Egg"
		egg.Anchored = true
		egg.CanCollide = false
		egg.CanTouch = false
		egg.CanQuery = false
		egg.CastShadow = false
		egg.Material = Enum.Material.Neon
		egg.Color = Color3.fromRGB(244, 247, 250)
		egg.Size = Vector3.new(2.2, 3, 2.2)
		egg.CFrame = CFrame.new((x0 + x1) / 2, y1 + 2.4, (z0 + z1) / 2)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = egg
		egg.Parent = model
		CollectionService:AddTag(egg, "FX_Bob")
		egg:SetAttribute("BobHeight", 0.2)
		egg:SetAttribute("BobSpeed", 1.2)
		egg:SetAttribute("BobPhase", (#folder:GetChildren() * 0.7) % (math.pi * 2))
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
