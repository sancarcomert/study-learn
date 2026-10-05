-- ADIM 3/6: PARK - agaclar, nehir + kopru, tepeler, yol lambalari
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
local rng = Random.new(33)
local k3 = fresh("Park")
local KINDS = { "oak", "oak", "oak", "oak", "oak", "birch", "birch", "cherry", "maple" }
-- 70 agac: meydandan, yollardan ve nehirden uzak
local placed = {}
for _ = 1, 4000 do
	if #placed >= 70 then
		break
	end
	local x, z = rng:NextNumber(-PARK + 14, PARK - 14), rng:NextNumber(-PARK + 14, PARK - 14)
	local ax, az = math.abs(x), math.abs(z)
	local ok = math.max(ax, az) >= HALF + 12 and math.min(ax, az) >= 22 and math.abs(x - RIVER_X) >= 22
	if ok then
		for _, p in ipairs(placed) do
			if (p[1] - x) ^ 2 + (p[2] - z) ^ 2 < 16 * 16 then
				ok = false
				break
			end
		end
	end
	if ok then
		table.insert(placed, { x, z })
		tree(k3, x, z, rng:NextNumber(0.85, 1.35), KINDS[rng:NextInteger(1, #KINDS)], rng)
	end
end
-- yol lambalari (nehir kopru bolgesi haric)
for side = 0, 3 do
	local rot = sideRot(side)
	local t = HALF + 20
	while t < PARK - 24 do
		for _, sx in ipairs({ -1, 1 }) do
			local p = rot * Vector3.new(sx * 11, 0, -t)
			if math.abs(p.X - RIVER_X) > 20 then
				lamp(k3, p.X, p.Z)
			end
		end
		t = t + 36
	end
end
-- nehir: x = 150, genis 10, iki yaninda kum seridi
P(k3, "BankSand", Vector3.new(16, 0.1, PARK * 2 - 10), CFrame.new(RIVER_X, 0.03, 0), RGB(222, 200, 150), Mat.Sand, NOCOL)
P(k3, "River", Vector3.new(10, 0.1, PARK * 2 - 10), CFrame.new(RIVER_X, 0.08, 0), RGB(76, 168, 220), Mat.SmoothPlastic, { solid = false, shadow = false })
-- ahsap kopru (+X yolu uzerinde)
local WL, WM, WD = RGB(190, 144, 94), RGB(160, 114, 74), RGB(118, 82, 52)
P(k3, "BridgeDeck", Vector3.new(26, 0.4, 16), CFrame.new(RIVER_X, 0.3, 0), WL, Mat.WoodPlanks)
for _, sz in ipairs({ -7.8, 7.8 }) do
	P(k3, "BridgeRailTop", Vector3.new(26, 0.35, 0.4), CFrame.new(RIVER_X, 2.3, sz), WM, Mat.Wood)
	P(k3, "BridgeRailMid", Vector3.new(26, 0.3, 0.3), CFrame.new(RIVER_X, 1.4, sz), WM, Mat.Wood, { solid = false })
	for k = -2, 2 do
		P(k3, "BridgePost", Vector3.new(0.6, 2.2, 0.6), CFrame.new(RIVER_X + k * 5.5, 1.4, sz), WD, Mat.Wood)
	end
end
-- nehir kenari kayalari
for z = -200, 200, 40 do
	for _, s in ipairs({ -1, 1 }) do
		if math.abs(z) > 20 then
			local sz = rng:NextNumber(1.6, 3)
			Ell(k3, "Rock", Vector3.new(sz * 1.2, sz * 0.8, sz), CFrame.new(RIVER_X + s * rng:NextNumber(10, 13), sz * 0.2, z + rng:NextNumber(-8, 8)), RGB(138, 138, 142), Mat.Slate, NOCOL)
		end
	end
end
-- uzak tepeler (parka girmez) + gorunmez sinir duvarlari
for k = 0, 13 do
	local a = k / 14 * TAU + rng:NextNumber(-0.12, 0.12)
	local w, h = rng:NextNumber(200, 320), rng:NextNumber(70, 130)
	local r = rng:NextNumber(420, 560)
	Ell(k3, "Hill", Vector3.new(w, h, w * rng:NextNumber(0.7, 1)), CFrame.new(math.cos(a) * r, -h * 0.1, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
		(k % 2 == 0) and RGB(80, 148, 62) or RGB(98, 164, 68), Mat.Grass, NOCOL)
end
for side = 0, 3 do
	P(k3, "Barrier", Vector3.new(PARK * 2 + 12, 60, 2), sideRot(side) * CFrame.new(0, 30, -(PARK + 3)), RGB(255, 255, 255), Mat.SmoothPlastic, { tr = 1, shadow = false })
end
print("[Adim 3] Park hazir: " .. #placed .. " agac, nehir, kopru")
