-- ADIM 5/6: 24 STAND (alcak ve acik tezgah; her stand kendi renginde)
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
local rng = Random.new(51)
local folder = W:FindFirstChild("Booths")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Booths"
	folder.Parent = W
end
folder:ClearAllChildren()
local COLORS = { RGB(214, 72, 72), RGB(66, 132, 214), RGB(244, 190, 50), RGB(150, 98, 200), RGB(236, 128, 48), RGB(52, 170, 160), RGB(232, 110, 156), RGB(96, 168, 72) }
local WL, WD, SIGN = RGB(190, 144, 94), RGB(118, 82, 52), RGB(228, 194, 140)

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
	local egg = Ell(m, "Egg", Vector3.new(2.2, 3, 2.2), L(0, 9.4, 2.8), RGB(244, 247, 250), Mat.Neon, NOCOL)
	CS:AddTag(egg, "FX_Bob")
	egg:SetAttribute("BobHeight", 0.2)
	egg:SetAttribute("BobSpeed", 1.2)
	egg:SetAttribute("BobPhase", rng:NextNumber(0, TAU))
	local base = P(m, "Base", Vector3.new(1, 1, 1), L(0, 4.4, -2.6), RGB(255, 255, 255), Mat.SmoothPlastic, { tr = 1, solid = false, shadow = false })
	m.PrimaryPart = base
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = folder
end

local i = 0
for side = 0, 3 do
	local rot = sideRot(side)
	for _, off in ipairs({ -65, -41, -17, 17, 41, 65 }) do
		i = i + 1
		booth(i, CFrame.new(rot * Vector3.new(off, 0, -88)) * rot * CFrame.Angles(0, math.pi, 0))
	end
end
print("[Adim 5] " .. i .. " stand hazir")
