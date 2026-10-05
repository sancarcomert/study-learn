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
local FLOWERS = { RGB(255, 128, 170), RGB(255, 224, 90), RGB(250, 250, 250), RGB(235, 80, 80), RGB(180, 120, 230), RGB(255, 150, 60) }
local UP = CFrame.Angles(0, 0, math.rad(90))

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
	return part:FindFirstAncestor("StyleDecor") ~= nil or part.Name == "Egg" or part:FindFirstAncestor("HatcheryGui") ~= nil
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
---------------------------------------------------------------------
local builders = {}

local function at(F, x, y, z)
	return F.frame * CFrame.new(F.xc + x, y, z)
end

function builders.rug(decor, F, accent)
	local w = math.clamp(F.width * 0.9, 6, 16)
	local z = F.front - 3.4
	addPart(decor, "RugBorder", Vector3.new(w + 0.8, 0.1, 5.8), at(F, 0, 0.06, z), CREAM, Enum.Material.Fabric)
	addPart(decor, "Rug", Vector3.new(w, 0.12, 5), at(F, 0, 0.09, z), accent, Enum.Material.Fabric)
	addPart(decor, "RugStripe", Vector3.new(w, 0.13, 1), at(F, 0, 0.1, z), CREAM, Enum.Material.Fabric)
end

function builders.flags(decor, F, accent)
	local half = F.width / 2 + 1
	local top = F.height + 1.5
	for _, sx in ipairs({ -1, 1 }) do
		addCylinder(decor, "FlagPole", 0.4, top, at(F, sx * half, top / 2, F.front - 0.8), WOOD, Enum.Material.Wood)
		addBall(decor, "FlagPoleTip", 0.7, at(F, sx * half, top + 0.2, F.front - 0.8), GOLD, Enum.Material.Metal)
	end
	local n = 9
	for k = 0, n - 1 do
		local t = (k + 0.5) / n
		local x = (t * 2 - 1) * half
		local sag = -1.1 * (1 - (2 * t - 1) ^ 2)
		addPart(decor, "Flag", Vector3.new(1.1, 1.1, 0.12), at(F, x, top - 0.5 + sag, F.front - 0.8) * CFrame.Angles(0, 0, math.rad(45)),
			(k % 2 == 0) and accent or CREAM, Enum.Material.Fabric)
	end
end

function builders.lantern(decor, F, accent)
	local half = F.width / 2 + 1.2
	for _, sx in ipairs({ -1, 1 }) do
		local p = at(F, sx * half, 0, F.front - 1.2)
		addCylinder(decor, "LanternPole", 0.4, 5.6, p * CFrame.new(0, 2.8, 0), RGB(56, 60, 66), Enum.Material.Metal)
		local lamp = addPart(decor, "Lantern", Vector3.new(1.3, 1.7, 1.3), p * CFrame.new(0, 6.3, 0), RGB(255, 226, 160), Enum.Material.Neon)
		addPart(decor, "LanternCap", Vector3.new(1.9, 0.3, 1.9), p * CFrame.new(0, 7.3, 0), RGB(56, 60, 66), Enum.Material.Metal)
		addPart(decor, "LanternBase", Vector3.new(1.9, 0.3, 1.9), p * CFrame.new(0, 5.4, 0), accent, Enum.Material.Metal)
		local light = Instance.new("PointLight")
		light.Color = RGB(255, 214, 140)
		light.Range = 16
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = lamp
	end
end

function builders.garden(decor, F, accent)
	local half = F.width / 2 + 1.6
	for side, sx in ipairs({ -1, 1 }) do
		local p = at(F, sx * half, 0, F.front - 1.8)
		addPart(decor, "PlanterBox", Vector3.new(3.6, 1.2, 3.6), p * CFrame.new(0, 0.6, 0), WOOD, Enum.Material.WoodPlanks)
		addPart(decor, "PlanterSoil", Vector3.new(3.1, 0.2, 3.1), p * CFrame.new(0, 1.25, 0), RGB(92, 64, 44), Enum.Material.Ground)
		for k = 1, 9 do
			local a = k / 9 * math.pi * 2 + side
			local r = 0.5 + (k % 3) * 0.4
			local col = (k % 2 == 0) and accent or FLOWERS[(k + side) % #FLOWERS + 1]
			addBall(decor, "Flower", 0.75, p * CFrame.new(math.cos(a) * r, 1.75 + (k % 3) * 0.15, math.sin(a) * r), col, Enum.Material.SmoothPlastic)
		end
		addBall(decor, "Leaf", 1.6, p * CFrame.new(0, 1.7, 0), RGB(86, 164, 66), Enum.Material.Grass)
	end
end

local function goldPosts(decor, F)
	local half = F.width / 2 + 1
	for _, sx in ipairs({ -1, 1 }) do
		addCylinder(decor, "GoldPost", 0.6, F.height + 1.2, at(F, sx * half, (F.height + 1.2) / 2, F.front - 0.8), GOLD, Enum.Material.Metal)
		addBall(decor, "GoldOrb", 1.1, at(F, sx * half, F.height + 1.7, F.front - 0.8), GOLD, Enum.Material.Metal)
	end
end

local function eggCenter(booth)
	local egg = booth:FindFirstChild("Egg")
	return egg and egg.Position
end

function builders.gold(decor, F, accent, booth)
	goldPosts(decor, F)
	local c = eggCenter(booth)
	if c then
		addCylinder(decor, "EggPad", 5.4, 0.18, CFrame.new(c.X, c.Y - 2.1, c.Z), GOLD, Enum.Material.Neon, 0.25)
	end
	addPart(decor, "GoldTrim", Vector3.new(F.width + 1, 0.5, 0.5), at(F, 0, 0.3, F.front - 0.4), GOLD, Enum.Material.Metal)
end

function builders.legend(decor, F, accent, booth)
	goldPosts(decor, F)
	local c = eggCenter(booth)
	if c then
		addCylinder(decor, "EggPad", 6.4, 0.2, CFrame.new(c.X, c.Y - 2.2, c.Z), GOLD, Enum.Material.Neon, 0.2)
		addCylinder(decor, "LightBeam", 1.4, 14, CFrame.new(c.X, c.Y + 7, c.Z), accent, Enum.Material.Neon, 0.7)
		local sparks = addPart(decor, "Sparkles", Vector3.new(1, 1, 1), CFrame.new(c.X, c.Y, c.Z), accent, Enum.Material.SmoothPlastic, 1)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(GOLD, accent)
		e.LightEmission = 1
		e.Rate = 14
		e.Lifetime = NumberRange.new(1.5, 2.5)
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		e.Parent = sparks
	end
	addPart(decor, "GoldTrim", Vector3.new(F.width + 1, 0.5, 0.5), at(F, 0, 0.3, F.front - 0.4), GOLD, Enum.Material.Metal)
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
