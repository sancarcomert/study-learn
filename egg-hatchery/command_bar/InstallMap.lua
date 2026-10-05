-- ============================================================
-- SUNNY PARK - tek komutla kurulum (Studio Command Bar)
-- 1) Studio'da View > Command Bar'i ac (altta yazi kutusu cikar)
-- 2) Bu dosyanin TAMAMINI kopyala, kutuya yapistir, Enter'a bas
-- 3) Birkac saniye bekle; Output'ta "[Kurulum] Bitti" yazinca hazir
-- Ayarlari (stand sayisi, ruh hali, isik) asagidaki ilk satirlardan degistirip tekrar calistirabilirsin.
-- ============================================================
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local BOOTHS_PER_SIDE = 6 -- her kenardaki stand sayisi: 6 (toplam 24) ya da 8 (toplam 32)
local BOOTH_FOLDER_NAME = "Booths"
local USE_FUTURE_LIGHTING = false -- true: daha guzel isik/golge (mobilde daha agir). Sadece Command Bar'dan calisir
local LOCK_PARTS = true -- true: parcalar kilitli olur, viewport'ta yanlislikla tasimazsin
local SEED = 11

BOOTHS_PER_SIDE = (BOOTHS_PER_SIDE >= 8) and 8 or 6

local PATH_HALF = 8 -- 4 yonlu yolun yari genisligi (stand aralarindaki giris boslugu)
local BOOTH_HALF = 8 -- stand yari genisligi
local BOOTH_STEP = 24 -- stand merkezleri arasi mesafe
local FIRST_BOOTH = PATH_HALF + BOOTH_HALF + 1 -- girisin yanindaki ilk standin merkezi
local PER_HALF = BOOTHS_PER_SIDE / 2
local OUTER_EDGE = FIRST_BOOTH + (PER_HALF - 1) * BOOTH_STEP + BOOTH_HALF + 0.5
local BOOTH_LINE = math.ceil((OUTER_EDGE + 14) / 2) * 2 -- stand sirasinin merkezden uzakligi (komsu kenarin on yuzune girmez)
local PLAZA_HALF = BOOTH_LINE + 18 -- meydanin yari boyutu (6 stand: 88 ve 106)
local PARK_HALF = 232 -- park (citlik) yari boyutu
local GROUND_HALF = 560 -- cimen zemin yari boyutu (tepeler dahil)

local TAU = math.pi * 2
local rng = Random.new(SEED)
local RGB = Color3.fromRGB
local Mat = Enum.Material

local C = {
	grass = RGB(104, 172, 74),
	grassLight = RGB(126, 190, 88),
	grassDark = RGB(80, 148, 62),
	hedge = RGB(58, 124, 52),
	leafA = RGB(86, 164, 66),
	leafB = RGB(106, 180, 74),
	leafC = RGB(66, 142, 58),
	trunk = RGB(112, 78, 50),
	woodLight = RGB(190, 144, 94),
	woodMid = RGB(160, 114, 74),
	woodDark = RGB(118, 82, 52),
	sign = RGB(228, 194, 140),
	awningGreen = RGB(86, 160, 72),
	cream = RGB(246, 240, 222),
	plaza = RGB(212, 204, 186),
	plazaLine = RGB(190, 182, 164),
	medallion = RGB(224, 217, 200),
	curb = RGB(172, 166, 154),
	stone = RGB(190, 184, 168),
	soil = RGB(92, 64, 44),
	metal = RGB(56, 60, 66),
	water = RGB(118, 196, 238),
	lamp = RGB(255, 240, 190),
	white = RGB(244, 247, 250),
}
local FLOWERS = { RGB(255, 128, 170), RGB(255, 224, 90), RGB(250, 250, 250), RGB(235, 80, 80), RGB(180, 120, 230) }

local DECO = { solid = false, shadow = false } -- carpisma ve golge yok (ince susler)
local SOFT = { solid = false } -- golge var, carpisma yok (yapraklar, tente)

local oldMap = Workspace:FindFirstChild("Map")
if oldMap then
	oldMap:Destroy()
end
for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("SpawnLocation") or child.Name == "Baseplate" then
		child:Destroy()
	end
end
for _, child in ipairs(Lighting:GetChildren()) do
	if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("BloomEffect") or child:IsA("ColorCorrectionEffect")
		or child:IsA("DepthOfFieldEffect") or child:IsA("SunRaysEffect") then
		child:Destroy()
	end
end
local terrain = Workspace:FindFirstChildOfClass("Terrain")
if terrain then
	for _, child in ipairs(terrain:GetChildren()) do
		if child:IsA("Clouds") then
			child:Destroy()
		end
	end
end

local boothFolder = Workspace:FindFirstChild(BOOTH_FOLDER_NAME)
if boothFolder then
	boothFolder:ClearAllChildren()
else
	boothFolder = Instance.new("Folder")
	boothFolder.Name = BOOTH_FOLDER_NAME
	boothFolder.Parent = Workspace
end

local map = Instance.new("Folder")
map.Name = "Map"
local function subfolder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = map
	return f
end
local groundF = subfolder("Ground")
local plazaF = subfolder("Plaza")
local decorF = subfolder("Decor")
local treesF = subfolder("Trees")
local sceneryF = subfolder("Scenery")

local function newPart(name, size, cf, color, material, o, shape)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if LOCK_PARTS then
		p.Locked = true
	end
	if o.transparency then
		p.Transparency = o.transparency
	end
	if o.reflectance then
		p.Reflectance = o.reflectance
	end
	if o.solid == false then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
	end
	if o.shadow == false or (material == Mat.Neon and o.shadow ~= true) then
		p.CastShadow = false
	end
	return p
end

local function part(parent, name, size, cf, color, material, o)
	local p = newPart(name, size, cf, color, material, o)
	p.Parent = parent
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function cyl(parent, name, diameter, height, cf, color, material, o)
	local p = newPart(name, Vector3.new(height, diameter, diameter), cf * UPRIGHT, color, material, o, Enum.PartType.Cylinder)
	p.Parent = parent
	return p
end

local function ball(parent, name, diameter, cf, color, material, o)
	local p = newPart(name, Vector3.new(diameter, diameter, diameter), cf, color, material, o, Enum.PartType.Ball)
	p.Parent = parent
	return p
end

local function ellipsoid(parent, name, size, cf, color, material, o)
	local p = newPart(name, size, cf, color, material, o)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = parent
	return p
end

local function anchorPart(parent, name, size, cf)
	return part(parent, name, size, cf, C.white, Mat.SmoothPlastic, { transparency = 1, solid = false, shadow = false })
end

local function tag(inst, tagName, attrs)
	CollectionService:AddTag(inst, tagName)
	if attrs then
		for k, v in pairs(attrs) do
			inst:SetAttribute(k, v)
		end
	end
end

local function ringSegments(parent, name, base, radius, count, radial, height, color, material, o)
	local chord = 2 * radius * math.sin(math.pi / count) * 1.06
	for k = 0, count - 1 do
		local a = k / count * TAU
		local lc = CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius) * CFrame.Angles(0, -a, 0)
		part(parent, name, Vector3.new(radial, height, chord), base * lc, color, material, o)
	end
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function sideRot(side)
	return CFrame.Angles(0, math.rad(90 * side), 0)
end

local PLAZA_TOP = 0.12

local function buildGround()
	part(groundF, "Grass", Vector3.new(GROUND_HALF * 2, 2, GROUND_HALF * 2), CFrame.new(0, -1, 0), C.grass, Mat.Grass)
	local placed = 0
	local tries = 0
	while placed < 26 and tries < 400 do
		tries = tries + 1
		local x = rng:NextNumber(-PARK_HALF + 20, PARK_HALF - 20)
		local z = rng:NextNumber(-PARK_HALF + 20, PARK_HALF - 20)
		local d = rng:NextNumber(16, 44)
		if math.max(math.abs(x), math.abs(z)) > PLAZA_HALF + d / 2 + 2 and math.min(math.abs(x), math.abs(z)) > PATH_HALF + d / 2 + 2 then
			placed = placed + 1
			local color = (placed % 2 == 0) and C.grassLight or C.grassDark
			cyl(groundF, "GrassPatch", d, 0.1, CFrame.new(x, 0.05, z), color, Mat.Grass, DECO)
		end
	end
end

local function buildPlaza()
	local size = PLAZA_HALF * 2
	part(plazaF, "PlazaFloor", Vector3.new(size, 0.4, size), CFrame.new(0, PLAZA_TOP - 0.2, 0), C.plaza, Mat.Concrete)

	local lines = math.floor(PLAZA_HALF / 12)
	for k = -lines, lines do
		local c = k * 12
		part(plazaF, "TileLine", Vector3.new(size, 0.06, 0.3), CFrame.new(0, PLAZA_TOP + 0.03, c), C.plazaLine, Mat.Concrete, DECO)
		part(plazaF, "TileLine", Vector3.new(0.3, 0.06, size), CFrame.new(c, PLAZA_TOP + 0.03, 0), C.plazaLine, Mat.Concrete, DECO)
	end

	cyl(plazaF, "Medallion", 60, 0.08, CFrame.new(0, PLAZA_TOP + 0.04, 0), C.medallion, Mat.Concrete, DECO)
	ringSegments(plazaF, "MedallionRing", CFrame.new(0, PLAZA_TOP + 0.08, 0), 30, 44, 0.6, 0.08, C.curb, Mat.Concrete, DECO)
	ringSegments(plazaF, "MedallionRing", CFrame.new(0, PLAZA_TOP + 0.08, 0), 17, 28, 0.5, 0.08, C.curb, Mat.Concrete, DECO)

	local pathLen = PARK_HALF - 14 - PLAZA_HALF
	for side = 0, 3 do
		local rot = sideRot(side)
		part(plazaF, "Path", Vector3.new(PATH_HALF * 2, 0.4, pathLen), rot * CFrame.new(0, PLAZA_TOP - 0.2, -(PLAZA_HALF + pathLen / 2)), C.plaza, Mat.Concrete)
		local len = PLAZA_HALF - PATH_HALF
		for _, sx in ipairs({ -1, 1 }) do
			part(plazaF, "Curb", Vector3.new(len, 0.55, 1.2), rot * CFrame.new(sx * (PATH_HALF + len / 2), 0.275, -PLAZA_HALF), C.curb, Mat.Concrete)
		end
	end
end

local function buildFountain()
	local y0 = PLAZA_TOP
	cyl(plazaF, "BasinFloor", 24, 0.5, CFrame.new(0, y0 + 0.25, 0), C.stone, Mat.Concrete)
	ringSegments(plazaF, "BasinWall", CFrame.new(0, y0 + 0.8, 0), 11.4, 32, 1.2, 1.6, C.stone, Mat.Concrete)
	cyl(plazaF, "Water", 21.6, 0.2, CFrame.new(0, y0 + 1.1, 0), C.water, Mat.Glass,
		{ solid = false, shadow = false, transparency = 0.35, reflectance = 0.1 })
	cyl(plazaF, "Pedestal", 5, 2.6, CFrame.new(0, y0 + 1.8, 0), C.stone, Mat.Concrete)
	cyl(plazaF, "Bowl", 9, 0.5, CFrame.new(0, y0 + 3.35, 0), C.stone, Mat.Concrete)
	cyl(plazaF, "Column", 1.4, 2.6, CFrame.new(0, y0 + 4.9, 0), C.stone, Mat.Concrete)
	ball(plazaF, "Finial", 2.4, CFrame.new(0, y0 + 6.5, 0), C.stone, Mat.Concrete)

	local spray = anchorPart(plazaF, "Spray", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, y0 + 7.8, 0))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(C.white, C.water)
	e.LightEmission = 0.3
	e.Rate = 60
	e.Lifetime = NumberRange.new(1.4, 1.8)
	e.Speed = NumberRange.new(16, 20)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Acceleration = Vector3.new(0, -32, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.3) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = spray
end

local function buildBooth(i, cf)
	local function L(x, y, z)
		return cf * CFrame.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = "Booth_" .. i

	part(model, "Platform", Vector3.new(17, 0.6, 11), L(0, 0.3, 0), C.woodLight, Mat.WoodPlanks)
	part(model, "BackWall", Vector3.new(16, 6.4, 0.6), L(0, 3.8, 4.7), C.woodDark, Mat.WoodPlanks)
	for _, sx in ipairs({ -7.7, 7.7 }) do
		part(model, "SideWall", Vector3.new(0.6, 3.4, 9.4), L(sx, 2.3, 0.1), C.woodDark, Mat.WoodPlanks)
	end
	for _, px in ipairs({ -7.6, 7.6 }) do
		part(model, "Post", Vector3.new(0.8, 4.7, 0.8), L(px, 2.95, -5.2), C.woodMid, Mat.Wood)
	end

	local awning = L(0, 7.0, 4.4) * CFrame.Angles(-math.rad(9), 0, 0)
	for s = 1, 8 do
		part(model, "Awning", Vector3.new(2, 0.3, 10.6), awning * CFrame.new((s - 4.5) * 2, 0, -5.3),
			(s % 2 == 1) and C.awningGreen or C.cream, Mat.Fabric, SOFT)
	end

	part(model, "Counter", Vector3.new(13, 2.5, 1.8), L(0, 1.85, -3.4), C.woodMid, Mat.WoodPlanks)
	part(model, "CounterTop", Vector3.new(13.8, 0.35, 2.6), L(0, 3.275, -3.4), C.woodLight, Mat.WoodPlanks)

	part(model, "SignFrame", Vector3.new(11.6, 2.8, 0.5), L(0, 8.4, 4.75), C.woodDark, Mat.WoodPlanks)
	local board = part(model, "SignBoard", Vector3.new(11, 2.2, 0.2), L(0, 8.4, 4.35), C.sign, Mat.WoodPlanks)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.LightInfluence = 0
	sg.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = RGB(84, 52, 28)
	label.Text = string.format("STAND %02d", i)
	label.Parent = sg
	tag(label, "BoothSign", { BoothNumber = i })

	cyl(model, "EggStand", 2.2, 0.5, L(0, 10.05, 4.75), C.woodDark, Mat.Wood)
	local egg = ellipsoid(model, "Egg", Vector3.new(2.2, 3.0, 2.2), L(0, 12.0, 4.75), C.white, Mat.Neon, DECO)
	tag(egg, "FX_Bob", { BobHeight = 0.2, BobSpeed = 1.2, BobPhase = rng:NextNumber(0, TAU) })

	local base = anchorPart(model, "Base", Vector3.new(1, 1, 1), L(0, 4.4, -3.4))
	model.PrimaryPart = base
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = boothFolder
end

local function buildBooths()
	local offsets = {}
	for j = PER_HALF, 1, -1 do
		table.insert(offsets, -(FIRST_BOOTH + (j - 1) * BOOTH_STEP))
	end
	for j = 1, PER_HALF do
		table.insert(offsets, FIRST_BOOTH + (j - 1) * BOOTH_STEP)
	end
	local i = 0
	for side = 0, 3 do
		local rot = sideRot(side)
		for _, off in ipairs(offsets) do
			i = i + 1
			local pos = rot * Vector3.new(off, 0, -BOOTH_LINE)
			buildBooth(i, CFrame.new(pos) * rot * CFrame.Angles(0, math.pi, 0))
		end
	end
	return i
end

local function bench(cf)
	part(decorF, "BenchSeat", Vector3.new(4.6, 0.4, 1.6), cf * CFrame.new(0, 1.7, 0), C.woodMid, Mat.WoodPlanks)
	part(decorF, "BenchBack", Vector3.new(4.6, 1.3, 0.3), cf * CFrame.new(0, 2.65, 0.7), C.woodMid, Mat.WoodPlanks, SOFT)
	for _, sx in ipairs({ -2, 2 }) do
		part(decorF, "BenchLeg", Vector3.new(0.5, 1.5, 1.4), cf * CFrame.new(sx, 0.75, 0), C.metal, Mat.Metal)
	end
end

local function lamp(x, z)
	local cf = CFrame.new(x, 0, z)
	cyl(decorF, "LampBase", 1.4, 0.5, cf * CFrame.new(0, 0.25, 0), C.metal, Mat.Metal)
	cyl(decorF, "LampPole", 0.5, 7, cf * CFrame.new(0, 3.5, 0), C.metal, Mat.Metal)
	part(decorF, "LampHead", Vector3.new(1.3, 1.6, 1.3), cf * CFrame.new(0, 7.8, 0), C.lamp, Mat.Neon, DECO)
	part(decorF, "LampCap", Vector3.new(1.9, 0.3, 1.9), cf * CFrame.new(0, 8.75, 0), C.metal, Mat.Metal, SOFT)
end

local function flowerBed(x, z)
	local cf = CFrame.new(x, 0, z)
	part(decorF, "BedSoil", Vector3.new(8, 0.5, 8), cf * CFrame.new(0, 0.25, 0), C.soil, Mat.Ground, DECO)
	for _, e in ipairs({ { 0, -4, 9, 1 }, { 0, 4, 9, 1 }, { -4, 0, 1, 9 }, { 4, 0, 1, 9 } }) do
		part(decorF, "BedBorder", Vector3.new(e[3], 0.9, e[4]), cf * CFrame.new(e[1], 0.45, e[2]), C.curb, Mat.Concrete)
	end
	for _ = 1, 26 do
		local fx, fz = rng:NextNumber(-3.2, 3.2), rng:NextNumber(-3.2, 3.2)
		ball(decorF, "Flower", 0.8, cf * CFrame.new(fx, 1.0, fz), pick(FLOWERS), Mat.SmoothPlastic, DECO)
	end
end

local function bush(parent, x, z, s)
	ellipsoid(parent, "Bush", Vector3.new(5 * s, 3.6 * s, 5 * s), CFrame.new(x, 1.5 * s, z), pick({ C.leafA, C.leafB, C.leafC }), Mat.Grass, SOFT)
end

local function tree(parent, x, z, s)
	local h = 9 * s
	local cf = CFrame.new(x, 0, z)
	cyl(parent, "Trunk", 1.8 * s, h, cf * CFrame.new(0, h / 2, 0), C.trunk, Mat.Wood)
	local colors = { C.leafA, C.leafB, C.leafC }
	local k = rng:NextInteger(1, 3)
	ball(parent, "Leaves", 13 * s, cf * CFrame.new(0, h + 3.5 * s, 0), colors[k], Mat.Grass, SOFT)
	ball(parent, "Leaves", 9.5 * s, cf * CFrame.new(3.6 * s, h + 1.5 * s, 1.2 * s), colors[k % 3 + 1], Mat.Grass, SOFT)
	ball(parent, "Leaves", 8.5 * s, cf * CFrame.new(-3.2 * s, h + 2 * s, -1.8 * s), colors[(k + 1) % 3 + 1], Mat.Grass, SOFT)
end

local function buildFurniture()
	local rb, rl, rf = BOOTH_LINE - 38, BOOTH_LINE - 30, BOOTH_LINE - 18

	for k = 0, 7 do
		local a = math.rad(22.5 + 45 * k)
		local pos = Vector3.new(math.cos(a) * rb, 0, math.sin(a) * rb)
		bench(CFrame.lookAt(pos, Vector3.new(0, 0, 0)))
	end
	for k = 0, 3 do
		local a = math.rad(45 + 90 * k)
		lamp(math.cos(a) * rl, math.sin(a) * rl)
		flowerBed(math.cos(a) * rf, math.sin(a) * rf)
	end
	for side = 0, 3 do
		local rot = sideRot(side)
		for _, sx in ipairs({ -1, 1 }) do
			local p = rot * Vector3.new(sx * (PATH_HALF + 2.5), 0, -(PLAZA_HALF - 3))
			lamp(p.X, p.Z)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local x, z = sx * (PLAZA_HALF - 10), sz * (PLAZA_HALF - 10)
			ringSegments(decorF, "TreeRing", CFrame.new(x, 0.3, z), 4.2, 14, 0.8, 0.6, C.curb, Mat.Concrete)
			tree(treesF, x, z, 1.15)
		end
	end

	local t = PLAZA_HALF + 18
	while t < PARK_HALF - 22 do
		for side = 0, 3 do
			local rot = sideRot(side)
			for _, sx in ipairs({ -1, 1 }) do
				local p = rot * Vector3.new(sx * 11, 0, -t)
				lamp(p.X, p.Z)
				local b = rot * Vector3.new(sx * 11, 0, -(t + 18))
				bench(CFrame.lookAt(b, rot * Vector3.new(0, 0, -(t + 18)))) -- bank yola bakar
				local q = rot * Vector3.new(sx * 16, 0, -(t + 9))
				bush(treesF, q.X, q.Z, 1)
			end
		end
		t = t + 36
	end
end

local function buildTrees()
	local placed = {}
	local tries = 0
	while #placed < 64 and tries < 3000 do
		tries = tries + 1
		local x = rng:NextNumber(-PARK_HALF + 14, PARK_HALF - 14)
		local z = rng:NextNumber(-PARK_HALF + 14, PARK_HALF - 14)
		local ax, az = math.abs(x), math.abs(z)
		local ok = math.max(ax, az) >= PLAZA_HALF + 12 and math.min(ax, az) >= 22
		if ok then
			for _, p in ipairs(placed) do
				if (p.x - x) ^ 2 + (p.z - z) ^ 2 < 16 * 16 then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(placed, { x = x, z = z })
			tree(treesF, x, z, rng:NextNumber(0.85, 1.35))
			if rng:NextInteger(1, 3) == 1 then
				bush(treesF, x + rng:NextNumber(-7, 7), z + rng:NextNumber(5, 9), rng:NextNumber(0.8, 1.2))
			end
		end
	end
end

local function buildBoundary()
	for side = 0, 3 do
		local rot = sideRot(side)
		local c = -PARK_HALF + 7
		while c <= PARK_HALF - 7 do
			part(sceneryF, "Hedge", Vector3.new(14.4, 4.4, 3.4), rot * CFrame.new(c, 2.2, -PARK_HALF), C.hedge, Mat.Grass, SOFT)
			c = c + 14
		end
		part(sceneryF, "Barrier", Vector3.new(PARK_HALF * 2 + 12, 60, 2), rot * CFrame.new(0, 30, -(PARK_HALF + 3)), C.white, Mat.SmoothPlastic,
			{ transparency = 1, shadow = false })
	end
end

local function buildHills()
	for k = 0, 13 do
		local a = k / 14 * TAU + rng:NextNumber(-0.12, 0.12)
		local r = rng:NextNumber(380, 520)
		local w = rng:NextNumber(200, 340)
		local h = rng:NextNumber(70, 140)
		ellipsoid(sceneryF, "Hill", Vector3.new(w, h, w * rng:NextNumber(0.7, 1.0)),
			CFrame.new(math.cos(a) * r, -h * 0.1, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			(k % 2 == 0) and C.grassDark or C.grass, Mat.Grass, DECO)
	end
end

local function applyLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.ExposureCompensation = 0
	Lighting.Ambient = RGB(120, 124, 132)
	Lighting.OutdoorAmbient = RGB(150, 160, 175)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true

	local sky = Instance.new("Sky")
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local atm = Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.15
	atm.Color = RGB(199, 220, 255)
	atm.Decay = RGB(110, 140, 200)
	atm.Glare = 0.2
	atm.Haze = 1
	atm.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 24
	bloom.Threshold = 1.2
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.TintColor = RGB(255, 252, 245)
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.8
	rays.Parent = Lighting

	if terrain then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.45
		clouds.Density = 0.5
		clouds.Color = RGB(255, 255, 255)
		clouds.Parent = terrain
	end

	if USE_FUTURE_LIGHTING then
		pcall(function()
			Lighting.Technology = Enum.Technology.Future -- scriptlerden degistirilemez, Command Bar'dan olur
		end)
	end
end

local function buildSpawns()
	for k = 0, 3 do
		local a = math.rad(90 * k)
		local sp = Instance.new("SpawnLocation")
		sp.Name = "Spawn" .. (k + 1)
		sp.Anchored = true
		sp.Size = Vector3.new(8, 0.2, 8)
		sp.CFrame = CFrame.new(math.cos(a) * 26, PLAZA_TOP + 0.1, math.sin(a) * 26)
		sp.Transparency = 1
		sp.CanCollide = false
		sp.Neutral = true
		sp.Duration = 0
		sp.TopSurface = Enum.SurfaceType.Smooth
		sp.BottomSurface = Enum.SurfaceType.Smooth
		sp.Locked = LOCK_PARTS
		sp.Parent = Workspace
	end
end

buildGround()
buildPlaza()
buildFountain()
local boothCount = buildBooths()
buildFurniture()
buildTrees()
buildBoundary()
buildHills()
buildSpawns()
applyLighting()

map.Parent = Workspace
print(string.format("[MapBuilder] Sunny Park hazir: %d stand", boothCount))

local MAPFX_SOURCE = [=[
-- StarterPlayer/StarterPlayerScripts/MapFX  (LocalScript)
--
-- MapBuilder'in isaretledigi (CollectionService tag) nesneleri istemcide gunceller.
-- Hepsi SADECE bu oyuncunun ekraninda olur: sunucuya yuk bindirmez.
--   FX_Bob   : stand yumurtasi yukari-asagi hafifce yuzer (BobHeight, BobSpeed, BobPhase)
--   BoothSign: stand tabelasi; sahipsiz = "STAND 07", sahipli = oyuncunun adi (booth OwnerUserId attribute'u)
--
-- Yuzme her karede baslangic konumundan MUTLAK hesaplanir; sayisal hata birikmez.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- tag'li nesneleri (var olanlar + sonradan akan/gelenler) takip eder
local function watch(tagName, onAdd, onRemove)
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		onAdd(inst)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(onAdd)
	if onRemove then
		CollectionService:GetInstanceRemovedSignal(tagName):Connect(onRemove)
	end
end

---------------------------------------------------------------------
-- Yumurtalar
---------------------------------------------------------------------
local bobbers = {}

watch("FX_Bob", function(inst)
	if bobbers[inst] == nil then
		bobbers[inst] = {
			base = inst.CFrame,
			height = inst:GetAttribute("BobHeight") or 0.3,
			speed = inst:GetAttribute("BobSpeed") or 1,
			phase = inst:GetAttribute("BobPhase") or 0,
		}
	end
end, function(inst)
	bobbers[inst] = nil
end)

RunService.Heartbeat:Connect(function()
	local t = Workspace:GetServerTimeNow()
	for inst, d in pairs(bobbers) do
		if inst.Parent then
			inst.CFrame = d.base + Vector3.new(0, math.sin(t * d.speed + d.phase) * d.height, 0)
		end
	end
end)

---------------------------------------------------------------------
-- Stand tabelalari
---------------------------------------------------------------------
watch("BoothSign", function(label)
	local booth = label:FindFirstAncestorOfClass("Model")
	if not booth then
		return
	end
	local number = label:GetAttribute("BoothNumber") or 0
	local function refresh()
		local ownerId = booth:GetAttribute("OwnerUserId")
		local owner = ownerId and Players:GetPlayerByUserId(ownerId)
		if owner then
			label.Text = owner.Name
		else
			label.Text = string.format("STAND %02d", number)
		end
	end
	refresh()
	booth:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
end)
]=]

do
	local ok, err = pcall(function()
		local container = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts") or game:GetService("StarterGui")
		local old = container:FindFirstChild("MapFX")
		if old then
			old:Destroy()
		end
		local fx = Instance.new("LocalScript")
		fx.Name = "MapFX"
		fx.Source = MAPFX_SOURCE
		fx.Parent = container
	end)
	if ok then
		print("[Kurulum] MapFX kuruldu (StarterPlayerScripts).")
	else
		warn("[Kurulum] MapFX otomatik kurulamadi (" .. tostring(err) .. "). Asagidaki kodu elle bir LocalScript'e yapistir:")
		print(MAPFX_SOURCE)
	end

	local oldBuilder = game:GetService("ServerScriptService"):FindFirstChild("MapBuilder")
	if oldBuilder then
		oldBuilder:Destroy()
		print("[Kurulum] Eski MapBuilder scripti silindi (harita artik kalici).")
	end
end

pcall(function()
	Workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 210, 360), Vector3.new(0, 0, 10))
end)
pcall(function()
	game:GetService("Selection"):Set({ map })
end)
print("[Kurulum] Bitti. Play'e (F5) basip standlara gidebilirsin.")
