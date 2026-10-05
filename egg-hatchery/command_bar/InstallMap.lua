-- ============================================================
-- SUNNY PARK - tek komutla kurulum (Studio Command Bar)
-- 1) Studio'da View > Command Bar'i ac (altta yazi kutusu cikar)
-- 2) Bu dosyanin TAMAMINI kopyala, kutuya yapistir, Enter'a bas
-- 3) Birkac saniye bekle; Output'ta "[Kurulum] Bitti" yazinca hazir
-- Ayarlari (stand sayisi, isik kalitesi, kilit) asagidaki ilk satirlardan degistirip tekrar calistirabilirsin.
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

local PATH_HALF = 8 -- 4 yonlu yolun yari genisligi
local BOOTH_HALF = 8 -- stand yari genisligi
local BOOTH_STEP = 24 -- stand merkezleri arasi mesafe
local FIRST_BOOTH = PATH_HALF + BOOTH_HALF + 1 -- girisin yanindaki ilk standin merkezi
local PER_HALF = BOOTHS_PER_SIDE / 2
local OUTER_EDGE = FIRST_BOOTH + (PER_HALF - 1) * BOOTH_STEP + BOOTH_HALF + 0.5
local BOOTH_LINE = math.ceil((OUTER_EDGE + 14) / 2) * 2 -- stand sirasinin merkezden uzakligi
local PLAZA_HALF = BOOTH_LINE + 18 -- meydanin yari boyutu (6 stand: 88 ve 106)
local PARK_HALF = 232 -- park yari boyutu
local GROUND_HALF = 640 -- arazi yari boyutu (tepeler dahil)

local LAKE = { x = 150, z = 150, r = 30 }
local POND = { x = 150, z = -150, r = 20 }
local STREAM = { { 150, 120 }, { 160, 96 }, { 140, 64 }, { 152, 32 }, { 148, 0 }, { 158, -32 }, { 142, -64 }, { 152, -96 }, { 150, -130 } }
local STREAM_W = 8
local PICNIC = { x = -150, z = 150 }
local GAZEBO = { x = -150, z = -150 }

local TAU = math.pi * 2
local rng = Random.new(SEED)
local RGB = Color3.fromRGB
local Mat = Enum.Material

local C = {
	grass = RGB(98, 164, 68),
	leafA = RGB(86, 164, 66),
	leafB = RGB(106, 180, 74),
	leafC = RGB(66, 142, 58),
	trunk = RGB(112, 78, 50),
	woodLight = RGB(190, 144, 94),
	woodMid = RGB(160, 114, 74),
	woodDark = RGB(118, 82, 52),
	sign = RGB(228, 194, 140),
	cream = RGB(246, 240, 222),
	plaza = RGB(190, 172, 142),
	plazaBand = RGB(150, 136, 114),
	plazaLight = RGB(214, 198, 168),
	curb = RGB(140, 128, 110),
	stone = RGB(176, 166, 148),
	soil = RGB(92, 64, 44),
	metal = RGB(56, 60, 66),
	water = RGB(118, 196, 238),
	lamp = RGB(255, 214, 140),
	white = RGB(244, 247, 250),
	clay = RGB(190, 108, 70),
	gold = RGB(255, 205, 60),
	reed = RGB(112, 150, 62),
	pad = RGB(70, 140, 72),
	birch = RGB(232, 228, 216),
	sand = RGB(222, 200, 150),
}
local ROCKS = { RGB(138, 138, 142), RGB(118, 120, 126), RGB(160, 154, 144), RGB(104, 108, 112) }
local STALL = { RGB(214, 72, 72), RGB(66, 132, 214), RGB(244, 190, 50), RGB(150, 98, 200), RGB(236, 128, 48), RGB(52, 170, 160), RGB(232, 110, 156), RGB(96, 168, 72) }
local FLOWERS = { RGB(255, 128, 170), RGB(255, 224, 90), RGB(250, 250, 250), RGB(235, 80, 80), RGB(180, 120, 230), RGB(255, 150, 60) }
local TREE_KINDS = {
	oak = { RGB(86, 164, 66), RGB(106, 180, 74), RGB(66, 142, 58) },
	birch = { RGB(120, 190, 80), RGB(140, 200, 96) },
	cherry = { RGB(246, 160, 190), RGB(238, 132, 170) },
	maple = { RGB(232, 140, 52), RGB(212, 100, 44) },
}

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
local waterF = subfolder("Water")

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

local function textOn(board, face, text, color)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.LightInfluence = 0
	sg.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = sg
	return label
end

local PLAZA_TOP = 0.12

local reserved = {}
local function reserve(x, z, r)
	table.insert(reserved, { x = x, z = z, r = r })
end
local function isReserved(x, z, pad)
	for _, c in ipairs(reserved) do
		local dx, dz = x - c.x, z - c.z
		local rr = c.r + (pad or 0)
		if dx * dx + dz * dz < rr * rr then
			return true
		end
	end
	return false
end

reserve(LAKE.x, LAKE.z, LAKE.r + 12)
reserve(POND.x, POND.z, POND.r + 12)
reserve(PICNIC.x, PICNIC.z, 26)
reserve(GAZEBO.x, GAZEBO.z, 24)
for k = 1, #STREAM - 1 do
	local a, b = STREAM[k], STREAM[k + 1]
	local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
	for s = 0, math.floor(len / 8) do
		local t = s / math.max(math.floor(len / 8), 1)
		reserve(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, STREAM_W / 2 + 9)
	end
end

local terrainOk = false
local hills = {}
for k = 0, 15 do
	local a = k / 16 * TAU + rng:NextNumber(-0.1, 0.1)
	local radius = rng:NextNumber(90, 170)
	local h = rng:NextNumber(45, 115)
	local foot = math.sqrt(2 * radius * h - h * h) -- tepenin zemindeki yaricapi
	local r = math.max(rng:NextNumber(380, 540), PARK_HALF + 40 + foot) -- parka girmesin
	table.insert(hills, { x = math.cos(a) * r, z = math.sin(a) * r, radius = radius, h = h, foot = foot })
end

local function buildTerrain()
	if not terrain then
		return false
	end
	local ok, err = pcall(function()
		terrain:Clear()
		terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(GROUND_HALF * 2, 16, GROUND_HALF * 2), Mat.Grass)
		for _, h in ipairs(hills) do
			terrain:FillBall(Vector3.new(h.x, h.h - h.radius, h.z), h.radius, Mat.Grass)
		end

		local segs = {}
		for k = 1, #STREAM - 1 do
			local a, b = STREAM[k], STREAM[k + 1]
			local mid = Vector3.new((a[1] + b[1]) / 2, 0, (a[2] + b[2]) / 2)
			local dir = Vector3.new(b[1] - a[1], 0, b[2] - a[2])
			table.insert(segs, { mid = mid, dir = dir, len = dir.Magnitude + 3 })
		end
		local function segCF(s, y)
			local p = Vector3.new(s.mid.X, y, s.mid.Z)
			return CFrame.lookAt(p, p + s.dir)
		end
		local pools = { LAKE, POND }
		for _, pool in ipairs(pools) do
			terrain:FillCylinder(CFrame.new(pool.x, -6, pool.z), 12, pool.r + 5, Mat.Sand)
		end
		for _, s in ipairs(segs) do
			terrain:FillBlock(segCF(s, -6), Vector3.new(STREAM_W + 8, 12, s.len), Mat.Sand)
		end
		for _, pool in ipairs(pools) do
			terrain:FillCylinder(CFrame.new(pool.x, -5, pool.z), 10, pool.r, Mat.Air)
		end
		for _, s in ipairs(segs) do
			terrain:FillBlock(segCF(s, -5), Vector3.new(STREAM_W, 10, s.len), Mat.Air)
		end
		for _, pool in ipairs(pools) do
			terrain:FillCylinder(CFrame.new(pool.x, -5.5, pool.z), 9, pool.r, Mat.Water)
		end
		for _, s in ipairs(segs) do
			terrain:FillBlock(segCF(s, -5.5), Vector3.new(STREAM_W, 9, s.len), Mat.Water)
		end

		pcall(function()
			terrain:SetMaterialColor(Mat.Grass, C.grass)
			terrain:SetMaterialColor(Mat.Sand, C.sand)
			terrain:SetMaterialColor(Mat.Rock, RGB(120, 122, 128))
		end)
		pcall(function()
			terrain.Decoration = true
			terrain.WaterColor = RGB(64, 150, 190)
			terrain.WaterTransparency = 0.85
			terrain.WaterReflectance = 0.5
			terrain.WaterWaveSize = 0.12
			terrain.WaterWaveSpeed = 10
		end)
	end)
	if not ok then
		warn("[MapBuilder] Arazi olusturulamadi (" .. tostring(err) .. "); duz zemin parcasi kullaniliyor.")
	end
	return ok
end

local function buildFallbackGround()
	part(groundF, "Grass", Vector3.new(GROUND_HALF * 2, 2, GROUND_HALF * 2), CFrame.new(0, -1, 0), C.grass, Mat.Grass)
	for _, h in ipairs(hills) do
		ellipsoid(sceneryF, "Hill", Vector3.new(h.foot * 2, h.h * 2, h.foot * 2), CFrame.new(h.x, 0, h.z), C.leafC, Mat.Grass, DECO)
	end
end

local function buildPlaza()
	local size = PLAZA_HALF * 2
	part(plazaF, "PlazaFloor", Vector3.new(size, 0.4, size), CFrame.new(0, PLAZA_TOP - 0.2, 0), C.plaza, Mat.Cobblestone)

	for side = 0, 3 do
		local rot = sideRot(side)
		part(plazaF, "Border", Vector3.new(size, 0.1, 4), rot * CFrame.new(0, PLAZA_TOP + 0.05, -(PLAZA_HALF - 2)), C.plazaBand, Mat.Slate, DECO)
		part(plazaF, "BorderLine", Vector3.new(size - 8, 0.12, 0.8), rot * CFrame.new(0, PLAZA_TOP + 0.06, -(PLAZA_HALF - 5.2)), C.plazaLight, Mat.Slate, DECO)
	end

	cyl(plazaF, "Medallion", 60, 0.08, CFrame.new(0, PLAZA_TOP + 0.04, 0), C.plazaLight, Mat.Slate, DECO)
	ringSegments(plazaF, "MedallionRing", CFrame.new(0, PLAZA_TOP + 0.08, 0), 30, 44, 0.8, 0.08, C.plazaBand, Mat.Slate, DECO)
	ringSegments(plazaF, "MedallionRing", CFrame.new(0, PLAZA_TOP + 0.08, 0), 17, 28, 0.6, 0.08, C.plazaBand, Mat.Slate, DECO)
	for k = 0, 15 do
		local a = k / 16 * TAU
		part(plazaF, "Spoke", Vector3.new(13, 0.08, 0.5), CFrame.new(math.cos(a) * 23.5, PLAZA_TOP + 0.08, math.sin(a) * 23.5) * CFrame.Angles(0, -a, 0),
			C.plazaBand, Mat.Slate, DECO)
	end

	local gapC, gapH = STREAM[5][1], 13
	for side = 0, 3 do
		local rot = sideRot(side)
		local spans = { { PLAZA_HALF, PARK_HALF - 14 } }
		if side == 3 then
			spans = { { PLAZA_HALF, gapC - gapH }, { gapC + gapH, PARK_HALF - 14 } }
		end
		for _, sp in ipairs(spans) do
			local len, mid = sp[2] - sp[1], (sp[1] + sp[2]) / 2
			part(plazaF, "Path", Vector3.new(PATH_HALF * 2, 0.4, len), rot * CFrame.new(0, PLAZA_TOP - 0.2, -mid), C.plaza, Mat.Cobblestone)
			for _, sx in ipairs({ -1, 1 }) do
				part(plazaF, "PathEdge", Vector3.new(0.7, 0.2, len), rot * CFrame.new(sx * (PATH_HALF + 0.35), 0.1, -mid), C.curb, Mat.Slate, DECO)
			end
		end
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
	ringSegments(plazaF, "BasinCap", CFrame.new(0, y0 + 1.72, 0), 11.4, 32, 1.7, 0.2, C.plazaLight, Mat.Concrete)
	cyl(plazaF, "Water", 21.6, 0.2, CFrame.new(0, y0 + 1.1, 0), C.water, Mat.Glass,
		{ solid = false, shadow = false, transparency = 0.35, reflectance = 0.1 })
	cyl(plazaF, "Pedestal", 5, 2.6, CFrame.new(0, y0 + 1.8, 0), C.stone, Mat.Concrete)
	cyl(plazaF, "Bowl", 9, 0.5, CFrame.new(0, y0 + 3.35, 0), C.stone, Mat.Concrete)
	cyl(plazaF, "Column", 1.4, 2.6, CFrame.new(0, y0 + 4.9, 0), C.stone, Mat.Concrete)
	ball(plazaF, "Finial", 2.4, CFrame.new(0, y0 + 6.5, 0), C.stone, Mat.Concrete)

	local function emitter(parent, rate, speed, spread, dir)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(C.white, C.water)
		e.LightEmission = 0.3
		e.Rate = rate
		e.Lifetime = NumberRange.new(1.2, 1.7)
		e.Speed = NumberRange.new(speed, speed + 4)
		e.SpreadAngle = Vector2.new(spread, spread)
		e.Acceleration = Vector3.new(0, -32, 0)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.3) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		if dir then
			e.EmissionDirection = dir
		end
		e.Parent = parent
	end
	emitter(anchorPart(plazaF, "Spray", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, y0 + 7.8, 0)), 60, 16, 10)
	for k = 0, 7 do
		local a = k / 8 * TAU
		local pos = Vector3.new(math.cos(a) * 3.6, y0 + 3.8, math.sin(a) * 3.6)
		local out = Vector3.new(math.cos(a) * 0.8, 0.9, math.sin(a) * 0.8)
		emitter(anchorPart(plazaF, "Jet", Vector3.new(0.4, 0.4, 0.4), CFrame.lookAt(pos, pos + out)), 22, 10, 5, Enum.NormalId.Front)
	end
end

local function buildBooth(i, cf)
	local ac = STALL[(i * 3) % #STALL + 1]
	local function L(x, y, z)
		return cf * CFrame.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = "Booth_" .. i

	part(model, "Platform", Vector3.new(17, 0.6, 11), L(0, 0.3, 0), C.woodLight, Mat.WoodPlanks)
	part(model, "Step", Vector3.new(13.8, 0.3, 1.4), L(0, 0.15, -6.2), C.woodMid, Mat.WoodPlanks)
	part(model, "BackWall", Vector3.new(16, 8.0, 0.6), L(0, 4.6, 4.7), C.woodDark, Mat.WoodPlanks)
	part(model, "BackTrim", Vector3.new(16.4, 0.5, 0.8), L(0, 0.85, 4.6), C.woodMid, Mat.WoodPlanks)
	for _, sx in ipairs({ -7.7, 7.7 }) do
		part(model, "SideWall", Vector3.new(0.6, 6.4, 9.4), L(sx, 3.8, 0.1), C.woodDark, Mat.WoodPlanks)
	end
	for _, px in ipairs({ -7.6, 7.6 }) do
		part(model, "Post", Vector3.new(0.9, 11.7, 0.9), L(px, 6.15, -5.2), C.woodMid, Mat.Wood)
	end

	local awning = L(0, 8.2, 4.4) * CFrame.Angles(-math.rad(9), 0, 0)
	for s = 1, 8 do
		local c = (s % 2 == 1) and ac or C.cream
		part(model, "Awning", Vector3.new(2, 0.3, 10.6), awning * CFrame.new((s - 4.5) * 2, 0, -5.3), c, Mat.Fabric, SOFT)
		part(model, "Valance", Vector3.new(2, 0.9, 0.25), awning * CFrame.new((s - 4.5) * 2, -0.55, -10.6), c, Mat.Fabric, SOFT)
	end
	for k = 0, 6 do
		ball(model, "Bulb", 0.5, L((k - 3) * 2, 5.75, -6.3), C.lamp, Mat.Neon, DECO)
	end

	part(model, "Counter", Vector3.new(13, 2.5, 1.8), L(0, 1.85, -3.4), C.woodMid, Mat.WoodPlanks)
	part(model, "CounterTop", Vector3.new(13.8, 0.35, 2.6), L(0, 3.275, -3.4), C.woodLight, Mat.WoodPlanks)
	for k = -2, 2 do
		part(model, "CounterSlat", Vector3.new(0.5, 2.1, 0.15), L(k * 2.4, 1.85, -4.35), ac, Mat.WoodPlanks)
	end
	for _, bx in ipairs({ -4.4, 4.4 }) do
		part(model, "Basket", Vector3.new(2.2, 0.9, 1.4), L(bx, 3.9, -3.4), C.woodDark, Mat.Wood, DECO)
		for f = 0, 3 do
			ball(model, "Fruit", 0.7, L(bx + (f % 2 - 0.5) * 0.9, 4.5, -3.4 + (math.floor(f / 2) - 0.5) * 0.5),
				(f % 2 == 0) and ac or RGB(250, 210, 70), Mat.SmoothPlastic, DECO)
		end
	end
	cyl(model, "Jar", 1.1, 1.5, L(0, 4.2, -3.4), C.white, Mat.Glass, { solid = false, shadow = false, transparency = 0.5 })
	for c = 0, 2 do
		cyl(model, "Coin", 0.7, 0.12, L(0, 3.6 + c * 0.16, -3.4), C.gold, Mat.Metal, DECO)
	end
	cyl(model, "JarLid", 1.2, 0.2, L(0, 5.0, -3.4), C.woodDark, Mat.Wood, DECO)

	part(model, "SignFrame", Vector3.new(14.2, 3.2, 0.6), L(0, 10.4, -5.2), C.woodDark, Mat.WoodPlanks)
	part(model, "SignCrown", Vector3.new(14.6, 0.5, 0.8), L(0, 12.15, -5.2), ac, Mat.WoodPlanks)
	local board = part(model, "SignBoard", Vector3.new(13.4, 2.6, 0.2), L(0, 10.4, -5.55), C.sign, Mat.WoodPlanks)
	local label = textOn(board, Enum.NormalId.Front, string.format("STAND %02d", i), RGB(84, 52, 28))
	tag(label, "BoothSign", { BoothNumber = i })

	for k = 0, 8 do
		local x = (k - 4) * 1.35
		local sag = -0.35 * (1 - (x / 6.2) ^ 2)
		part(model, "Pennant", Vector3.new(0.85, 0.85, 0.12), L(x, 8.0 + sag, -5.78) * CFrame.Angles(0, 0, math.rad(45)),
			(k % 2 == 0) and ac or C.cream, Mat.Fabric, DECO)
	end

	for _, px in ipairs({ -6.4, 6.4 }) do
		cyl(model, "Pot", 1.7, 1.4, L(px, 0.82, -8.0), C.clay, Mat.Slate)
		ball(model, "PotLeaves", 1.9, L(px, 1.95, -8.0), C.leafB, Mat.Grass, DECO)
		for f = 0, 3 do
			local a = f / 4 * TAU
			ball(model, "PotFlower", 0.55, L(px + math.cos(a) * 0.55, 2.55, -8.0 + math.sin(a) * 0.55), (f % 2 == 0) and ac or RGB(250, 215, 80), Mat.SmoothPlastic, DECO)
		end
	end

	cyl(model, "EggStand", 2.8, 0.5, L(0, 12.65, -5.2), C.woodDark, Mat.Wood)
	local egg = ellipsoid(model, "Egg", Vector3.new(2.6, 3.6, 2.6), L(0, 14.75, -5.2), C.white, Mat.Neon, DECO)
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

local function bin(x, z)
	cyl(decorF, "Bin", 1.6, 2.2, CFrame.new(x, 1.1, z), RGB(70, 110, 80), Mat.Metal)
	cyl(decorF, "BinLid", 1.8, 0.25, CFrame.new(x, 2.3, z), C.metal, Mat.Metal, SOFT)
end

local function flowerBed(x, z, n)
	local cf = CFrame.new(x, 0, z)
	part(decorF, "BedSoil", Vector3.new(8, 0.5, 8), cf * CFrame.new(0, 0.25, 0), C.soil, Mat.Ground, DECO)
	for _, e in ipairs({ { 0, -4, 9, 1 }, { 0, 4, 9, 1 }, { -4, 0, 1, 9 }, { 4, 0, 1, 9 } }) do
		part(decorF, "BedBorder", Vector3.new(e[3], 0.9, e[4]), cf * CFrame.new(e[1], 0.45, e[2]), C.curb, Mat.Concrete)
	end
	for _ = 1, n or 24 do
		local fx, fz = rng:NextNumber(-3.2, 3.2), rng:NextNumber(-3.2, 3.2)
		ball(decorF, "Flower", 0.8, cf * CFrame.new(fx, 1.0, fz), pick(FLOWERS), Mat.SmoothPlastic, DECO)
	end
end

local function bush(parent, x, z, s)
	ellipsoid(parent, "Bush", Vector3.new(5 * s, 3.6 * s, 5 * s), CFrame.new(x, 1.5 * s, z), pick(TREE_KINDS.oak), Mat.Grass, SOFT)
end

local function tree(parent, x, z, s, kind)
	kind = kind or "oak"
	local cols = TREE_KINDS[kind]
	local h = 9 * s
	local cf = CFrame.new(x, 0, z)
	cyl(parent, "Trunk", (kind == "birch" and 1.1 or 1.8) * s, h, cf * CFrame.new(0, h / 2, 0), (kind == "birch") and C.birch or C.trunk, Mat.Wood)
	local k = rng:NextInteger(1, #cols)
	ball(parent, "Leaves", 13 * s, cf * CFrame.new(0, h + 3.5 * s, 0), cols[k], Mat.Grass, SOFT)
	ball(parent, "Leaves", 9.5 * s, cf * CFrame.new(3.6 * s, h + 1.5 * s, 1.2 * s), cols[k % #cols + 1], Mat.Grass, SOFT)
	ball(parent, "Leaves", 8.5 * s, cf * CFrame.new(-3.2 * s, h + 2 * s, -1.8 * s), cols[(k + 1) % #cols + 1], Mat.Grass, SOFT)
end

local function pickKind()
	local r = rng:NextInteger(1, 100)
	if r <= 58 then
		return "oak"
	elseif r <= 78 then
		return "birch"
	elseif r <= 90 then
		return "cherry"
	end
	return "maple"
end

local function signpost(x, z, yaw, text)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	cyl(decorF, "SignPole", 0.45, 5.4, cf * CFrame.new(0, 2.7, 0), C.woodDark, Mat.Wood)
	local board = part(decorF, "SignPlank", Vector3.new(6.4, 1.5, 0.3), cf * CFrame.new(0, 4.4, 0), C.sign, Mat.WoodPlanks, SOFT)
	textOn(board, Enum.NormalId.Front, text, RGB(84, 52, 28))
	textOn(board, Enum.NormalId.Back, text, RGB(84, 52, 28))
end

local function buildFurniture()
	local rb, rl, rf = BOOTH_LINE - 38, BOOTH_LINE - 30, BOOTH_LINE - 18

	for k = 0, 7 do
		local a = math.rad(22.5 + 45 * k)
		bench(CFrame.lookAt(Vector3.new(math.cos(a) * rb, 0, math.sin(a) * rb), Vector3.new(0, 0, 0)))
		local bp = Vector3.new(math.cos(a) * (rb + 4), 0, math.sin(a) * (rb + 4))
		bin(bp.X + 2.6 * math.sin(a), bp.Z - 2.6 * math.cos(a))
	end
	for k = 0, 7 do
		local a = k / 8 * TAU
		local x, z = math.cos(a) * 38, math.sin(a) * 38
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, -a, 0)
		part(decorF, "PlanterBox", Vector3.new(4.5, 1.1, 4.5), cf * CFrame.new(0, 0.55, 0), C.woodDark, Mat.WoodPlanks)
		part(decorF, "PlanterSoil", Vector3.new(3.9, 0.2, 3.9), cf * CFrame.new(0, 1.15, 0), C.soil, Mat.Ground, DECO)
		for _ = 1, 8 do
			ball(decorF, "Flower", 0.7, cf * CFrame.new(rng:NextNumber(-1.6, 1.6), 1.5, rng:NextNumber(-1.6, 1.6)), pick(FLOWERS), Mat.SmoothPlastic, DECO)
		end
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
		local rot0 = rot
		for _, sx in ipairs({ -1, 1 }) do
			part(decorF, "GatePillar", Vector3.new(2.2, 9, 2.2), rot0 * CFrame.new(sx * 9.6, 4.5, -(PLAZA_HALF + 4)), C.stone, Mat.Concrete)
			part(decorF, "GatePillarCap", Vector3.new(3, 0.6, 3), rot0 * CFrame.new(sx * 9.6, 9.3, -(PLAZA_HALF + 4)), C.curb, Mat.Concrete)
		end
		part(decorF, "GateBeam", Vector3.new(22, 1.8, 1.4), rot0 * CFrame.new(0, 10.2, -(PLAZA_HALF + 4)), C.woodDark, Mat.WoodPlanks, { solid = false })
		local plank = part(decorF, "GateSign", Vector3.new(11, 1.3, 1.6), rot0 * CFrame.new(0, 10.2, -(PLAZA_HALF + 4)), C.sign, Mat.WoodPlanks,
			{ solid = false, shadow = false })
		textOn(plank, Enum.NormalId.Front, "WELCOME", RGB(84, 52, 28))
		textOn(plank, Enum.NormalId.Back, "WELCOME", RGB(84, 52, 28))
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local x, z = sx * (PLAZA_HALF - 10), sz * (PLAZA_HALF - 10)
			ringSegments(decorF, "TreeRing", CFrame.new(x, 0.3, z), 4.2, 14, 0.8, 0.6, C.curb, Mat.Concrete)
			tree(treesF, x, z, 1.15, "cherry")
		end
	end

	local t = PLAZA_HALF + 18
	while t < PARK_HALF - 22 do
		for side = 0, 3 do
			local rot = sideRot(side)
			for _, sx in ipairs({ -1, 1 }) do
				local p = rot * Vector3.new(sx * 11, 0, -t)
				if not isReserved(p.X, p.Z, 1) then
					lamp(p.X, p.Z)
				end
				local b = rot * Vector3.new(sx * 11, 0, -(t + 18))
				if not isReserved(b.X, b.Z, 1) then
					bench(CFrame.lookAt(b, rot * Vector3.new(0, 0, -(t + 18)))) -- bank yola bakar
					bin(b.X + sx * 3.4, b.Z + 0.6)
				end
				local q = rot * Vector3.new(sx * 16, 0, -(t + 9))
				if not isReserved(q.X, q.Z, 1) then
					bush(treesF, q.X, q.Z, 1)
				end
			end
		end
		t = t + 36
	end
end

local function flowerClump(x, z, color, n)
	for _ = 1, n do
		local fx, fz = x + rng:NextNumber(-2.4, 2.4), z + rng:NextNumber(-2.4, 2.4)
		cyl(decorF, "Stem", 0.14, 0.9, CFrame.new(fx, 0.5, fz), C.leafC, Mat.Grass, DECO)
		ball(decorF, "Bloom", 0.65, CFrame.new(fx, 1.05, fz), color, Mat.SmoothPlastic, DECO)
	end
end

local function boulder(parent, x, z, s)
	local sx, sy, sz = s * rng:NextNumber(0.9, 1.4), s * rng:NextNumber(0.6, 1.0), s * rng:NextNumber(0.9, 1.3)
	ellipsoid(parent, "Rock", Vector3.new(sx, sy, sz), CFrame.new(x, sy * 0.28, z) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), pick(ROCKS), Mat.Slate, DECO)
end

local function trail(sx, sz, ex, ez)
	local dx, dz = ex - sx, ez - sz
	local len = math.sqrt(dx * dx + dz * dz)
	local px, pz = -dz / len, dx / len
	local n = math.floor(len / 3.4)
	for k = 0, n do
		local t = k / n
		local wiggle = math.sin(t * math.pi * 2.5) * 5 * math.sin(t * math.pi) ^ 0.5
		local x = sx + dx * t + px * wiggle + rng:NextNumber(-0.35, 0.35)
		local z = sz + dz * t + pz * wiggle + rng:NextNumber(-0.35, 0.35)
		local d = rng:NextNumber(2.0, 2.8)
		cyl(decorF, "StepStone", d, 0.16, CFrame.new(x, 0.08, z) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), pick(ROCKS), Mat.Slate, DECO)
		if k % 3 == 0 then
			reserve(x, z, 6)
		end
	end
end

local function buildPaths()
	trail(12, 151, LAKE.x - LAKE.r - 8, 150)
	trail(12, -151, POND.x - POND.r - 6, -150)
	trail(-12, 151, PICNIC.x + 22, 150)
	trail(-12, -151, GAZEBO.x + 22, -150)
end

local function buildLakeSide()
	local x0 = LAKE.x - LAKE.r - 5
	for k = 0, 13 do
		part(waterF, "DockPlank", Vector3.new(1.6, 0.3, 5.2), CFrame.new(x0 + k * 1.7, 0.55, LAKE.z), C.woodLight, Mat.WoodPlanks, { solid = true })
	end
	for k = 0, 6 do
		for _, sz in ipairs({ -2.5, 2.5 }) do
			cyl(waterF, "DockPost", 0.6, 3.4, CFrame.new(x0 + k * 3.4, -0.3, LAKE.z + sz), C.woodDark, Mat.Wood)
		end
	end
	signpost(x0 - 4, LAKE.z + 6, math.rad(90), "LAKE")

	local bx = STREAM[5][1]
	part(waterF, "BridgeDeck", Vector3.new(26, 0.4, 15.6), CFrame.new(bx, 0.4, 0), C.woodLight, Mat.WoodPlanks)
	for _, sz in ipairs({ -7.6, 7.6 }) do
		part(waterF, "BridgeRailTop", Vector3.new(26, 0.35, 0.4), CFrame.new(bx, 2.2, sz), C.woodMid, Mat.Wood)
		part(waterF, "BridgeRailMid", Vector3.new(26, 0.3, 0.3), CFrame.new(bx, 1.35, sz), C.woodMid, Mat.Wood, SOFT)
		for k = -2, 2 do
			part(waterF, "BridgePost", Vector3.new(0.6, 2.1, 0.6), CFrame.new(bx + k * 5.5, 1.3, sz), C.woodDark, Mat.Wood)
		end
	end

	local function waterEdge(pool, count, rocks)
		for k = 0, count - 1 do
			local a = k / count * TAU + rng:NextNumber(-0.1, 0.1)
			local rr = pool.r - 1
			local cx, cz = pool.x + math.cos(a) * rr, pool.z + math.sin(a) * rr
			for _ = 1, 4 do
				local rx, rz = cx + rng:NextNumber(-1.2, 1.2), cz + rng:NextNumber(-1.2, 1.2)
				cyl(waterF, "Reed", 0.22, rng:NextNumber(2.4, 3.6), CFrame.new(rx, 0.7, rz), C.reed, Mat.Grass, DECO)
			end
		end
		for _ = 1, rocks do
			local a = rng:NextNumber(0, TAU)
			local rr = pool.r + rng:NextNumber(2, 6)
			boulder(waterF, pool.x + math.cos(a) * rr, pool.z + math.sin(a) * rr, rng:NextNumber(1.6, 3.4))
		end
		for _ = 1, 12 do
			local a, rr = rng:NextNumber(0, TAU), rng:NextNumber(3, pool.r - 4)
			local px, pz = pool.x + math.cos(a) * rr, pool.z + math.sin(a) * rr
			cyl(waterF, "LilyPad", rng:NextNumber(1.8, 2.6), 0.1, CFrame.new(px, -0.9, pz), C.pad, Mat.Grass, DECO)
			if rng:NextInteger(1, 3) == 1 then
				ball(waterF, "LilyFlower", 0.7, CFrame.new(px, -0.6, pz), RGB(255, 170, 200), Mat.SmoothPlastic, DECO)
			end
		end
	end
	waterEdge(LAKE, 14, 14)
	waterEdge(POND, 10, 10)
	signpost(POND.x - POND.r - 14, POND.z + 8, math.rad(90), "POND")
	for k = 1, #STREAM, 2 do
		local s = STREAM[k]
		for _, side in ipairs({ -1, 1 }) do
			if math.abs(s[2]) > 14 then
				boulder(waterF, s[1] + side * (STREAM_W / 2 + 6), s[2] + rng:NextNumber(-3, 3), rng:NextNumber(1.4, 2.6))
			end
		end
	end
end

local function buildPicnic()
	local cx, cz = PICNIC.x, PICNIC.z
	local blanketColors = { RGB(214, 72, 72), RGB(66, 132, 214), RGB(244, 190, 50), RGB(96, 168, 72) }
	for k = 0, 3 do
		local a = k / 4 * TAU + 0.4
		local x, z = cx + math.cos(a) * 11, cz + math.sin(a) * 11
		local ang = rng:NextNumber(0, TAU)
		local bc = blanketColors[k + 1]
		part(decorF, "Blanket", Vector3.new(7, 0.1, 7), CFrame.new(x, 0.08, z) * CFrame.Angles(0, ang, 0), bc, Mat.Fabric, DECO)
		part(decorF, "BlanketStripe", Vector3.new(7.05, 0.12, 1.4), CFrame.new(x, 0.1, z) * CFrame.Angles(0, ang, 0), C.cream, Mat.Fabric, DECO)
		part(decorF, "PicnicBasket", Vector3.new(1.8, 1.2, 1.2), CFrame.new(x, 0.7, z) * CFrame.Angles(0, ang, 0), C.woodDark, Mat.Wood, DECO)
	end
	for k = 0, 2 do
		local a = k / 3 * TAU + 1.2
		local cf = CFrame.new(cx + math.cos(a) * 3, 0, cz + math.sin(a) * 3) * CFrame.Angles(0, -a, 0)
		part(decorF, "TableTop", Vector3.new(6, 0.4, 3), cf * CFrame.new(0, 2.6, 0), C.woodLight, Mat.WoodPlanks)
		for _, sz in ipairs({ -2.4, 2.4 }) do
			part(decorF, "TableBench", Vector3.new(6, 0.35, 1.1), cf * CFrame.new(0, 1.55, sz), C.woodMid, Mat.WoodPlanks)
		end
		for _, sx in ipairs({ -2.3, 2.3 }) do
			part(decorF, "TableLeg", Vector3.new(0.5, 2.4, 4.6), cf * CFrame.new(sx, 1.2, 0), C.woodDark, Mat.Wood)
		end
	end
	signpost(cx + 24, cz + 8, math.rad(-90), "PICNIC")
	for k = 1, 5 do
		local a = k / 5 * TAU
		flowerClump(cx + math.cos(a) * 20, cz + math.sin(a) * 20, FLOWERS[k], 7)
	end
end

local function buildGazebo()
	local cx, cz = GAZEBO.x, GAZEBO.z
	cyl(decorF, "GazeboFloor", 16, 0.5, CFrame.new(cx, 0.25, cz), C.woodLight, Mat.WoodPlanks)
	for k = 0, 7 do
		local a = k / 8 * TAU
		cyl(decorF, "GazeboPost", 0.7, 7, CFrame.new(cx + math.cos(a) * 7, 4, cz + math.sin(a) * 7), C.cream, Mat.Wood)
	end
	cyl(decorF, "GazeboRing", 15.6, 0.6, CFrame.new(cx, 7.7, cz), C.woodDark, Mat.WoodPlanks)
	cyl(decorF, "GazeboRoof", 18, 0.5, CFrame.new(cx, 8.2, cz), STALL[8], Mat.Fabric, SOFT)
	cyl(decorF, "GazeboRoof", 13, 0.5, CFrame.new(cx, 8.7, cz), STALL[1], Mat.Fabric, SOFT)
	cyl(decorF, "GazeboRoof", 8, 0.5, CFrame.new(cx, 9.2, cz), STALL[3], Mat.Fabric, SOFT)
	ball(decorF, "GazeboTop", 1.6, CFrame.new(cx, 10.2, cz), C.gold, Mat.Metal, SOFT)
	for _, ang in ipairs({ 0.5, 2.6, 4.7 }) do
		bench(CFrame.lookAt(Vector3.new(cx + math.cos(ang) * 4.6, 0.5, cz + math.sin(ang) * 4.6), Vector3.new(cx, 0.5, cz)))
	end
	signpost(cx + 24, cz - 8, math.rad(-90), "GAZEBO")
	for k = 1, 6 do
		local a = k / 6 * TAU + 0.3
		flowerClump(cx + math.cos(a) * 20, cz + math.sin(a) * 20, FLOWERS[k], 8)
	end
	flowerBed(cx + 14, cz + 14, 18)
	flowerBed(cx - 14, cz - 14, 18)
end

local function buildTrees()
	local placed = {}
	local tries = 0
	while #placed < 70 and tries < 4000 do
		tries = tries + 1
		local x = rng:NextNumber(-PARK_HALF + 14, PARK_HALF - 14)
		local z = rng:NextNumber(-PARK_HALF + 14, PARK_HALF - 14)
		local ax, az = math.abs(x), math.abs(z)
		local ok = math.max(ax, az) >= PLAZA_HALF + 12 and math.min(ax, az) >= 22 and not isReserved(x, z, 6)
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
			tree(treesF, x, z, rng:NextNumber(0.85, 1.35), pickKind())
			if rng:NextInteger(1, 3) == 1 and not isReserved(x, z + 7, 4) then
				bush(treesF, x + rng:NextNumber(-5, 5), z + rng:NextNumber(5, 8), rng:NextNumber(0.8, 1.2))
			end
		end
	end
end

local function buildBoundary()
	for side = 0, 3 do
		local rot = sideRot(side)
		local c = -PARK_HALF
		while c <= PARK_HALF do
			local p = rot * Vector3.new(c + rng:NextNumber(-2, 2), 0, -(PARK_HALF + rng:NextNumber(-1, 2.5)))
			boulder(sceneryF, p.X, p.Z, rng:NextNumber(3.5, 6.5))
			c = c + 10
		end
		c = -PARK_HALF - 10
		while c <= PARK_HALF + 10 do
			local p = rot * Vector3.new(c + rng:NextNumber(-4, 4), 0, -(PARK_HALF + 10 + rng:NextNumber(0, 24)))
			tree(sceneryF, p.X, p.Z, rng:NextNumber(1.1, 1.6), pickKind())
			c = c + 17
		end
		part(sceneryF, "Barrier", Vector3.new(PARK_HALF * 2 + 12, 60, 2), rot * CFrame.new(0, 30, -(PARK_HALF + 3)), C.white, Mat.SmoothPlastic,
			{ transparency = 1, shadow = false })
	end
end

local function applyLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
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
	bloom.Intensity = 0.12
	bloom.Size = 24
	bloom.Threshold = 1.8
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

terrainOk = buildTerrain()
if not terrainOk then
	buildFallbackGround()
end
buildPaths()
buildPlaza()
buildFountain()
local boothCount = buildBooths()
buildFurniture()
buildLakeSide()
buildPicnic()
buildGazebo()
buildTrees()
buildBoundary()
buildSpawns()
applyLighting()

map.Parent = Workspace
print(string.format("[MapBuilder] Dogal park hazir: %d stand, arazi=%s", boothCount, tostring(terrainOk)))

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
			sizeY = inst.Size.Y, -- yumurta buyuyunce alt kenari sabit kalsin
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
			inst.CFrame = d.base + Vector3.new(0, (inst.Size.Y - d.sizeY) / 2 + math.sin(t * d.speed + d.phase) * d.height, 0)
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
