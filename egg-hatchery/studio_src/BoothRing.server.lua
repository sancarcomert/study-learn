-- BoothRing (Script, "BoothRing" parcasinin icinde): Play'de sari dairenin yerine/boyutuna gore standlari halka yapar.
local disc = script.Parent
local CENTER_X, CENTER_Z = disc.Position.X, disc.Position.Z
local FLOOR_Y = disc.Position.Y -- dairenin merkezi zemin yuzeyine oturtulmali
local RADIUS = math.min(disc.Size.Y, disc.Size.Z) / 2 -- dairenin yaricapi
disc.Transparency = 1
disc.CanCollide = false
disc.CanQuery = false
disc.CanTouch = false
local W = game:GetService("Workspace")
local CS = game:GetService("CollectionService")
local RGB, Mat = Color3.fromRGB, Enum.Material
local TAU = math.pi * 2
local rng = Random.new(51)
local UP = CFrame.Angles(0, 0, math.rad(90))
local NOCOL = { solid = false, shadow = false }
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
local function Cyl(parent, name, d, h, cf, color, mat)
	return P(parent, name, Vector3.new(h, d, d), cf * UP, color, mat, { shape = Enum.PartType.Cylinder })
end
local COLORS = { RGB(214, 72, 72), RGB(66, 132, 214), RGB(244, 190, 50), RGB(150, 98, 200), RGB(236, 128, 48), RGB(52, 170, 160), RGB(232, 110, 156), RGB(96, 168, 72) }
local WL, WD, SIGN = RGB(190, 144, 94), RGB(118, 82, 52), RGB(228, 194, 140)

local folder = W:FindFirstChild("Booths")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Booths"
	folder.Parent = W
end
folder:ClearAllChildren()

local function booth(i, cf)
	local ac = COLORS[(i * 3) % #COLORS + 1]
	local function L(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local m = Instance.new("Model")
	m.Name = "Booth_" .. i
	P(m, "Platform", Vector3.new(17, 0.5, 8), L(0, 0.25, 0), WL, Mat.WoodPlanks)
	P(m, "Counter", Vector3.new(12, 2.4, 1.6), L(0, 1.7, -2.6), ac, Mat.WoodPlanks)
	P(m, "CounterTop", Vector3.new(13, 0.3, 2.4), L(0, 3.05, -2.6), WL, Mat.WoodPlanks)
	for _, lx in ipairs({ -5.8, 5.8 }) do
		P(m, "SignLeg", Vector3.new(0.8, 2.9, 0.6), L(lx, 1.95, 2.8), WD, Mat.WoodPlanks)
	end
	P(m, "SignFrame", Vector3.new(14, 4.2, 0.5), L(0, 5.4, 2.8), WD, Mat.WoodPlanks)
	local board = P(m, "SignBoard", Vector3.new(13.2, 3.4, 0.2), L(0, 5.4, 2.45), SIGN, Mat.WoodPlanks)
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
	CS:AddTag(label, "BoothSign")
	label:SetAttribute("BoothNumber", i)
	Cyl(m, "EggStand", 2.4, 0.4, L(0, 7.7, 2.8), WD, Mat.Wood)
	local egg = P(m, "Egg", Vector3.new(2.2, 3, 2.2), L(0, 9.4, 2.8), RGB(244, 247, 250), Mat.Neon, NOCOL)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	CS:AddTag(egg, "FX_Bob")
	egg:SetAttribute("BobHeight", 0.2)
	egg:SetAttribute("BobSpeed", 1.2)
	egg:SetAttribute("BobPhase", rng:NextNumber(0, TAU))
	local base = P(m, "Base", Vector3.new(1, 1, 1), L(0, 4.4, -2.6), RGB(255, 255, 255), Mat.SmoothPlastic, { tr = 1, solid = false, shadow = false })
	m.PrimaryPart = base
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = folder
end

-- halkaya sigacak en fazla stand (komsu standlar arasi en az ~3 stud bosluk)
local maxN = math.floor(math.pi / math.asin(math.min(1, 10 / (RADIUS - 4))))
local N = math.max(6, math.min(24, maxN))
local center = Vector3.new(CENTER_X, FLOOR_Y, CENTER_Z)
for i = 1, N do
	local a = (i - 1) / N * TAU
	local pos = center + Vector3.new(math.cos(a) * RADIUS, 0, math.sin(a) * RADIUS)
	booth(i, CFrame.lookAt(pos, center)) -- on yuz (-Z) merkeze bakar
end
print(string.format("[Halka] %d stand dizildi (yaricap %.0f, merkez %.0f, %.0f). Standlar cakisiyorsa RADIUS'u buyut.", N, RADIUS, CENTER_X, CENTER_Z))
