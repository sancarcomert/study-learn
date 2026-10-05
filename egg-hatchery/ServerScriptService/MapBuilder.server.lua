-- ServerScriptService/MapBuilder  (Script)
--
-- CELESTIAL HATCHERY: gokyuzunde yuzen kozmik bir kulucka adasi.
-- Oyun baslarken haritanin tamamini kodla kurar (elle hicbir sey yerlestirmen gerekmez):
--   * N adet stand (kaide, yaprak kubbe, kristaller, yildizlara uzanan isik huzmesi)
--   * ortada donen halkalarin icinde yuzen "Genesis" yumurtasi
--   * gokkusagi halkasi, yuzen adaciklar, uzak monolitler, gokyuzu halkalari (derinlik)
--   * isiklandirma, atmosfer, bloom, alan derinligi
-- Standlar Workspace.Booths icine "Booth_1..N" adiyla konur; BoothManager bunlari otomatik kullanir.
-- Donme/yuzme animasyonlari MapFX LocalScript'i ile istemcide calisir.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

---------------------------------------------------------------------
-- AYARLAR
---------------------------------------------------------------------
local BOOTH_COUNT = 16 -- stand sayisi (8 - 24)
local MOOD = "twilight" -- "twilight" (alacakaranlik) | "night" (gece) | "day" (gunduz)
local BOOTH_FOLDER_NAME = "Booths"

local BOOTH_RADIUS = 80 -- standlarin merkeze uzakligi
local ISLAND_RADIUS = 130
local SEED = 7

BOOTH_COUNT = math.clamp(math.floor(BOOTH_COUNT), 8, 24)

local TAU = math.pi * 2
local rng = Random.new(SEED)
local RGB = Color3.fromRGB
local Mat = Enum.Material

local MOODS = {
	twilight = {
		clock = 18.6, brightness = 2, exposure = 0.3,
		ambient = RGB(84, 76, 126), outdoor = RGB(124, 108, 176),
		atmColor = RGB(244, 166, 204), atmDecay = RGB(150, 100, 190),
		density = 0.3, offset = 0.3, glare = 0.4, haze = 1.2,
		bloom = 0.9, stars = 3500, rays = 0.1,
	},
	night = {
		clock = 0, brightness = 1.2, exposure = 0.5,
		ambient = RGB(52, 58, 104), outdoor = RGB(76, 86, 142),
		atmColor = RGB(120, 140, 220), atmDecay = RGB(80, 70, 160),
		density = 0.26, offset = 0.2, glare = 0, haze = 1.8,
		bloom = 1.2, stars = 5000, rays = 0,
	},
	day = {
		clock = 14.5, brightness = 3, exposure = 0,
		ambient = RGB(120, 120, 140), outdoor = RGB(150, 150, 175),
		atmColor = RGB(199, 220, 255), atmDecay = RGB(110, 140, 200),
		density = 0.3, offset = 0.15, glare = 0.2, haze = 1.5,
		bloom = 0.5, stars = 0, rays = 0.1,
	},
}

local COLOR = {
	floor = RGB(44, 42, 70),
	floorMid = RGB(58, 54, 90),
	path = RGB(88, 84, 128),
	marble = RGB(200, 200, 226),
	stoneDark = RGB(40, 38, 62),
	stoneMid = RGB(70, 66, 100),
	metal = RGB(32, 30, 54),
	rock = RGB(54, 50, 76),
	cyan = RGB(90, 230, 255),
	magenta = RGB(255, 90, 215),
	gold = RGB(255, 205, 100),
	white = RGB(240, 245, 255),
	grass = RGB(52, 128, 118),
}

local DECO = { solid = false, shadow = false } -- carpisma ve golge yok (sus)

---------------------------------------------------------------------
-- TEMIZLIK
---------------------------------------------------------------------
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
local floorF = subfolder("Floor")
local centerF = subfolder("Center")
local pathF = subfolder("Paths")
local decorF = subfolder("Decor")
local underF = subfolder("Underside")
local farF = subfolder("FarScenery")
local fxF = subfolder("Effects")
local beamF = subfolder("SkyBeams")

---------------------------------------------------------------------
-- YARDIMCILAR
---------------------------------------------------------------------
local function hsv(h, s, v)
	return Color3.fromHSV(h % 1, s, v)
end

local function rainbow(sat)
	return function(k, n)
		return hsv(k / n, sat or 0.65, 1)
	end
end

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

-- Silindirin ekseni X'tedir; 90 derece doneren dikey olur. cf = silindirin merkezi.
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

-- Elipsoid: SpecialMesh(Sphere) ile esit olmayan olcude "yumurta/igne" sekilleri
local function ellipsoid(parent, name, size, cf, color, material, o)
	local p = newPart(name, size, cf, color, material, o)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = parent
	return p
end

local function anchorPart(parent, name, size, cf)
	return part(parent, name, size, cf, COLOR.white, Mat.SmoothPlastic, { transparency = 1, solid = false, shadow = false })
end

local function attach(p, name)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = p
	return a
end

local function tag(inst, tagName, attrs)
	CollectionService:AddTag(inst, tagName)
	if attrs then
		for k, v in pairs(attrs) do
			inst:SetAttribute(k, v)
		end
	end
end

local function addLight(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = math.min(range, 60)
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

local function addSparkles(parent, color, rate, speedMin, speedMax, sizeMax, lifeMin, lifeMax)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, COLOR.white)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = rate
	e.Lifetime = NumberRange.new(lifeMin, lifeMax)
	e.Speed = NumberRange.new(speedMin, speedMax)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, sizeMax),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.2),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = parent
	return e
end

local function makeBeam(parent, a0, a1, c0, c1, w0, w1, t0)
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(c0, c1)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 1
	b.Width0 = w0
	b.Width1 = w1
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, t0), NumberSequenceKeypoint.new(1, 1) })
	b.Parent = parent
	return b
end

-- Y ekseni etrafinda halka: parcalarin uzun kenari teget yonde. base = halkanin merkez CFrame'i.
-- color bir Color3 ya da function(k, n) -> Color3 olabilir.
local function ringSegments(parent, name, base, radius, count, radial, height, color, material, o)
	local chord = 2 * radius * math.sin(math.pi / count) * 1.06
	for k = 0, count - 1 do
		local a = k / count * TAU
		local lc = CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius) * CFrame.Angles(0, -a, 0)
		local c = color
		if typeof(c) == "function" then
			c = color(k, count)
		end
		part(parent, name, Vector3.new(radial, height, chord), base * lc, c, material, o)
	end
end

-- Yere yapisik ince neon halka (ust yuzey y = 0.16)
local function neonRing(parent, name, radius, width, color, segLen)
	local count = math.max(16, math.floor(TAU * radius / (segLen or 7)))
	ringSegments(parent, name, CFrame.new(0, 0.08, 0), radius, count, width, 0.16, color, Mat.Neon, DECO)
end

local function boothAccent(i)
	return hsv((i - 1) / BOOTH_COUNT, 0.62, 1)
end

---------------------------------------------------------------------
-- ZEMIN: gokyuzu adasi, meydan, neon kakmalar
---------------------------------------------------------------------
local function buildFloor()
	cyl(floorF, "Floor", ISLAND_RADIUS * 2, 2, CFrame.new(0, -1, 0), COLOR.floor, Mat.Slate)
	cyl(floorF, "FloorMid", 208, 0.1, CFrame.new(0, 0, 0), COLOR.floorMid, Mat.Slate, DECO)
	cyl(floorF, "FloorInner", 92, 0.1, CFrame.new(0, 0.05, 0), COLOR.marble, Mat.Marble, DECO)

	neonRing(floorF, "InnerRing", 46.5, 0.5, COLOR.cyan, 8)
	neonRing(floorF, "RainbowRing", 96, 0.7, rainbow(0.65), 5)
	neonRing(floorF, "MidRing", 103.5, 0.4, COLOR.white, 8)
	neonRing(floorF, "EdgeRing", 122, 0.6, COLOR.gold, 8)
end

-- Merkezden standa uzanan yol
local function buildPath(i)
	local accent = boothAccent(i)
	local a = (i - 1) / BOOTH_COUNT * TAU
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local r0, r1 = 26, BOOTH_RADIUS - 9.6
	local len = r1 - r0
	local mid = dir * ((r0 + r1) / 2)
	local frame = CFrame.lookAt(mid, mid + dir)
	part(pathF, "Path", Vector3.new(7, 0.2, len), frame * CFrame.new(0, 0.1, 0), COLOR.path, Mat.Slate, DECO)
	for _, sx in ipairs({ -3.5, 3.5 }) do
		part(pathF, "PathEdge", Vector3.new(0.35, 0.26, len), frame * CFrame.new(sx, 0.13, 0), accent, Mat.Neon, DECO)
	end
	local dots = 6
	for n = 1, dots do
		local z = -len / 2 + n * len / (dots + 1)
		cyl(pathF, "PathDot", 0.9, 0.26, frame * CFrame.new(0, 0.13, z), accent, Mat.Neon, DECO)
	end
end

---------------------------------------------------------------------
-- MERKEZ: sunak, donen halkalar, yuzen Genesis yumurtasi, obeliskler
---------------------------------------------------------------------
local EGG_Y = 34

local function gyroRing(name, radius, count, tilt, spin, hue0)
	local model = Instance.new("Model")
	model.Name = name
	local base = CFrame.new(0, EGG_Y, 0) * tilt
	model.PrimaryPart = anchorPart(model, "Pivot", Vector3.new(1, 1, 1), base)
	local function glow(k, n)
		return hsv(hue0 + 0.45 * k / n, 0.55, 1)
	end
	ringSegments(model, "Body", base, radius, count, 1.2, 1.5, COLOR.metal, Mat.Metal, DECO)
	ringSegments(model, "Glow", base * CFrame.new(0, 0.9, 0), radius, count, 0.5, 0.3, glow, Mat.Neon, DECO)
	for k = 0, count - 1, 6 do -- donusun gorunmesi icin boncuklar
		local a = k / count * TAU
		local bc = base * CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		ball(model, "Bead", 2.2, bc, glow(k, count), Mat.Neon, DECO)
	end
	tag(model, "FX_Spin", { SpinSpeed = spin })
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = centerF
end

local function buildObelisk(a)
	local pos = Vector3.new(math.cos(a) * 39, 0, math.sin(a) * 39)
	local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
	local c = hsv(a / TAU, 0.55, 1)
	local function L(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	part(centerF, "ObeliskBase", Vector3.new(4.4, 0.8, 4.4), L(0, 0.4, 0), COLOR.stoneMid, Mat.Slate)
	part(centerF, "ObeliskShaft", Vector3.new(2.4, 15, 2.4), L(0, 8.3, 0), COLOR.metal, Mat.Metal)
	part(centerF, "ObeliskCap", Vector3.new(2.9, 0.5, 2.9), L(0, 16.05, 0), c, Mat.Neon, DECO)
	for _, s in ipairs({ { 1.26, 0, 0.14, 0.5 }, { -1.26, 0, 0.14, 0.5 }, { 0, 1.26, 0.5, 0.14 }, { 0, -1.26, 0.5, 0.14 } }) do
		part(centerF, "ObeliskGlow", Vector3.new(s[3], 11, s[4]), L(s[1], 8.3, s[2]), c, Mat.Neon, DECO)
	end
	local shard = ellipsoid(centerF, "ObeliskShard", Vector3.new(1.6, 4.8, 1.6), L(0, 21, 0), c, Mat.Neon, DECO)
	tag(shard, "FX_Bob", { BobHeight = 0.8, BobSpeed = 0.9, BobPhase = a })
end

local function buildCenter()
	local tiers = {
		{ d = 56, top = 0.8, glow = COLOR.cyan },
		{ d = 42, top = 1.6, glow = RGB(150, 160, 255) },
		{ d = 28, top = 2.4, glow = COLOR.magenta },
	}
	for i, t in ipairs(tiers) do
		cyl(centerF, "Tier" .. i, t.d, 0.8, CFrame.new(0, t.top - 0.4, 0), COLOR.marble, Mat.Marble)
		local r = t.d / 2 - 0.5
		ringSegments(centerF, "TierGlow" .. i, CFrame.new(0, t.top + 0.02, 0), r, math.floor(TAU * r / 5), 0.45, 0.1, t.glow, Mat.Neon, DECO)
	end

	cyl(centerF, "Altar", 14, 2, CFrame.new(0, 3.4, 0), COLOR.metal, Mat.Metal)
	cyl(centerF, "AltarBand", 14.6, 0.35, CFrame.new(0, 3.7, 0), COLOR.cyan, Mat.Neon, DECO)
	cyl(centerF, "AltarTop", 11, 0.12, CFrame.new(0, 4.46, 0), COLOR.cyan, Mat.Neon, DECO)

	-- Genesis yumurtasi + cam kabuk
	local egg = ellipsoid(centerF, "GenesisEgg", Vector3.new(9.5, 13, 9.5), CFrame.new(0, EGG_Y, 0), COLOR.cyan, Mat.Neon, DECO)
	addLight(egg, COLOR.cyan, 60, 2.5)
	addSparkles(egg, COLOR.cyan, 14, 2, 6, 0.9, 2, 4)
	tag(egg, "FX_Bob", { BobHeight = 1.4, BobSpeed = 0.8, BobPhase = 0 })
	local shell = ellipsoid(centerF, "GenesisShell", Vector3.new(11.6, 15.6, 11.6), CFrame.new(0, EGG_Y, 0), COLOR.white, Mat.Glass,
		{ solid = false, shadow = false, transparency = 0.55, reflectance = 0.2 })
	tag(shell, "FX_Bob", { BobHeight = 1.4, BobSpeed = 0.8, BobPhase = 0 })

	-- Sunaktan yumurtaya enerji huzmesi ve gokyuzune uzanan sutun
	local low = anchorPart(centerF, "BeamLow", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 4.6, 0))
	local mid = anchorPart(centerF, "BeamMid", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 29, 0))
	makeBeam(low, attach(low, "A0"), attach(mid, "A1"), COLOR.cyan, COLOR.white, 1.6, 3.2, 0.25)
	local up0 = anchorPart(centerF, "BeamUp0", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 41, 0))
	local up1 = anchorPart(centerF, "BeamUp1", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 430, 0))
	makeBeam(up0, attach(up0, "A0"), attach(up1, "A1"), COLOR.cyan, COLOR.magenta, 7, 2, 0.3)
	local core0 = anchorPart(centerF, "BeamCore0", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 41, 0))
	makeBeam(core0, attach(core0, "A0"), attach(up1, "A2"), COLOR.white, COLOR.white, 2.4, 0.8, 0.05)

	gyroRing("GyroA", 14, 28, CFrame.Angles(math.rad(72), 0, 0), 0.55, 0.45)
	gyroRing("GyroB", 18, 36, CFrame.Angles(0, 0, math.rad(68)), -0.4, 0.6)
	gyroRing("GyroC", 22, 44, CFrame.Angles(math.rad(28), math.rad(40), math.rad(30)), 0.3, 0.75)

	for k = 1, 8 do
		local shard = ellipsoid(centerF, "OrbitShard", Vector3.new(1.4, 4.2, 1.4), CFrame.new(0, EGG_Y, 0),
			hsv(0.45 + 0.4 * k / 8, 0.6, 1), Mat.Neon, DECO)
		tag(shard, "FX_Orbit", {
			OrbitCenter = Vector3.new(0, EGG_Y, 0),
			OrbitRadius = 9 + (k % 3) * 1.4,
			OrbitSpeed = 0.5 + (k % 3) * 0.12,
			OrbitPhase = k / 8 * TAU,
			OrbitHeight = (k % 4 - 1.5) * 2.2,
			OrbitBob = 0.6,
		})
	end

	-- Standlarin arasina (yollara degil) obeliskler
	for j = 0, BOOTH_COUNT - 1, 2 do
		buildObelisk((j + 0.5) / BOOTH_COUNT * TAU)
	end
end

---------------------------------------------------------------------
-- STAND: yaprak kubbeli kulucka kaidesi
---------------------------------------------------------------------
local function buildBooth(i)
	local a = (i - 1) / BOOTH_COUNT * TAU
	local pos = Vector3.new(math.cos(a) * BOOTH_RADIUS, 0, math.sin(a) * BOOTH_RADIUS)
	local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0)) -- on yuz merkeze (-Z) bakar
	local accent = boothAccent(i)
	local function L(x, y, z)
		return cf * CFrame.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = "Booth_" .. i

	-- Basamak, kaide, neon kakmalar
	cyl(model, "Step", 19, 0.5, L(0, 0.25, 0), COLOR.stoneMid, Mat.Slate)
	cyl(model, "Dais", 16, 0.9, L(0, 0.75, 0), COLOR.stoneDark, Mat.Slate)
	ringSegments(model, "DaisInlay", L(0, 1.18, 0), 7.2, 20, 0.45, 0.1, accent, Mat.Neon, DECO)
	cyl(model, "DaisCore", 10, 0.1, L(0, 1.2, 0), COLOR.metal, Mat.Metal, DECO)
	cyl(model, "DaisRune", 5.2, 0.06, L(0, 1.26, 0), accent, Mat.Neon, { solid = false, shadow = false, transparency = 0.3 })
	ringSegments(model, "FloorGlow", L(0, 0.08, 0), 9.9, 20, 0.35, 0.16, accent, Mat.Neon, DECO)

	-- Destek sunagi (on) + stand numarasi
	part(model, "PlinthBase", Vector3.new(3.6, 0.35, 3.6), L(0, 1.375, -5), COLOR.metal, Mat.Metal)
	local plinth = part(model, "Plinth", Vector3.new(3, 2.4, 3), L(0, 2.75, -5), COLOR.stoneDark, Mat.Slate)
	part(model, "PlinthCap", Vector3.new(3.3, 0.16, 3.3), L(0, 4.03, -5), accent, Mat.Neon, DECO)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0
	sg.Parent = plinth
	local num = Instance.new("TextLabel")
	num.Size = UDim2.fromScale(1, 1)
	num.BackgroundTransparency = 1
	num.Font = Enum.Font.GothamBlack
	num.TextScaled = true
	num.Text = string.format("%02d", i)
	num.TextColor3 = accent
	num.Parent = sg

	-- Ay kapisi: yumurtanin arkasinda dikey halka (on taraf tamamen acik)
	local gate = L(0, 7.4, 3.2) * CFrame.Angles(math.rad(90), 0, 0)
	ringSegments(model, "GateFrame", gate, 6, 20, 0.8, 0.9, COLOR.metal, Mat.Metal, DECO)
	ringSegments(model, "GateGlow", gate * CFrame.new(0, -0.5, 0), 6, 20, 0.28, 0.2, accent, Mat.Neon, DECO)
	part(model, "GateBase", Vector3.new(2.2, 0.3, 1.4), L(0, 1.35, 3.2), COLOR.metal, Mat.Metal, DECO)
	ball(model, "GateKeystone", 1.3, L(0, 13.9, 3.2), accent, Mat.Neon, DECO)

	-- Yan direkler + kucuk kristal kumeleri
	for _, sx in ipairs({ -6.6, 6.6 }) do
		local side = sx > 0 and 1 or -1
		cyl(model, "PylonBase", 1.8, 0.6, L(sx, 1.5, 1.2), COLOR.metal, Mat.Metal, DECO)
		cyl(model, "Pylon", 1.0, 10, L(sx, 6.2, 1.2), COLOR.metal, Mat.Metal, DECO)
		cyl(model, "PylonGlow", 0.25, 8.4, L(sx, 6.2, 0.65), accent, Mat.Neon, DECO)
		ball(model, "PylonOrb", 1.4, L(sx, 11.9, 1.2), accent, Mat.Neon, DECO)
		ellipsoid(model, "Crystal", Vector3.new(1.0, 3.4, 1.0), L(side * 5.2, 2.9, 2.2) * CFrame.Angles(0, 0, math.rad(-14 * side)), accent, Mat.Neon, DECO)
		ellipsoid(model, "Crystal", Vector3.new(0.8, 2.4, 0.8), L(side * 4.5, 2.4, 3.4) * CFrame.Angles(0, 0, math.rad(12 * side)), accent, Mat.Neon, DECO)
	end

	-- Yumurta (HatcheryService bu parcayi bulup kullanir) + isik + yuzen yorungeler
	local egg = ellipsoid(model, "Egg", Vector3.new(3.4, 4.6, 3.4), L(0, 6.8, 0), COLOR.white, Mat.Neon, DECO)
	addLight(egg, accent, 20, 1.6)
	addSparkles(egg, accent, 5, 1, 3, 0.45, 1.5, 3)
	tag(egg, "FX_Bob", { BobHeight = 0.45, BobSpeed = 1.1, BobPhase = rng:NextNumber(0, TAU) })
	for k = 1, 3 do
		local orb = ball(model, "Orbiter", 0.7, L(0, 6.8, 0), accent, Mat.Neon, DECO)
		tag(orb, "FX_Orbit", {
			OrbitCenter = L(0, 6.8, 0).Position,
			OrbitRadius = 3.3 + k * 0.25,
			OrbitSpeed = 1.1 + k * 0.2,
			OrbitPhase = k / 3 * TAU,
			OrbitHeight = (k - 2) * 0.9,
			OrbitBob = 0.25,
		})
	end

	-- Fenerler
	for _, sx in ipairs({ -8.2, 8.2 }) do
		cyl(model, "LanternPost", 0.35, 4.2, L(sx, 2.6, -3.6), COLOR.metal, Mat.Metal, DECO)
		ball(model, "LanternLamp", 1.2, L(sx, 5.1, -3.6), accent, Mat.Neon, DECO)
	end

	-- Gokyuzune uzanan isik huzmesi (MapFX: sahipli standda parlak, bos standda soluk)
	local bBase = anchorPart(model, "BeamBase", Vector3.new(0.4, 0.4, 0.4), L(0, 1.3, 0))
	local bTop = anchorPart(beamF, "BeamTop_" .. i, Vector3.new(0.4, 0.4, 0.4), CFrame.new(pos + Vector3.new(0, 200, 0)))
	local beam = makeBeam(bBase, attach(bBase, "A0"), attach(bTop, "A1"), accent, COLOR.white, 0.9, 0.3, 0.85)
	beam.Name = "SkyBeam"
	CollectionService:AddTag(beam, "BoothBeam")

	-- Istem prompt'larinin baglanacagi gorunmez ankraj (PrimaryPart = "Base")
	local base = anchorPart(model, "Base", Vector3.new(2, 2, 2), L(0, 5.4, -5))
	model.PrimaryPart = base
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = boothFolder
end

---------------------------------------------------------------------
-- SUS: bahce halkasi, korkuluk, gorunmez sinir
---------------------------------------------------------------------
local function buildGarden()
	for j = 0, BOOTH_COUNT - 1 do
		local a = (j + 0.5) / BOOTH_COUNT * TAU
		local pos = CFrame.new(math.cos(a) * 112, 0, math.sin(a) * 112)
		local c = hsv((j + 0.5) / BOOTH_COUNT + 0.5, 0.6, 1)
		cyl(decorF, "PlanterBase", 7.4, 1.0, pos * CFrame.new(0, 0.5, 0), COLOR.stoneMid, Mat.Slate)
		cyl(decorF, "PlanterSoil", 6.4, 0.12, pos * CFrame.new(0, 1.0, 0), RGB(30, 26, 44), Mat.Slate, DECO)
		cyl(decorF, "Trunk", 0.8, 5.5, pos * CFrame.new(0, 3.75, 0), COLOR.metal, Mat.Metal, DECO)
		ball(decorF, "Canopy", 5.8, pos * CFrame.new(0, 8.3, 0), c, Mat.Neon, { solid = false, shadow = false, transparency = 0.15 })
		for b = 1, 4 do
			local ba = b / 4 * TAU
			ellipsoid(decorF, "Bulb", Vector3.new(0.9, 1.6, 0.9), pos * CFrame.new(math.cos(ba) * 2.4, 1.8, math.sin(ba) * 2.4), c, Mat.Neon, DECO)
		end
	end
end

local function buildParapet()
	local r = ISLAND_RADIUS - 4
	local count = math.floor(TAU * r / 8)
	ringSegments(decorF, "WallBody", CFrame.new(0, 0.7, 0), r, count, 1.4, 1.4, COLOR.rock, Mat.Basalt)
	ringSegments(decorF, "WallGlow", CFrame.new(0, 1.46, 0), r, count, 0.4, 0.12, COLOR.gold, Mat.Neon, DECO)
	for k = 0, count - 1, 6 do
		local a = k / count * TAU
		local p = CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
		cyl(decorF, "WallPost", 1.8, 5, p * CFrame.new(0, 2.5, 0), COLOR.stoneMid, Mat.Slate)
		ball(decorF, "WallLamp", 1.7, p * CFrame.new(0, 5.6, 0), COLOR.gold, Mat.Neon, DECO)
	end
	-- Gorunmez yuksek sinir: oyuncular adadan dusmesin
	local br = r + 2.8
	ringSegments(decorF, "Barrier", CFrame.new(0, 20, 0), br, math.floor(TAU * br / 10), 1, 40, COLOR.white, Mat.SmoothPlastic,
		{ transparency = 1, shadow = false })
end

---------------------------------------------------------------------
-- ADANIN ALTI: kaya basamaklari, parcalar, sarkan kristaller
---------------------------------------------------------------------
local function buildUnderside()
	local layers = 15
	local radii = {}
	for k = 1, layers do
		local r = ISLAND_RADIUS * (1 - k / (layers + 1)) ^ 1.15
		radii[k] = r
		local y = -6 - 8 * (k - 1)
		local mat = (k % 2 == 0) and Mat.Slate or Mat.Basalt
		cyl(underF, "Layer" .. k, r * 2, 8, CFrame.new(0, y, 0), COLOR.rock:Lerp(COLOR.stoneMid, rng:NextNumber()), mat, { solid = false })
	end
	for _ = 1, 70 do
		local k = rng:NextInteger(1, layers)
		local ang = rng:NextNumber(0, TAU)
		local r = radii[k] * rng:NextNumber(0.55, 1.0)
		local sx = rng:NextNumber(7, 20)
		local sy = sx * rng:NextNumber(0.6, 1.2)
		local sz = sx * rng:NextNumber(0.7, 1.3)
		local extent = 0.5 * math.sqrt(sx * sx + sy * sy + sz * sz) -- donse bile zemini delmesin
		local y = math.min(-6 - 8 * (k - 1) + rng:NextNumber(-3, 3), -2.5 - extent)
		local rot = CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), rng:NextNumber(0, TAU))
		local mat = (rng:NextInteger(0, 1) == 0) and Mat.Basalt or Mat.Slate
		part(underF, "Chunk", Vector3.new(sx, sy, sz), CFrame.new(math.cos(ang) * r, y, math.sin(ang) * r) * rot,
			COLOR.rock:Lerp(COLOR.stoneMid, rng:NextNumber()), mat, { solid = false })
	end
	for n = 1, 18 do
		local ang = rng:NextNumber(0, TAU)
		local r = rng:NextNumber(8, 62)
		local len = rng:NextNumber(12, 30)
		local top = rng:NextNumber(-60, -20)
		local c = hsv(rng:NextNumber(0.45, 0.95), 0.6, 1)
		local tilt = CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2))
		local crystal = ellipsoid(underF, "HangingCrystal", Vector3.new(2.6, len, 2.6),
			CFrame.new(math.cos(ang) * r, top - len / 2, math.sin(ang) * r) * tilt, c, Mat.Neon, DECO)
		if n <= 6 then
			addLight(crystal, c, 40, 1.2)
		end
	end
end

---------------------------------------------------------------------
-- UZAK MANZARA: yuzen adaciklar, monolitler, gokyuzu halkalari (derinlik)
---------------------------------------------------------------------
local function buildIslet(i)
	local ang = i * 2.399963
	local r = 190 + ((i - 1) % 4) * 48 + rng:NextNumber(0, 24)
	local cy = rng:NextNumber(-40, 70)
	local dia = rng:NextNumber(18, 34)
	local base = CFrame.new(math.cos(ang) * r, cy, math.sin(ang) * r)
	local hue = rng:NextNumber()
	local glow = hsv(hue, 0.6, 1)

	local model = Instance.new("Model")
	model.Name = "Islet_" .. i
	model.PrimaryPart = anchorPart(model, "Pivot", Vector3.new(1, 1, 1), base)

	cyl(model, "Top", dia, 2.6, base * CFrame.new(0, -1.3, 0), COLOR.grass, Mat.Grass, { solid = false })
	local fracs = { 0.8, 0.58, 0.34, 0.16 }
	for k, f in ipairs(fracs) do
		cyl(model, "Under" .. k, dia * f, 3, base * CFrame.new(0, -2.6 - 1.5 - 3 * (k - 1), 0), COLOR.rock, (k % 2 == 0) and Mat.Slate or Mat.Basalt, { solid = false })
	end
	local rim = dia / 2 - 0.4
	ringSegments(model, "Rim", base * CFrame.new(0, 0.05, 0), rim, math.max(10, math.floor(TAU * rim / 4)), 0.5, 0.12, glow, Mat.Neon, DECO)

	if i % 2 == 0 then
		cyl(model, "Trunk", 1.3, 7, base * CFrame.new(0, 3.5, 0), RGB(70, 52, 60), Mat.Wood, DECO)
		local leaf = hsv(hue + 0.1, 0.45, 0.95)
		ball(model, "Leaves", 9, base * CFrame.new(0, 9.5, 0), leaf, Mat.SmoothPlastic, DECO)
		ball(model, "Leaves", 7, base * CFrame.new(1.5, 12.5, 0.5), leaf, Mat.SmoothPlastic, DECO)
		ball(model, "Leaves", 5, base * CFrame.new(-1, 15, -0.5), leaf, Mat.SmoothPlastic, DECO)
		for b = 1, 6 do
			local ba = b / 6 * TAU
			ball(model, "Fruit", 0.9, base * CFrame.new(math.cos(ba) * 3.8, 9.2 + (b % 3), math.sin(ba) * 3.8), glow, Mat.Neon, DECO)
		end
	else
		for k = 1, 4 do
			local ca = k / 4 * TAU
			local h = rng:NextNumber(8, 14)
			ellipsoid(model, "Crystal", Vector3.new(2.4, h, 2.4),
				base * CFrame.new(math.cos(ca) * 3, h / 2, math.sin(ca) * 3) * CFrame.Angles(math.cos(ca) * 0.2, 0, math.sin(ca) * 0.2),
				glow, Mat.Neon, DECO)
		end
	end

	tag(model, "FX_Bob", {
		BobHeight = rng:NextNumber(1.5, 3.5),
		BobSpeed = rng:NextNumber(0.25, 0.5),
		BobPhase = rng:NextNumber(0, TAU),
		SpinSpeed = rng:NextNumber(-0.04, 0.04),
	})
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = farF
end

local function buildMonolith(i)
	local ang = i * 2.399963 + 0.7
	local r = rng:NextNumber(430, 640)
	local y = rng:NextNumber(10, 170)
	local w, h, dpt = rng:NextNumber(12, 20), rng:NextNumber(60, 130), rng:NextNumber(5, 8)
	local center = Vector3.new(math.cos(ang) * r, y, math.sin(ang) * r)
	local cf = CFrame.lookAt(center, Vector3.new(0, y, 0)) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
	local c = hsv(rng:NextNumber(0.45, 0.95), 0.6, 1)

	local model = Instance.new("Model")
	model.Name = "Monolith_" .. i
	model.PrimaryPart = anchorPart(model, "Pivot", Vector3.new(1, 1, 1), CFrame.new(center))
	part(model, "Slab", Vector3.new(w, h, dpt), cf, RGB(26, 24, 44), Mat.Basalt, { solid = false })
	part(model, "Glow", Vector3.new(0.7, h * 0.85, 0.3), cf * CFrame.new(0, 0, -(dpt / 2 + 0.1)), c, Mat.Neon, DECO)
	part(model, "Cap", Vector3.new(w + 1, 1.2, dpt + 1), cf * CFrame.new(0, h / 2 + 0.6, 0), c, Mat.Neon, DECO)
	tag(model, "FX_Bob", { BobHeight = 4, BobSpeed = 0.25, BobPhase = rng:NextNumber(0, TAU) })
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = farF
end

local function skyRing(name, radius, count, tilt, height, hueShift, spin)
	local model = Instance.new("Model")
	model.Name = name
	local base = CFrame.new(0, height, 0) * tilt
	model.PrimaryPart = anchorPart(model, "Pivot", Vector3.new(1, 1, 1), base)
	ringSegments(model, "Seg", base, radius, count, 7, 7, function(k, n)
		return hsv(hueShift + k / n, 0.7, 1)
	end, Mat.Neon, DECO)
	tag(model, "FX_Spin", { SpinSpeed = spin })
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = farF
end

---------------------------------------------------------------------
-- EFEKTLER, ISIKLANDIRMA, DOGMA NOKTALARI
---------------------------------------------------------------------
local function buildEffects()
	local dust = anchorPart(fxF, "Stardust", Vector3.new(320, 70, 320), CFrame.new(0, 30, 0))
	local e = addSparkles(dust, COLOR.white, 60, 0.4, 1.6, 0.6, 8, 14)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Acceleration = Vector3.new(0, 0.2, 0)

	local motes = anchorPart(fxF, "CenterMotes", Vector3.new(44, 50, 44), CFrame.new(0, 26, 0))
	local m = addSparkles(motes, COLOR.cyan, 18, 0.5, 2, 0.7, 4, 8)
	m.Shape = Enum.ParticleEmitterShape.Box
	m.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
end

local function applyLighting()
	local m = MOODS[MOOD] or MOODS.twilight
	Lighting.ClockTime = m.clock
	Lighting.Brightness = m.brightness
	Lighting.ExposureCompensation = m.exposure
	Lighting.Ambient = m.ambient
	Lighting.OutdoorAmbient = m.outdoor
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true

	local sky = Instance.new("Sky")
	sky.StarCount = m.stars
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local atm = Instance.new("Atmosphere")
	atm.Density = m.density
	atm.Offset = m.offset
	atm.Color = m.atmColor
	atm.Decay = m.atmDecay
	atm.Glare = m.glare
	atm.Haze = m.haze
	atm.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = m.bloom
	bloom.Size = 30
	bloom.Threshold = 0.9
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.2
	cc.Contrast = 0.12
	cc.TintColor = RGB(255, 246, 255)
	cc.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.2
	dof.FocusDistance = 100
	dof.InFocusRadius = 180
	dof.NearIntensity = 0
	dof.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = m.rays
	rays.Spread = 0.8
	rays.Parent = Lighting
end

local function buildSpawns()
	for k = 0, 3 do
		local j = math.floor(BOOTH_COUNT * k / 4) -- yol uzerinde (obeliskler yarim adimda)
		local a = j / BOOTH_COUNT * TAU
		local x, z = math.cos(a) * 36, math.sin(a) * 36
		local sp = Instance.new("SpawnLocation")
		sp.Name = "Spawn" .. (k + 1)
		sp.Anchored = true
		sp.Size = Vector3.new(10, 0.2, 10)
		sp.CFrame = CFrame.new(x, 0.1, z)
		sp.Transparency = 1
		sp.CanCollide = false
		sp.Neutral = true
		sp.Duration = 0
		sp.TopSurface = Enum.SurfaceType.Smooth
		sp.BottomSurface = Enum.SurfaceType.Smooth
		sp.Parent = Workspace
		ringSegments(decorF, "SpawnRing", CFrame.new(x, 0.2, z), 4, 16, 0.4, 0.1, COLOR.gold, Mat.Neon, DECO)
	end
end

---------------------------------------------------------------------
-- KUR
---------------------------------------------------------------------
buildFloor()
buildCenter()
for i = 1, BOOTH_COUNT do
	buildPath(i)
	buildBooth(i)
end
buildGarden()
buildParapet()
buildUnderside()
for i = 1, 12 do
	buildIslet(i)
end
for i = 1, 14 do
	buildMonolith(i)
end
skyRing("SkyRingA", 560, 64, CFrame.Angles(math.rad(18), 0, math.rad(8)), 260, 0, 0.012)
skyRing("SkyRingB", 650, 72, CFrame.Angles(math.rad(-22), 0, math.rad(12)), 240, 0.5, -0.009)
buildEffects()
buildSpawns()
applyLighting()

map.Parent = Workspace
print(string.format("[MapBuilder] Celestial Hatchery hazir: %d stand", BOOTH_COUNT))
