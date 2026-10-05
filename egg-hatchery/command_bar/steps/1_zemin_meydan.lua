-- ADIM 1/6: ZEMIN + MEYDAN + YOLLAR  (once Baseplate'i siler)
local W = game:GetService("Workspace")
local CS = game:GetService("CollectionService")
local RGB, Mat = Color3.fromRGB, Enum.Material
local TAU = math.pi * 2
local map = W:FindFirstChild("Map")
if not map then
	map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = W
end
local function fresh(name)
	local o = map:FindFirstChild(name)
	if o then
		o:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = map
	return f
end
local function P(parent, name, size, cf, color, mat, o)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	if o and o.shape then
		p.Shape = o.shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Locked = true
	if o then
		if o.tr then
			p.Transparency = o.tr
		end
		if o.solid == false then
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
		end
		if o.shadow == false then
			p.CastShadow = false
		end
	end
	p.Parent = parent
	return p
end
local UP = CFrame.Angles(0, 0, math.rad(90))
local function Cyl(parent, name, d, h, cf, color, mat, o)
	o = o or {}
	o.shape = Enum.PartType.Cylinder
	return P(parent, name, Vector3.new(h, d, d), cf * UP, color, mat, o)
end
local function Ball(parent, name, d, cf, color, mat, o)
	o = o or {}
	o.shape = Enum.PartType.Ball
	return P(parent, name, Vector3.new(d, d, d), cf, color, mat, o)
end
local function Ell(parent, name, size, cf, color, mat, o)
	local p = P(parent, name, size, cf, color, mat, o)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end
local function sideRot(side)
	return CFrame.Angles(0, math.rad(90 * side), 0)
end
local NOCOL = { solid = false, shadow = false }
local HALF, PARK, RIVER_X = 106, 232, 150
for _, c in ipairs(W:GetChildren()) do
	if c.Name == "Baseplate" or c:IsA("SpawnLocation") then
		c:Destroy()
	end
end
local rng = Random.new(5)
local g = fresh("Ground")
P(g, "Grass", Vector3.new(1400, 2, 1400), CFrame.new(0, -1, 0), RGB(98, 164, 68), Mat.Grass)
local n = 0
for _ = 1, 400 do
	if n >= 34 then
		break
	end
	local x, z, d = rng:NextNumber(-215, 215), rng:NextNumber(-215, 215), rng:NextNumber(14, 38)
	if math.max(math.abs(x), math.abs(z)) > HALF + d / 2 + 2 and math.min(math.abs(x), math.abs(z)) > 8 + d / 2 + 2 and math.abs(x - RIVER_X) > d / 2 + 12 then
		n = n + 1
		Cyl(g, "Patch", d, 0.1, CFrame.new(x, 0.05, z), (n % 2 == 0) and RGB(120, 186, 84) or RGB(82, 150, 62), Mat.Grass, NOCOL)
	end
end

local pl = fresh("Plaza")
local STONE, BAND, LIGHT, CURB = RGB(190, 172, 142), RGB(150, 136, 114), RGB(214, 198, 168), RGB(140, 128, 110)
P(pl, "PlazaFloor", Vector3.new(HALF * 2, 0.4, HALF * 2), CFrame.new(0, -0.08, 0), STONE, Mat.Cobblestone)
for k = -8, 8 do
	P(pl, "TileLine", Vector3.new(HALF * 2, 0.06, 0.3), CFrame.new(0, 0.15, k * 12), BAND, Mat.Slate, NOCOL)
	P(pl, "TileLine", Vector3.new(0.3, 0.06, HALF * 2), CFrame.new(k * 12, 0.15, 0), BAND, Mat.Slate, NOCOL)
end
for side = 0, 3 do
	local rot = sideRot(side)
	P(pl, "Border", Vector3.new(HALF * 2, 0.1, 4), rot * CFrame.new(0, 0.17, -(HALF - 2)), BAND, Mat.Slate, NOCOL)
	for _, sx in ipairs({ -1, 1 }) do
		P(pl, "Curb", Vector3.new(HALF - 8, 0.55, 1.2), rot * CFrame.new(sx * (8 + (HALF - 8) / 2), 0.27, -HALF), CURB, Mat.Concrete)
	end
	local spans = { { HALF, PARK - 14 } }
	if side == 3 then
		spans = { { HALF, RIVER_X - 13 }, { RIVER_X + 13, PARK - 14 } }
	end
	for _, sp in ipairs(spans) do
		local len, mid = sp[2] - sp[1], (sp[1] + sp[2]) / 2
		P(pl, "Path", Vector3.new(16, 0.4, len), rot * CFrame.new(0, -0.08, -mid), STONE, Mat.Cobblestone)
		for _, sx in ipairs({ -1, 1 }) do
			P(pl, "PathEdge", Vector3.new(0.7, 0.2, len), rot * CFrame.new(sx * 8.35, 0.1, -mid), CURB, Mat.Slate, NOCOL)
		end
	end
end
Cyl(pl, "Medallion", 60, 0.08, CFrame.new(0, 0.16, 0), LIGHT, Mat.Slate, NOCOL)
for _, r in ipairs({ 30, 17 }) do
	local count = (r == 30) and 44 or 28
	local chord = 2 * r * math.sin(math.pi / count) * 1.06
	for k = 0, count - 1 do
		local a = k / count * TAU
		P(pl, "MedallionRing", Vector3.new(0.7, 0.08, chord), CFrame.new(math.cos(a) * r, 0.18, math.sin(a) * r) * CFrame.Angles(0, -a, 0), BAND, Mat.Slate, NOCOL)
	end
end
print("[Adim 1] Zemin + meydan hazir: " .. #pl:GetChildren() .. " parca")
