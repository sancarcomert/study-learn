-- ADIM 4/6: SPAWN + 3 LIDERLIK PANOSU (panolar cesmenin kuzeyinde, spawn'a bakar)
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
local sp = fresh("Spawn")
for k, x in ipairs({ -12, 0, 12 }) do
	local s = Instance.new("SpawnLocation")
	s.Name = "Spawn" .. k
	s.Anchored = true
	s.Size = Vector3.new(8, 0.2, 8)
	s.CFrame = CFrame.new(x, 0.3, 48)
	s.Transparency = 1
	s.CanCollide = false
	s.Neutral = true
	s.Duration = 0
	s.Locked = true
	s.Parent = sp
end
-- spawn alani: yere ince sari serit (karsilama)
P(sp, "SpawnMark", Vector3.new(36, 0.06, 12), CFrame.new(0, 0.17, 48), RGB(255, 214, 140), Mat.Slate, NOCOL)
local bd = fresh("Boards")
local DARK, SIGN = RGB(118, 82, 52), RGB(228, 194, 140)
local TITLES = { { "Raised", "EN COK TOPLAYAN" }, { "Donated", "EN COK BAGISLAYAN" }, { "Level", "EN YUKSEK YUMURTA" } }
for i, t in ipairs(TITLES) do
	local x = (i - 2) * 20
	local base = CFrame.new(x, 0, -55) * CFrame.Angles(0, math.pi, 0) -- guneye (+Z) bakar
	for _, lx in ipairs({ -6, 6 }) do
		P(bd, "BoardLeg", Vector3.new(1, 3, 1), base * CFrame.new(lx, 1.5, 0), DARK, Mat.WoodPlanks)
	end
	P(bd, "BoardFrame", Vector3.new(16.8, 10.8, 1), base * CFrame.new(0, 8.4, 0), DARK, Mat.WoodPlanks)
	local face = P(bd, "Board_" .. t[1], Vector3.new(16, 10, 0.4), base * CFrame.new(0, 8.4, -0.55), SIGN, Mat.WoodPlanks)
	face:SetAttribute("Stat", t[1])
	CS:AddTag(face, "LeaderboardBoard")
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = face
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.2)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = RGB(84, 52, 28)
	title.Text = t[2]
	title.Parent = sg
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.fromScale(0, 0.22)
	body.Size = UDim2.fromScale(1, 0.7)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamBold
	body.TextScaled = true
	body.TextColor3 = RGB(110, 80, 50)
	body.Text = "..."
	body.Parent = sg
	P(bd, "BoardTop", Vector3.new(17.4, 0.6, 1.4), base * CFrame.new(0, 14.1, 0), RGB(255, 205, 60), Mat.Metal, NOCOL)
end
print("[Adim 4] Spawn (3 nokta) + 3 pano hazir")
