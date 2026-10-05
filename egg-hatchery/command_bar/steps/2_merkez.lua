-- ADIM 2/6: MERKEZ - cesme, bank, saksi, lamba, kose agaclari
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
local function tree(parent, x, z, s, kind, rng)
	local K = {
		oak = { RGB(86, 164, 66), RGB(106, 180, 74), RGB(66, 142, 58) },
		birch = { RGB(120, 190, 80), RGB(140, 200, 96) },
		cherry = { RGB(246, 160, 190), RGB(238, 132, 170) },
		maple = { RGB(232, 140, 52), RGB(212, 100, 44) },
	}
	local cols = K[kind]
	local h = 9 * s
	local cf = CFrame.new(x, 0, z)
	Cyl(parent, "Trunk", (kind == "birch" and 1.1 or 1.8) * s, h, cf * CFrame.new(0, h / 2, 0), (kind == "birch") and RGB(232, 228, 216) or RGB(112, 78, 50), Mat.Wood)
	local k = rng:NextInteger(1, #cols)
	local soft = { solid = false }
	Ball(parent, "Leaves", 13 * s, cf * CFrame.new(0, h + 3.5 * s, 0), cols[k], Mat.Grass, soft)
	Ball(parent, "Leaves", 9.5 * s, cf * CFrame.new(3.6 * s, h + 1.5 * s, 1.2 * s), cols[k % #cols + 1], Mat.Grass, soft)
	Ball(parent, "Leaves", 8.5 * s, cf * CFrame.new(-3.2 * s, h + 2 * s, -1.8 * s), cols[(k + 1) % #cols + 1], Mat.Grass, soft)
end
local function lamp(parent, x, z)
	local cf = CFrame.new(x, 0, z)
	local metal = RGB(56, 60, 66)
	Cyl(parent, "LampBase", 1.4, 0.5, cf * CFrame.new(0, 0.25, 0), metal, Mat.Metal)
	Cyl(parent, "LampPole", 0.5, 7, cf * CFrame.new(0, 3.5, 0), metal, Mat.Metal)
	P(parent, "LampHead", Vector3.new(1.3, 1.6, 1.3), cf * CFrame.new(0, 7.8, 0), RGB(255, 214, 140), Mat.Neon, NOCOL)
	P(parent, "LampCap", Vector3.new(1.9, 0.3, 1.9), cf * CFrame.new(0, 8.75, 0), metal, Mat.Metal, { solid = false })
end
local rng = Random.new(21)
local c = fresh("Center")
local STONE, CAP, SOIL, WOOD, DARK = RGB(176, 166, 148), RGB(214, 198, 168), RGB(92, 64, 44), RGB(160, 114, 74), RGB(118, 82, 52)
local FLOWERS = { RGB(255, 128, 170), RGB(255, 224, 90), RGB(250, 250, 250), RGB(235, 80, 80), RGB(180, 120, 230), RGB(255, 150, 60) }

local function ring(name, y, r, count, radial, h, color, mat)
	local chord = 2 * r * math.sin(math.pi / count) * 1.06
	for k = 0, count - 1 do
		local a = k / count * TAU
		P(c, name, Vector3.new(radial, h, chord), CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(0, -a, 0), color, mat)
	end
end
-- cesme (yaricap 12, en fazla 8 stud yuksek)
Cyl(c, "BasinFloor", 24, 0.5, CFrame.new(0, 0.37, 0), STONE, Mat.Concrete)
ring("BasinWall", 0.92, 11.4, 32, 1.2, 1.6, STONE, Mat.Concrete)
ring("BasinCap", 1.84, 11.4, 32, 1.7, 0.2, CAP, Mat.Concrete)
Cyl(c, "Water", 21.6, 0.2, CFrame.new(0, 1.22, 0), RGB(118, 196, 238), Mat.Glass, { solid = false, shadow = false, tr = 0.35 })
Cyl(c, "Pedestal", 5, 2.6, CFrame.new(0, 1.92, 0), STONE, Mat.Concrete)
Cyl(c, "Bowl", 9, 0.5, CFrame.new(0, 3.47, 0), STONE, Mat.Concrete)
Cyl(c, "Column", 1.4, 2.6, CFrame.new(0, 5.02, 0), STONE, Mat.Concrete)
Ball(c, "Finial", 2.4, CFrame.new(0, 6.62, 0), STONE, Mat.Concrete)
local function jet(name, pos, dir, rate, speed, spread)
	local a = P(c, name, Vector3.new(0.4, 0.4, 0.4), CFrame.lookAt(pos, pos + dir), RGB(255, 255, 255), Mat.SmoothPlastic, { tr = 1, solid = false, shadow = false })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(RGB(244, 247, 250), RGB(118, 196, 238))
	e.LightEmission = 0.3
	e.Rate = rate
	e.Lifetime = NumberRange.new(1.2, 1.7)
	e.Speed = NumberRange.new(speed, speed + 4)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.Acceleration = Vector3.new(0, -32, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.3) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.EmissionDirection = Enum.NormalId.Front
	e.Parent = a
end
jet("Spray", Vector3.new(0, 7.9, 0), Vector3.new(0, 1, 0), 60, 16, 10)
for k = 0, 7 do
	local a = k / 8 * TAU
	jet("Jet", Vector3.new(math.cos(a) * 3.6, 3.9, math.sin(a) * 3.6), Vector3.new(math.cos(a) * 0.8, 0.9, math.sin(a) * 0.8), 22, 10, 5)
end

-- 8 bank (yaricap 30), hepsi cesmeye bakar
for k = 0, 7 do
	local a = math.rad(22.5 + 45 * k)
	local cf = CFrame.lookAt(Vector3.new(math.cos(a) * 30, 0, math.sin(a) * 30), Vector3.new(0, 0, 0))
	P(c, "BenchSeat", Vector3.new(4.6, 0.4, 1.6), cf * CFrame.new(0, 1.7, 0), WOOD, Mat.WoodPlanks)
	P(c, "BenchBack", Vector3.new(4.6, 1.3, 0.3), cf * CFrame.new(0, 2.65, 0.7), WOOD, Mat.WoodPlanks, { solid = false })
	for _, sx in ipairs({ -2, 2 }) do
		P(c, "BenchLeg", Vector3.new(0.5, 1.5, 1.4), cf * CFrame.new(sx, 0.75, 0), RGB(56, 60, 66), Mat.Metal)
	end
end
-- 8 cicek saksisi (yaricap 38)
for k = 0, 7 do
	local a = k / 8 * TAU
	local cf = CFrame.new(math.cos(a) * 38, 0, math.sin(a) * 38) * CFrame.Angles(0, -a, 0)
	P(c, "PlanterBox", Vector3.new(4.5, 1.1, 4.5), cf * CFrame.new(0, 0.55, 0), DARK, Mat.WoodPlanks)
	P(c, "PlanterSoil", Vector3.new(3.9, 0.2, 3.9), cf * CFrame.new(0, 1.15, 0), SOIL, Mat.Ground, NOCOL)
	for _ = 1, 8 do
		Ball(c, "Flower", 0.7, cf * CFrame.new(rng:NextNumber(-1.6, 1.6), 1.5, rng:NextNumber(-1.6, 1.6)), FLOWERS[rng:NextInteger(1, #FLOWERS)], Mat.SmoothPlastic, NOCOL)
	end
end
-- lambalar: stand araliklarinda (x = +-29, +-53), stand hatti uzerinde
for side = 0, 3 do
	local rot = sideRot(side)
	for _, x in ipairs({ -53, -29, 29, 53 }) do
		local p = rot * Vector3.new(x, 0, -88)
		lamp(c, p.X, p.Z)
	end
end
-- 4 kose agaci
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local x, z = sx * 96, sz * 96
		local chord = 2 * 4.2 * math.sin(math.pi / 14) * 1.06
		for k = 0, 13 do
			local a = k / 14 * TAU
			P(c, "TreeRing", Vector3.new(0.8, 0.6, chord), CFrame.new(x + math.cos(a) * 4.2, 0.3, z + math.sin(a) * 4.2) * CFrame.Angles(0, -a, 0), RGB(140, 128, 110), Mat.Concrete)
		end
		tree(c, x, z, 1.15, "cherry", rng)
	end
end
print("[Adim 2] Merkez hazir: " .. #c:GetChildren() .. " parca")
