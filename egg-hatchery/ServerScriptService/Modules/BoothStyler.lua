-- BoothStyler: standin uzerine seviye ile acilan gorsel stilleri kurar.
-- Her stand modeli icin standin sinirlarini olcer, "StyleDecor" modeline sus parcalari ekler.
-- Sus parcalari carpismaz (oyuncu icinden gecer) ve golge atmaz; standin kendi parcalarina dokunulmaz.

local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local Styler = {}

local RGB = Color3.fromRGB
local CREAM = RGB(248, 242, 224)
local GOLD = RGB(255, 205, 60)
local WOOD = RGB(124, 88, 56)
local DARK_WOOD = RGB(92, 64, 42)
local STONE = RGB(176, 170, 160)
local DARK_METAL = RGB(52, 56, 64)
local WARM_LIGHT = RGB(255, 226, 160)
local LEAF_A, LEAF_B = RGB(86, 164, 66), RGB(64, 138, 56)
local FLOWERS = { RGB(255, 128, 170), RGB(255, 224, 90), RGB(250, 250, 250), RGB(235, 80, 80), RGB(180, 120, 230), RGB(255, 150, 60) }
local UP = CFrame.Angles(0, 0, math.rad(90))

local function shade(color, factor)
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

local function addPart(parent, name, size, cf, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Locked = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if transparency then
		p.Transparency = transparency
	end
	p.Parent = parent
	return p
end

local function addCylinder(parent, name, diameter, height, cf, color, material, transparency)
	local p = addPart(parent, name, Vector3.new(height, diameter, diameter), cf * UP, color, material, transparency)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function addBall(parent, name, diameter, cf, color, material)
	local p = addPart(parent, name, Vector3.new(diameter, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- iki nokta arasina ince silindir (ip, cubuk)
local function addRod(parent, name, a, b, thickness, color, material)
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	local p = addPart(parent, name, Vector3.new((b - a).Magnitude, thickness, thickness), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function anyPosition(inst)
	if inst:IsA("BasePart") then
		return inst.Position
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			return d.Position
		end
	end
	return nil
end

-- Standlarin "on yuzu": haritanin merkezine (cesme varsa cesme) bakan taraf
local function frontTarget()
	local fountain = Workspace:FindFirstChild("Fountain", true)
	return (fountain and anyPosition(fountain)) or Vector3.new(0, 0, 0)
end

local function isDecor(part, booth)
	return part:FindFirstAncestor("StyleDecor") ~= nil or part:FindFirstAncestor("Egg") ~= nil or part:FindFirstAncestor("EggPad") ~= nil
		or part.Name == "PulseRing"
end

-- Standi olc: on yone donuk bir cerceve + genislik/yukseklik/on kenar
function Styler.Measure(booth)
	local corners = {}
	local minY, maxY = math.huge, -math.huge
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for _, d in ipairs(booth:GetDescendants()) do
		if d:IsA("BasePart") and not isDecor(d, booth) then
			for _, sx in ipairs({ -0.5, 0.5 }) do
				for _, sy in ipairs({ -0.5, 0.5 }) do
					for _, sz in ipairs({ -0.5, 0.5 }) do
						local c = d.CFrame * Vector3.new(sx * d.Size.X, sy * d.Size.Y, sz * d.Size.Z)
						table.insert(corners, c)
						minY, maxY = math.min(minY, c.Y), math.max(maxY, c.Y)
						x0, x1 = math.min(x0, c.X), math.max(x1, c.X)
						z0, z1 = math.min(z0, c.Z), math.max(z1, c.Z)
					end
				end
			end
		end
	end
	if #corners == 0 then
		return nil
	end
	local center = Vector3.new((x0 + x1) / 2, minY, (z0 + z1) / 2)
	local dir = frontTarget() - center
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		dir = Vector3.new(0, 0, -1)
	end
	local frame = CFrame.lookAt(center, center + dir.Unit)
	local lx0, lx1, lz0, lz1, ly1 = math.huge, -math.huge, math.huge, -math.huge, 0
	for _, c in ipairs(corners) do
		local l = frame:PointToObjectSpace(c)
		lx0, lx1 = math.min(lx0, l.X), math.max(lx1, l.X)
		lz0, lz1 = math.min(lz0, l.Z), math.max(lz1, l.Z)
		ly1 = math.max(ly1, l.Y)
	end
	return {
		frame = frame,
		width = lx1 - lx0,
		height = ly1,
		xc = (lx0 + lx1) / 2, -- yatay merkez ofseti
		front = lz0, -- on kenar (negatif z = onde)
		back = lz1,
	}
end

---------------------------------------------------------------------
-- Stil kurucular. F = Measure sonucu, accent = secilen renk
-- Konum: at(F, yanal, yukseklik, derinlik); derinlik negatif = standin onu (plazaya dogru)
---------------------------------------------------------------------
local builders = {}

local function at(F, x, y, z)
	return F.frame * CFrame.new(F.xc + x, y, z)
end

local function lightOn(part, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
	return light
end

local function sparkleEmitter(parent, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Rate = rate
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(1.5, 4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = parent
	return e
end

-- Hali: cerceveli, desenli, saclakli giris halisi
function builders.rug(decor, F, accent)
	local w = math.clamp(F.width * 0.85, 7, 14)
	local d = 5.2
	local z = F.front - 0.8 - d / 2
	local dark = shade(accent, 0.55)
	local function layer(name, sx, sz, y, color)
		return addPart(decor, name, Vector3.new(sx, 0.04, sz), at(F, 0, y, z), color, Enum.Material.Fabric)
	end
	layer("RugEdge", w + 0.9, d + 0.9, 0.04, CREAM)
	layer("RugBorder", w + 0.1, d + 0.1, 0.07, dark)
	layer("Rug", w - 0.7, d - 0.7, 0.10, accent)
	-- ortada ic ice gecmis elmaslar
	local m = math.min(d - 1.3, 3.4)
	for k, spec in ipairs({ { 1, CREAM }, { 0.72, dark }, { 0.44, CREAM }, { 0.22, accent } }) do
		addPart(decor, "Medallion" .. k, Vector3.new(m * spec[1], 0.04, m * spec[1]),
			at(F, 0, 0.12 + k * 0.012, z) * CFrame.Angles(0, math.rad(45), 0), spec[2], Enum.Material.Fabric)
	end
	-- kose karolari
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			addPart(decor, "RugCorner", Vector3.new(0.7, 0.04, 0.7), at(F, sx * (w / 2 - 0.85), 0.125, z + sz * (d / 2 - 0.85)), dark, Enum.Material.Fabric)
		end
	end
	-- iki ucta saclar
	local n = math.floor(d / 0.5)
	for i = 1, n do
		local zz = z - d / 2 + (i - 0.5) * d / n
		for _, sx in ipairs({ -1, 1 }) do
			addPart(decor, "Fringe", Vector3.new(0.45, 0.03, 0.14), at(F, sx * (w / 2 + 0.45 + 0.22), 0.035, zz), CREAM, Enum.Material.Fabric)
		end
	end
end

-- Bayrakli: iki direk arasinda sarkan ip ve renkli flamalar
function builders.flags(decor, F, accent)
	local half = F.width / 2 + 1.1
	local z = F.front - 0.9
	local top = F.height + 1.6
	for _, sx in ipairs({ -1, 1 }) do
		addCylinder(decor, "PoleBase", 1.0, 0.45, at(F, sx * half, 0.225, z), STONE, Enum.Material.Concrete)
		addCylinder(decor, "FlagPole", 0.3, top, at(F, sx * half, top / 2, z), WOOD, Enum.Material.Wood)
		addCylinder(decor, "PoleCollar", 0.5, 0.25, at(F, sx * half, top - 0.6, z), GOLD, Enum.Material.Metal)
		addBall(decor, "PoleTip", 0.62, at(F, sx * half, top + 0.3, z), GOLD, Enum.Material.Metal)
	end
	local function ropePoint(t)
		local sag = 1.5 * (1 - (2 * t - 1) ^ 2)
		return at(F, (2 * t - 1) * half, top - 0.55 - sag, z).Position
	end
	local segments = 20
	for i = 1, segments do
		addRod(decor, "Rope", ropePoint((i - 1) / segments), ropePoint(i / segments), 0.07, DARK_WOOD, Enum.Material.Fabric)
	end
	local colors = { accent, CREAM, shade(accent, 0.7) }
	local count = 13
	for k = 1, count do
		local t = 0.04 + 0.92 * (k - 1) / (count - 1)
		local p = ropePoint(t)
		local cf = CFrame.new(p) * (F.frame - F.frame.Position) * CFrame.new(0, -0.55, 0) * CFrame.Angles(0, 0, math.rad(45))
		addPart(decor, "Flag", Vector3.new(0.95, 0.95, 0.06), cf, colors[(k - 1) % 3 + 1], Enum.Material.Fabric)
	end
end

-- Fenerli: tas kaideli, kafesli iki sokak lambasi
function builders.lantern(decor, F, accent)
	local half = F.width / 2 + 1.3
	local z = F.front - 1.2
	for _, sx in ipairs({ -1, 1 }) do
		local p = at(F, sx * half, 0, z)
		addPart(decor, "LampFoot", Vector3.new(1.4, 0.35, 1.4), p * CFrame.new(0, 0.175, 0), STONE, Enum.Material.Concrete)
		addPart(decor, "LampPedestal", Vector3.new(0.9, 0.55, 0.9), p * CFrame.new(0, 0.625, 0), STONE, Enum.Material.Concrete)
		addCylinder(decor, "LampPole", 0.28, 5.0, p * CFrame.new(0, 3.4, 0), DARK_METAL, Enum.Material.Metal)
		addCylinder(decor, "LampCollar", 0.6, 0.18, p * CFrame.new(0, 1.2, 0), accent, Enum.Material.Metal)
		addPart(decor, "LampPlate", Vector3.new(1.5, 0.18, 1.5), p * CFrame.new(0, 5.99, 0), DARK_METAL, Enum.Material.Metal)
		for _, cx in ipairs({ -0.58, 0.58 }) do
			for _, cz in ipairs({ -0.58, 0.58 }) do
				addPart(decor, "LampBar", Vector3.new(0.1, 1.5, 0.1), p * CFrame.new(cx, 6.83, cz), DARK_METAL, Enum.Material.Metal)
			end
		end
		local core = addPart(decor, "Lantern", Vector3.new(0.8, 1.25, 0.8), p * CFrame.new(0, 6.83, 0), WARM_LIGHT, Enum.Material.Neon)
		lightOn(core, RGB(255, 214, 140), 18, 1.5)
		addPart(decor, "LampRoof", Vector3.new(1.7, 0.2, 1.7), p * CFrame.new(0, 7.68, 0), DARK_METAL, Enum.Material.Metal)
		addPart(decor, "LampRoofTop", Vector3.new(1.1, 0.3, 1.1), p * CFrame.new(0, 7.93, 0), DARK_METAL, Enum.Material.Metal)
		addBall(decor, "LampFinial", 0.34, p * CFrame.new(0, 8.2, 0), accent, Enum.Material.Metal)
	end
end

local function planter(decor, F, sx, accent, seed)
	local p = at(F, sx, 0, F.front - 1.6)
	addPart(decor, "PlanterBox", Vector3.new(3.4, 1.1, 2.4), p * CFrame.new(0, 0.55, 0), WOOD, Enum.Material.WoodPlanks)
	addPart(decor, "PlanterTrim", Vector3.new(3.6, 0.18, 2.6), p * CFrame.new(0, 1.19, 0), DARK_WOOD, Enum.Material.Wood)
	addPart(decor, "PlanterSoil", Vector3.new(3.0, 0.12, 2.0), p * CFrame.new(0, 1.26, 0), RGB(78, 54, 38), Enum.Material.Ground)
	for k = -1, 1 do
		addBall(decor, "Hedge", 1.25, p * CFrame.new(k * 1.0, 1.75, 0.35), (k % 2 == 0) and LEAF_A or LEAF_B, Enum.Material.Grass)
	end
	for k = 1, 7 do
		local x = -1.35 + (k - 1) * 0.45
		local zz = -0.5 + ((k * 5 + seed) % 3) * 0.15
		local h = 0.9 + ((k * 3 + seed) % 3) * 0.25
		addCylinder(decor, "Stem", 0.07, h, p * CFrame.new(x, 1.3 + h / 2, zz), LEAF_B, Enum.Material.Grass)
		local col = (k % 3 == 0) and accent or FLOWERS[(k + seed) % #FLOWERS + 1]
		addBall(decor, "Flower", 0.5, p * CFrame.new(x, 1.3 + h + 0.12, zz), col, Enum.Material.SmoothPlastic)
	end
end

-- Cicekli: iki saksi ve standin onunu cerceveleyen cicekli kemer
function builders.garden(decor, F, accent)
	local R = F.width / 2 + 1.4
	local z = F.front - 1.6
	local baseY = F.height * 0.38
	local ry = F.height * 0.62 + 0.6
	for side, sx in ipairs({ -1, 1 }) do
		planter(decor, F, sx * R, accent, side * 2)
		addCylinder(decor, "ArchPost", 0.32, baseY, at(F, sx * R, baseY / 2, z - 0.9), WOOD, Enum.Material.Wood)
	end
	local n = 27
	local function archPoint(k)
		local th = math.pi * k / (n - 1)
		return at(F, R * math.cos(th), baseY + ry * math.sin(th), z - 0.9)
	end
	for k = 0, n - 2 do
		addRod(decor, "ArchFrame", archPoint(k).Position, archPoint(k + 1).Position, 0.22, DARK_WOOD, Enum.Material.Wood)
	end
	for k = 0, n - 1 do
		local cf = archPoint(k)
		addBall(decor, "Leaf", 1.0, cf, (k % 2 == 0) and LEAF_A or LEAF_B, Enum.Material.Grass)
		if k % 2 == 1 then
			addBall(decor, "Blossom", 0.6, cf * CFrame.new(0, 0, -0.45), (k % 4 == 1) and accent or FLOWERS[k % #FLOWERS + 1], Enum.Material.SmoothPlastic)
		end
	end
end

-- Altin sutunlar (altin ve efsane stilleri ortak kullanir)
local function goldColumns(decor, F)
	local half = F.width / 2 + 1.0
	local z = F.front - 0.8
	local h = F.height + 0.8
	for _, sx in ipairs({ -1, 1 }) do
		addPart(decor, "ColumnPlinth", Vector3.new(1.5, 0.5, 1.5), at(F, sx * half, 0.25, z), GOLD, Enum.Material.Metal)
		addPart(decor, "ColumnPlinthTop", Vector3.new(1.1, 0.25, 1.1), at(F, sx * half, 0.625, z), GOLD, Enum.Material.Metal)
		addCylinder(decor, "ColumnShaft", 0.7, h, at(F, sx * half, 0.75 + h / 2, z), GOLD, Enum.Material.Metal)
		addCylinder(decor, "ColumnRing", 0.95, 0.2, at(F, sx * half, 0.95, z), GOLD, Enum.Material.Metal)
		addCylinder(decor, "ColumnRing", 0.95, 0.2, at(F, sx * half, 0.75 + h - 0.2, z), GOLD, Enum.Material.Metal)
		addPart(decor, "ColumnCapital", Vector3.new(1.3, 0.35, 1.3), at(F, sx * half, 0.75 + h + 0.175, z), GOLD, Enum.Material.Metal)
		addBall(decor, "ColumnOrb", 0.9, at(F, sx * half, 0.75 + h + 0.8, z), GOLD, Enum.Material.Metal)
	end
	addPart(decor, "GoldLintel", Vector3.new(half * 2, 0.32, 0.4), at(F, 0, 0.75 + h + 0.05, z), GOLD, Enum.Material.Metal)
	return half, z, h
end

local function coinStack(decor, F, sx, z, count)
	for k = 1, count do
		addCylinder(decor, "Coin", 0.95 - (k % 2) * 0.06, 0.13, at(F, sx + ((k % 3) - 1) * 0.04, 0.065 + (k - 1) * 0.14, z), GOLD, Enum.Material.Metal)
	end
end

-- Altin: altin sutunlar, lento, zemin isigi ve para yiginlari
function builders.gold(decor, F, accent)
	local half, z = goldColumns(decor, F)
	addPart(decor, "GoldInlay", Vector3.new(F.width * 0.9, 0.05, 2.6), at(F, 0, 0.05, F.front - 2.4), GOLD, Enum.Material.Metal)
	addPart(decor, "GoldInlayStripe", Vector3.new(F.width * 0.9, 0.05, 0.25), at(F, 0, 0.065, F.front - 2.4), accent, Enum.Material.Neon)
	coinStack(decor, F, -half - 1.6, z - 0.5, 6)
	coinStack(decor, F, half + 1.6, z - 0.5, 4)
end

-- Efsane: altin stilin ustune isik sutunlari, flamalar, kivilcimlar ve isikli zemin
function builders.legend(decor, F, accent)
	local half, z, h = goldColumns(decor, F)
	local ring = addCylinder(decor, "GroundRing", F.width + 3, 0.05, at(F, 0, 0.04, F.front - 0.5), GOLD, Enum.Material.Neon, 0.55)
	ring.CanQuery = false
	-- kirmizi (secilen renk) yurume seridi, altin kenarli
	local zr = F.front - 3.2
	addPart(decor, "RunnerEdge", Vector3.new(3.4, 0.05, 5.4), at(F, 0, 0.05, zr), GOLD, Enum.Material.Metal)
	addPart(decor, "Runner", Vector3.new(2.8, 0.06, 5.2), at(F, 0, 0.075, zr), accent, Enum.Material.Fabric)
	-- sutunlarin yaninda isik huzmesi + kivilcim
	for _, sx in ipairs({ -1, 1 }) do
		addCylinder(decor, "Pillar", 0.9, 22, at(F, sx * half, 11, z), accent, Enum.Material.Neon, 0.82)
		local spark = addPart(decor, "Sparkles", Vector3.new(0.5, 0.5, 0.5), at(F, sx * half, 0.75 + h + 0.9, z), accent, Enum.Material.SmoothPlastic, 1)
		sparkleEmitter(spark, GOLD, 12)
	end
	-- lentodan sarkan flamalar (altin saclakli)
	local banners = 3
	for k = 1, banners do
		local x = (k - (banners + 1) / 2) * (half * 2 / (banners + 0.6))
		local top = 0.75 + h - 0.1
		addPart(decor, "Banner", Vector3.new(1.3, 3.2, 0.08), at(F, x, top - 1.6, z - 0.3), (k % 2 == 1) and accent or shade(accent, 0.7), Enum.Material.Fabric)
		addPart(decor, "BannerTrim", Vector3.new(1.4, 0.14, 0.12), at(F, x, top - 3.2, z - 0.3), GOLD, Enum.Material.Metal)
		addBall(decor, "BannerTip", 0.22, at(F, x, top - 3.4, z - 0.3), GOLD, Enum.Material.Metal)
	end
	coinStack(decor, F, -half - 1.6, z - 0.5, 8)
	coinStack(decor, F, half + 1.6, z - 0.5, 8)
end

---------------------------------------------------------------------
-- Disari acik
---------------------------------------------------------------------
function Styler.Clear(booth)
	local old = booth:FindFirstChild("StyleDecor")
	if old then
		old:Destroy()
	end
end

-- styleId: Config.STYLES icindeki Id, colorIndex: Config.STYLE_COLORS indeksi
function Styler.Apply(booth, styleId, colorIndex)
	Styler.Clear(booth)
	local build = builders[styleId]
	if not build then
		return false -- "classic" gibi susu olmayan stil
	end
	local F = Styler.Measure(booth)
	if not F then
		return false
	end
	local accent = (Config.STYLE_COLORS[colorIndex] or Config.STYLE_COLORS[1]).Color
	local decor = Instance.new("Model")
	decor.Name = "StyleDecor"
	build(decor, F, accent, booth)
	decor.Parent = booth
	return true
end

return Styler
