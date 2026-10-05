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
