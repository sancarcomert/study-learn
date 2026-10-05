-- dev/mock_roblox.lua
-- Gercek Luau yorumlayicisinda (Roblox'suz) calistirilan KATI bir Roblox API taklidi.
-- Amac: Studio'ya yapistirmadan once yanlis ozellik adi / yanlis tur / NaN / null hatalarini yakalamak.
-- Bilinmeyen ozellik, yanlis turde deger, gecersiz Enum uyesi -> hata verir.

local function isType(v, name)
	return type(v) == "table" and rawget(v, "__type") == name
end

local function isNaN(x)
	return x ~= x
end

---------------------------------------------------------------------
-- Vector3 / Vector2
---------------------------------------------------------------------
Vector3 = {}
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return Vector3.new(0, 0, 0)
		end
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif k == "Cross" then
		return function(a, b)
			return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return Vector3.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
		end
	end
	error("Vector3 uyesi yok: " .. tostring(k), 2)
end
V3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("%g, %g, %g", a.X, a.Y, a.Z)
end
function Vector3.new(x, y, z)
	x, y, z = x or 0, y or 0, z or 0
	assert(type(x) == "number" and type(y) == "number" and type(z) == "number", "Vector3.new: sayi bekleniyor")
	assert(not (isNaN(x) or isNaN(y) or isNaN(z)), "Vector3.new: NaN")
	return setmetatable({ __type = "Vector3", X = x, Y = y, Z = z }, V3)
end

Vector2 = {}
local V2 = {}
V2.__index = function(_, k)
	error("Vector2 uyesi yok: " .. tostring(k), 2)
end
function Vector2.new(x, y)
	return setmetatable({ __type = "Vector2", X = x or 0, Y = y or 0 }, V2)
end

UDim = {}
function UDim.new(s, o)
	return { __type = "UDim", Scale = s or 0, Offset = o or 0 }
end
UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	return { __type = "UDim2", XS = xs or 0, XO = xo or 0, YS = ys or 0, YO = yo or 0 }
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end

---------------------------------------------------------------------
-- CFrame (satir-oncelikli 3x3 + konum)
---------------------------------------------------------------------
CFrame = {}
local CF = {}

local function newCF(m)
	for i = 1, 12 do
		assert(type(m[i]) == "number" and not isNaN(m[i]), "CFrame: gecersiz bilesen #" .. i)
	end
	return setmetatable({ __type = "CFrame", m = m }, CF)
end

local function mulCF(a, b)
	local A, B = a.m, b.m
	return newCF({
		A[4] * B[1] + A[5] * B[2] + A[6] * B[3] + A[1],
		A[7] * B[1] + A[8] * B[2] + A[9] * B[3] + A[2],
		A[10] * B[1] + A[11] * B[2] + A[12] * B[3] + A[3],
		A[4] * B[4] + A[5] * B[7] + A[6] * B[10],
		A[4] * B[5] + A[5] * B[8] + A[6] * B[11],
		A[4] * B[6] + A[5] * B[9] + A[6] * B[12],
		A[7] * B[4] + A[8] * B[7] + A[9] * B[10],
		A[7] * B[5] + A[8] * B[8] + A[9] * B[11],
		A[7] * B[6] + A[8] * B[9] + A[9] * B[12],
		A[10] * B[4] + A[11] * B[7] + A[12] * B[10],
		A[10] * B[5] + A[11] * B[8] + A[12] * B[11],
		A[10] * B[6] + A[11] * B[9] + A[12] * B[12],
	})
end

local function xformV(a, v)
	local A = a.m
	return Vector3.new(
		A[4] * v.X + A[5] * v.Y + A[6] * v.Z + A[1],
		A[7] * v.X + A[8] * v.Y + A[9] * v.Z + A[2],
		A[10] * v.X + A[11] * v.Y + A[12] * v.Z + A[3]
	)
end

local function inverseCF(a)
	local A = a.m
	local r11, r12, r13, r21, r22, r23, r31, r32, r33 = A[4], A[5], A[6], A[7], A[8], A[9], A[10], A[11], A[12]
	-- R^T
	local px = -(r11 * A[1] + r21 * A[2] + r31 * A[3])
	local py = -(r12 * A[1] + r22 * A[2] + r32 * A[3])
	local pz = -(r13 * A[1] + r23 * A[2] + r33 * A[3])
	return newCF({ px, py, pz, r11, r21, r31, r12, r22, r32, r13, r23, r33 })
end

CF.__index = function(c, k)
	local A = c.m
	if k == "Position" then
		return Vector3.new(A[1], A[2], A[3])
	elseif k == "X" then
		return A[1]
	elseif k == "Y" then
		return A[2]
	elseif k == "Z" then
		return A[3]
	elseif k == "RightVector" then
		return Vector3.new(A[4], A[7], A[10])
	elseif k == "UpVector" then
		return Vector3.new(A[5], A[8], A[11])
	elseif k == "LookVector" then
		return Vector3.new(-A[6], -A[9], -A[12])
	elseif k == "Inverse" then
		return inverseCF
	elseif k == "PointToWorldSpace" then
		return xformV
	end
	error("CFrame uyesi yok: " .. tostring(k), 2)
end
CF.__mul = function(a, b)
	if isType(b, "CFrame") then
		return mulCF(a, b)
	elseif isType(b, "Vector3") then
		return xformV(a, b)
	end
	error("CFrame * (gecersiz tur)", 2)
end
CF.__add = function(a, b)
	assert(isType(b, "Vector3"), "CFrame + Vector3 olmali")
	local A = a.m
	return newCF({ A[1] + b.X, A[2] + b.Y, A[3] + b.Z, A[4], A[5], A[6], A[7], A[8], A[9], A[10], A[11], A[12] })
end
CF.__sub = function(a, b)
	assert(isType(b, "Vector3"), "CFrame - Vector3 olmali")
	local A = a.m
	return newCF({ A[1] - b.X, A[2] - b.Y, A[3] - b.Z, A[4], A[5], A[6], A[7], A[8], A[9], A[10], A[11], A[12] })
end
CF.__tostring = function(c)
	return table.concat(c.m, ", ")
end

local function lookAtCF(at, target, up)
	up = up or Vector3.new(0, 1, 0)
	local look = (target - at).Unit
	local right = look:Cross(up).Unit
	local u = right:Cross(look)
	return newCF({ at.X, at.Y, at.Z, right.X, u.X, -look.X, right.Y, u.Y, -look.Y, right.Z, u.Z, -look.Z })
end

function CFrame.new(a, b, c)
	if a == nil then
		return newCF({ 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 })
	elseif isType(a, "Vector3") then
		if isType(b, "Vector3") then
			return lookAtCF(a, b)
		end
		return newCF({ a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1 })
	end
	assert(type(a) == "number" and type(b) == "number" and type(c) == "number", "CFrame.new: gecersiz arguman")
	return newCF({ a, b, c, 1, 0, 0, 0, 1, 0, 0, 0, 1 })
end
function CFrame.lookAt(at, target, up)
	return lookAtCF(at, target, up)
end
function CFrame.Angles(rx, ry, rz)
	assert(type(rx) == "number" and type(ry) == "number" and type(rz) == "number", "CFrame.Angles: sayi bekleniyor")
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = newCF({ 0, 0, 0, 1, 0, 0, 0, cx, -sx, 0, sx, cx })
	local Ry = newCF({ 0, 0, 0, cy, 0, sy, 0, 1, 0, -sy, 0, cy })
	local Rz = newCF({ 0, 0, 0, cz, -sz, 0, sz, cz, 0, 0, 0, 1 })
	return mulCF(mulCF(Rx, Ry), Rz)
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFrame.identity = CFrame.new()

---------------------------------------------------------------------
-- Color3, Sequence'ler
---------------------------------------------------------------------
Color3 = {}
local C3 = {}
C3.__index = function(c, k)
	if k == "Lerp" then
		return function(a, b, t)
			return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end
	end
	error("Color3 uyesi yok: " .. tostring(k), 2)
end
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
function Color3.new(r, g, b)
	assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "Color3.new: sayi bekleniyor")
	assert(not (isNaN(r) or isNaN(g) or isNaN(b)), "Color3: NaN")
	return setmetatable({ __type = "Color3", R = math.clamp(r, 0, 1), G = math.clamp(g, 0, 1), B = math.clamp(b, 0, 1) }, C3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
function Color3.fromHSV(h, s, v)
	assert(type(h) == "number" and type(s) == "number" and type(v) == "number", "Color3.fromHSV: sayi bekleniyor")
	h = h % 1
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then
		return Color3.new(v, t, p)
	elseif i == 1 then
		return Color3.new(q, v, p)
	elseif i == 2 then
		return Color3.new(p, v, t)
	elseif i == 3 then
		return Color3.new(p, q, v)
	elseif i == 4 then
		return Color3.new(t, p, v)
	end
	return Color3.new(v, p, q)
end

ColorSequence = {}
function ColorSequence.new(a, b)
	if isType(a, "Color3") and isType(b, "Color3") then
		return { __type = "ColorSequence", keys = { { 0, a }, { 1, b } } }
	elseif isType(a, "Color3") then
		return { __type = "ColorSequence", keys = { { 0, a }, { 1, a } } }
	end
	assert(type(a) == "table" and #a >= 2, "ColorSequence.new: en az 2 anahtar")
	return { __type = "ColorSequence", keys = a }
end

NumberSequenceKeypoint = {}
function NumberSequenceKeypoint.new(t, v, e)
	assert(type(t) == "number" and type(v) == "number", "NumberSequenceKeypoint.new: sayi bekleniyor")
	assert(t >= 0 and t <= 1, "NumberSequenceKeypoint zamani 0..1 olmali")
	return { __type = "NumberSequenceKeypoint", Time = t, Value = v, Envelope = e or 0 }
end
NumberSequence = {}
function NumberSequence.new(a, b)
	if type(a) == "number" then
		return { __type = "NumberSequence", keys = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) } }
	end
	assert(type(a) == "table" and #a >= 2, "NumberSequence.new: en az 2 anahtar")
	assert(a[1].Time == 0 and a[#a].Time == 1, "NumberSequence: ilk anahtar 0, son anahtar 1 olmali")
	for i = 2, #a do
		assert(a[i].Time >= a[i - 1].Time, "NumberSequence anahtarlari siralanmali")
	end
	return { __type = "NumberSequence", keys = a }
end
NumberRange = {}
function NumberRange.new(a, b)
	assert(type(a) == "number", "NumberRange.new: sayi bekleniyor")
	b = b or a
	assert(a <= b, "NumberRange: min <= max olmali")
	return { __type = "NumberRange", Min = a, Max = b }
end
TweenInfo = {}
function TweenInfo.new(...)
	return { __type = "TweenInfo", ... }
end

---------------------------------------------------------------------
-- Enum (katı beyaz liste)
---------------------------------------------------------------------
local ENUMS = {
	Material = "Plastic SmoothPlastic Neon Wood WoodPlanks Marble Basalt Slate CrackedLava Concrete Limestone Granite Pavement Brick Pebble Cobblestone Rock Sandstone CorrodedMetal DiamondPlate Foil Metal Grass LeafyGrass Sand Fabric Snow Mud Ground Asphalt Salt Ice Glacier Glass ForceField Air Water Cardboard Carpet CeramicTiles ClayRoofTiles RoofShingles Leather Plaster Rubber",
	PartType = "Ball Block Cylinder Wedge CornerWedge",
	SurfaceType = "Smooth Glue Weld Studs Inlet Universal Hinge Motor SteppingMotor SmoothNoOutlines",
	MeshType = "Head Torso Wedge Prism Pyramid ParallelRamp RightAngleRamp CornerWedge Brick Sphere Cylinder FileMesh",
	NormalId = "Top Bottom Back Front Right Left",
	SurfaceGuiSizingMode = "FixedSize PixelsPerStud",
	ModelStreamingMode = "Default Atomic Persistent PersistentPerPlayer Nonatomic",
	ParticleEmitterShape = "Box Sphere Cylinder Disc",
	ParticleEmitterShapeStyle = "Volume Surface",
	ParticleEmitterShapeInOut = "Outward Inward InAndOut",
	Font = "Gotham GothamBold GothamBlack GothamMedium GothamSemibold SourceSans SourceSansBold Arial Legacy",
	KeyCode = "E F Q R",
	EasingStyle = "Linear Sine Back Quad Quart Quint Bounce Elastic Exponential Circular Cubic",
	EasingDirection = "In Out InOut",
	ZIndexBehavior = "Global Sibling",
	ProductPurchaseDecision = "PurchaseGranted NotProcessedYet",
	InfoType = "Asset Product GamePass Subscription Bundle",
}
local enumItems = {}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		local list = ENUMS[enumName]
		if not list then
			error("Bilinmeyen Enum: Enum." .. tostring(enumName), 2)
		end
		local valid = {}
		for word in string.gmatch(list, "%S+") do
			valid[word] = true
		end
		return setmetatable({}, {
			__index = function(_, item)
				if not valid[item] then
					error("Bilinmeyen Enum uyesi: Enum." .. enumName .. "." .. tostring(item), 2)
				end
				local key = enumName .. "." .. item
				if not enumItems[key] then
					enumItems[key] = { __type = "EnumItem", EnumType = enumName, Name = item }
				end
				return enumItems[key]
			end,
		})
	end,
})

---------------------------------------------------------------------
-- Is parcacigi yardimcisi: olay isleyicileri ve task.spawn her zaman YENI coroutine'de calisir
-- (Roblox gibi); bu sayede isleyici icinde task.wait guvenle bekleyebilir.
---------------------------------------------------------------------
local mine = setmetatable({}, { __mode = "k" })
local function runThread(fn, ...)
	local co = coroutine.create(fn)
	mine[co] = true
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(tostring(err), 0)
	end
	return co
end

---------------------------------------------------------------------
-- Sinyal
---------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
local function newSignal()
	return setmetatable({ __type = "RBXScriptSignal", fns = {} }, Signal)
end
function Signal:Connect(fn)
	assert(type(fn) == "function", "Connect: fonksiyon bekleniyor")
	local conn = { fn = fn, connected = true }
	table.insert(self.fns, conn)
	conn.Disconnect = function()
		conn.connected = false
	end
	return conn
end
function Signal:Fire(...)
	for _, c in ipairs(self.fns) do
		if c.connected then
			runThread(c.fn, ...)
		end
	end
end

---------------------------------------------------------------------
-- Ozellik semalari
---------------------------------------------------------------------
local function tNum(lo, hi)
	return function(v)
		return type(v) == "number" and not isNaN(v) and (lo == nil or v >= lo) and (hi == nil or v <= hi)
	end
end
local tBool = function(v)
	return type(v) == "boolean"
end
local tStr = function(v)
	return type(v) == "string"
end
local function tT(name)
	return function(v)
		return isType(v, name)
	end
end
local function tEnum(name)
	return function(v)
		return isType(v, "EnumItem") and v.EnumType == name
	end
end
local tAny = function()
	return true
end
local tInst = function(v)
	return v == nil or isType(v, "Instance")
end
local tSize = function(v)
	return isType(v, "Vector3") and v.X >= 0.001 and v.Y >= 0.001 and v.Z >= 0.001 and v.X <= 2048 and v.Y <= 2048 and v.Z <= 2048
end

local PARENT = {
	Instance = nil,
	PVInstance = "Instance",
	BasePart = "PVInstance",
	Part = "BasePart",
	SpawnLocation = "Part",
	Model = "PVInstance",
	Workspace = "Model",
	Folder = "Instance",
	DataModelMesh = "Instance",
	SpecialMesh = "DataModelMesh",
	PointLight = "Instance",
	ParticleEmitter = "Instance",
	Beam = "Instance",
	Attachment = "Instance",
	GuiBase2d = "Instance",
	SurfaceGui = "Instance",
	BillboardGui = "Instance",
	TextLabel = "Instance",
	Frame = "Instance",
	UICorner = "Instance",
	ProximityPrompt = "Instance",
	RemoteEvent = "Instance",
	ModuleScript = "Instance",
	Script = "Instance",
	LocalScript = "Instance",
	Atmosphere = "Instance",
	Sky = "Instance",
	BloomEffect = "Instance",
	ColorCorrectionEffect = "Instance",
	DepthOfFieldEffect = "Instance",
	SunRaysEffect = "Instance",
	Lighting = "Instance",
	Players = "Instance",
	ReplicatedStorage = "Instance",
	Player = "Instance",
	IntValue = "Instance",
}

local SCHEMA = {
	Instance = { Name = tStr, Parent = tInst },
	BasePart = {
		Anchored = tBool,
		Size = tSize,
		CFrame = tT("CFrame"),
		Color = tT("Color3"),
		Material = tEnum("Material"),
		Transparency = tNum(0, 1),
		Reflectance = tNum(0, 1),
		CanCollide = tBool,
		CanTouch = tBool,
		CanQuery = tBool,
		CastShadow = tBool,
		TopSurface = tEnum("SurfaceType"),
		BottomSurface = tEnum("SurfaceType"),
	},
	Part = { Shape = tEnum("PartType") },
	SpawnLocation = { Neutral = tBool, Duration = tNum(0), Enabled = tBool, AllowTeamChangeOnTouch = tBool },
	Model = { PrimaryPart = tInst, ModelStreamingMode = tEnum("ModelStreamingMode"), WorldPivot = tT("CFrame") },
	SpecialMesh = { MeshType = tEnum("MeshType"), Scale = tT("Vector3"), Offset = tT("Vector3") },
	PointLight = { Brightness = tNum(0), Color = tT("Color3"), Range = tNum(0, 60), Shadows = tBool, Enabled = tBool },
	ParticleEmitter = {
		Texture = tStr,
		Color = tT("ColorSequence"),
		LightEmission = tNum(0, 1),
		LightInfluence = tNum(0, 1),
		Rate = tNum(0),
		Lifetime = tT("NumberRange"),
		Speed = tT("NumberRange"),
		SpreadAngle = tT("Vector2"),
		Size = tT("NumberSequence"),
		Transparency = tT("NumberSequence"),
		Acceleration = tT("Vector3"),
		Rotation = tT("NumberRange"),
		RotSpeed = tT("NumberRange"),
		Shape = tEnum("ParticleEmitterShape"),
		ShapeStyle = tEnum("ParticleEmitterShapeStyle"),
		ShapeInOut = tEnum("ParticleEmitterShapeInOut"),
		Enabled = tBool,
		Drag = tNum(0),
		LockedToPart = tBool,
		ZOffset = tNum(),
	},
	Beam = {
		Attachment0 = tInst,
		Attachment1 = tInst,
		Color = tT("ColorSequence"),
		Transparency = tT("NumberSequence"),
		Width0 = tNum(0),
		Width1 = tNum(0),
		FaceCamera = tBool,
		LightEmission = tNum(0, 1),
		LightInfluence = tNum(0, 1),
		Segments = tNum(1),
		Texture = tStr,
		Enabled = tBool,
		CurveSize0 = tNum(),
		CurveSize1 = tNum(),
		ZOffset = tNum(),
	},
	Attachment = { Position = tT("Vector3"), CFrame = tT("CFrame") },
	SurfaceGui = {
		Face = tEnum("NormalId"),
		SizingMode = tEnum("SurfaceGuiSizingMode"),
		PixelsPerStud = tNum(1),
		LightInfluence = tNum(0, 1),
		AlwaysOnTop = tBool,
		Adornee = tInst,
		Enabled = tBool,
		Brightness = tNum(0),
		CanvasSize = tT("Vector2"),
		ZIndexBehavior = tEnum("ZIndexBehavior"),
	},
	BillboardGui = {
		Size = tT("UDim2"),
		StudsOffset = tT("Vector3"),
		MaxDistance = tNum(0),
		AlwaysOnTop = tBool,
		Adornee = tInst,
		LightInfluence = tNum(0, 1),
	},
	TextLabel = {
		BackgroundTransparency = tNum(0, 1),
		BackgroundColor3 = tT("Color3"),
		Font = tEnum("Font"),
		Size = tT("UDim2"),
		Position = tT("UDim2"),
		Text = tStr,
		TextColor3 = tT("Color3"),
		TextScaled = tBool,
		TextSize = tNum(1),
		TextStrokeTransparency = tNum(0, 1),
		AnchorPoint = tT("Vector2"),
	},
	Frame = {
		Position = tT("UDim2"),
		Size = tT("UDim2"),
		BackgroundColor3 = tT("Color3"),
		BackgroundTransparency = tNum(0, 1),
		BorderSizePixel = tNum(0),
		AnchorPoint = tT("Vector2"),
	},
	UICorner = { CornerRadius = tT("UDim") },
	ProximityPrompt = {
		ActionText = tStr,
		ObjectText = tStr,
		KeyboardKeyCode = tEnum("KeyCode"),
		HoldDuration = tNum(0),
		MaxActivationDistance = tNum(0),
		RequiresLineOfSight = tBool,
		Enabled = tBool,
	},
	Atmosphere = {
		Color = tT("Color3"),
		Decay = tT("Color3"),
		Density = tNum(0, 1),
		Glare = tNum(0, 10),
		Haze = tNum(0, 10),
		Offset = tNum(0, 1),
	},
	Sky = { CelestialBodiesShown = tBool, StarCount = tNum(0, 5000), MoonAngularSize = tNum(), SunAngularSize = tNum() },
	BloomEffect = { Intensity = tNum(0), Size = tNum(0, 56), Threshold = tNum(0), Enabled = tBool },
	ColorCorrectionEffect = {
		Brightness = tNum(),
		Contrast = tNum(),
		Saturation = tNum(),
		TintColor = tT("Color3"),
		Enabled = tBool,
	},
	DepthOfFieldEffect = {
		FarIntensity = tNum(0, 1),
		FocusDistance = tNum(0),
		InFocusRadius = tNum(0),
		NearIntensity = tNum(0, 1),
		Enabled = tBool,
	},
	SunRaysEffect = { Intensity = tNum(0, 1), Spread = tNum(0, 1), Enabled = tBool },
	Lighting = {
		Ambient = tT("Color3"),
		OutdoorAmbient = tT("Color3"),
		Brightness = tNum(0),
		ClockTime = tNum(0, 24),
		ExposureCompensation = tNum(-5, 5),
		EnvironmentDiffuseScale = tNum(0, 1),
		EnvironmentSpecularScale = tNum(0, 1),
		GlobalShadows = tBool,
		GeographicLatitude = tNum(),
		ColorShift_Top = tT("Color3"),
		ColorShift_Bottom = tT("Color3"),
		ShadowSoftness = tNum(0, 1),
		FogColor = tT("Color3"),
		FogEnd = tNum(),
		FogStart = tNum(),
	},
	IntValue = { Value = tNum() },
	Player = { UserId = tNum(), Character = tInst },
}

local DEFAULTS = {
	Anchored = false,
	Transparency = 0,
	Reflectance = 0,
	CanCollide = true,
	CanTouch = true,
	CanQuery = true,
	CastShadow = true,
	Enabled = true,
	Size = nil,
	Value = 0,
}

local function chain(class)
	local list = {}
	while class do
		table.insert(list, class)
		class = PARENT[class]
	end
	return list
end

local function schemaFor(class, key)
	for _, c in ipairs(chain(class)) do
		local s = SCHEMA[c]
		if s and s[key] then
			return s[key]
		end
	end
	return nil
end

---------------------------------------------------------------------
-- Instance
---------------------------------------------------------------------
local Methods = {}
local IMT = {}
local ALL = {} -- olusturulan her ornek (istatistik icin)

local function d(self)
	return rawget(self, "_d")
end

local function isDescendantOf(inst, ancestor)
	local p = d(inst).parent
	while p do
		if p == ancestor then
			return true
		end
		p = d(p).parent
	end
	return false
end

local function detach(self)
	local data = d(self)
	if data.parent then
		local pd = d(data.parent)
		for i, c in ipairs(pd.children) do
			if c == self then
				table.remove(pd.children, i)
				break
			end
		end
		if pd.signals.ChildRemoved then
			pd.signals.ChildRemoved:Fire(self)
		end
	end
	data.parent = nil
end

local function getSignal(self, name)
	local data = d(self)
	if not data.signals[name] then
		data.signals[name] = newSignal()
	end
	return data.signals[name]
end

IMT.__index = function(self, key)
	local data = d(self)
	if key == "ClassName" then
		return data.class
	end
	if key == "Name" then
		return data.name
	end
	if key == "Parent" then
		return data.parent
	end
	if schemaFor(data.class, key) then
		local v = data.props[key]
		if v == nil then
			if key == "Position" then
				return data.props.CFrame.Position
			end
			if DEFAULTS[key] ~= nil then
				return DEFAULTS[key]
			end
			if key == "Size" or key == "CFrame" then
				error(data.class .. "." .. key .. " henuz atanmadi (mock)", 2)
			end
		end
		return v
	end
	if key == "Position" and data.props.CFrame then
		return data.props.CFrame.Position
	end
	if key == "ChildAdded" or key == "ChildRemoved" or key == "Changed" or key == "Triggered" or key == "OnServerEvent"
		or key == "Destroying" or key == "PlayerAdded" or key == "PlayerRemoving" or key == "OnClientEvent" then
		return getSignal(self, key)
	end
	if Methods[key] then
		return Methods[key]
	end
	for _, c in ipairs(data.children) do
		if d(c).name == key then
			return c
		end
	end
	error(string.format("'%s' bir %s uyesi degil (mock)", tostring(key), data.class), 2)
end

IMT.__newindex = function(self, key, value)
	local data = d(self)
	if key == "Name" then
		assert(type(value) == "string", "Name string olmali")
		data.name = value
		return
	end
	if key == "Parent" then
		assert(value == nil or isType(value, "Instance"), "Parent bir Instance olmali")
		if value ~= nil then
			assert(not data.destroyed, "Destroy edilmis ornege Parent atanamaz: " .. data.name)
			assert(value ~= self and not isDescendantOf(value, self), "Dongusel Parent")
		end
		detach(self)
		if value ~= nil then
			data.parent = value
			table.insert(d(value).children, self)
			local sig = d(value).signals.ChildAdded
			if sig then
				sig:Fire(self)
			end
		end
		return
	end
	local check = schemaFor(data.class, key)
	if not check then
		error(string.format("'%s' bir %s ozelligi degil (mock)", tostring(key), data.class), 2)
	end
	if not check(value) then
		local shown = type(value) == "table" and (rawget(value, "__type") or "table") or tostring(value)
		error(string.format("%s.%s icin gecersiz deger: %s", data.class, key, shown), 2)
	end
	data.props[key] = value
	if data.signals.Changed then
		data.signals.Changed:Fire(key)
	end
end

IMT.__tostring = function(self)
	return d(self).name
end

Instance = {}
function Instance.new(class, parent)
	if PARENT[class] == nil and class ~= "Instance" then
		error("Bilinmeyen sinif: " .. tostring(class), 2)
	end
	local self = setmetatable({
		__type = "Instance",
		_d = { class = class, name = class, props = {}, children = {}, parent = nil, attrs = {}, signals = {}, destroyed = false },
	}, IMT)
	table.insert(ALL, self)
	if parent then
		self.Parent = parent
	end
	return self
end

local function descendants(self, out)
	for _, c in ipairs(d(self).children) do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end

function Methods.GetChildren(self)
	return table.clone(d(self).children)
end
function Methods.GetDescendants(self)
	return descendants(self, {})
end
function Methods.FindFirstChild(self, name, recursive)
	for _, c in ipairs(d(self).children) do
		if d(c).name == name then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(descendants(self, {})) do
			if d(c).name == name then
				return c
			end
		end
	end
	return nil
end
function Methods.WaitForChild(self, name)
	local c = Methods.FindFirstChild(self, name)
	assert(c, "WaitForChild: '" .. name .. "' bulunamadi (mock sonsuza kadar beklerdi)")
	return c
end
function Methods.IsA(self, class)
	for _, c in ipairs(chain(d(self).class)) do
		if c == class then
			return true
		end
	end
	return false
end
function Methods.FindFirstChildWhichIsA(self, class, recursive)
	local list = recursive and descendants(self, {}) or d(self).children
	for _, c in ipairs(list) do
		if Methods.IsA(c, class) then
			return c
		end
	end
	return nil
end
function Methods.FindFirstChildOfClass(self, class)
	for _, c in ipairs(d(self).children) do
		if d(c).class == class then
			return c
		end
	end
	return nil
end
function Methods.FindFirstAncestorOfClass(self, class)
	local p = d(self).parent
	while p do
		if d(p).class == class then
			return p
		end
		p = d(p).parent
	end
	return nil
end
function Methods.IsDescendantOf(self, ancestor)
	return isDescendantOf(self, ancestor)
end
function Methods.GetFullName(self)
	local names = { d(self).name }
	local p = d(self).parent
	while p do
		table.insert(names, 1, d(p).name)
		p = d(p).parent
	end
	return table.concat(names, ".")
end
function Methods.Destroy(self)
	local data = d(self)
	for _, c in ipairs(table.clone(data.children)) do
		Methods.Destroy(c)
	end
	detach(self)
	data.destroyed = true
	if data.signals.Destroying then
		data.signals.Destroying:Fire()
	end
end
function Methods.ClearAllChildren(self)
	for _, c in ipairs(table.clone(d(self).children)) do
		Methods.Destroy(c)
	end
end
local ATTR_OK = { boolean = true, number = true, string = true }
function Methods.SetAttribute(self, name, value)
	assert(type(name) == "string" and #name > 0, "Attribute adi string olmali")
	assert(not string.find(name, "^RBX"), "RBX ile baslayan attribute adi yasak")
	local ok = value == nil or ATTR_OK[type(value)] or isType(value, "Vector3") or isType(value, "Color3") or isType(value, "CFrame")
	assert(ok, "Attribute turu desteklenmiyor: " .. name)
	if type(value) == "number" then
		assert(not isNaN(value), "Attribute NaN")
	end
	d(self).attrs[name] = value
	local sig = d(self).signals["Attr_" .. name]
	if sig then
		sig:Fire()
	end
end
function Methods.GetAttribute(self, name)
	return d(self).attrs[name]
end
function Methods.GetAttributes(self)
	return table.clone(d(self).attrs)
end
function Methods.GetAttributeChangedSignal(self, name)
	return getSignal(self, "Attr_" .. name)
end
function Methods.GetPropertyChangedSignal(self, name)
	return getSignal(self, "Prop_" .. name)
end

-- Pivot (Model: PrimaryPart ya da ilk parca; Part: CFrame)
local function pivotPart(self)
	local data = d(self)
	if data.class == "Model" or data.class == "Workspace" then
		return data.props.PrimaryPart
	end
	return self
end
function Methods.GetPivot(self)
	local data = d(self)
	if Methods.IsA(self, "BasePart") then
		return data.props.CFrame
	end
	local pp = data.props.PrimaryPart
	assert(pp, "GetPivot: PrimaryPart yok (mock): " .. data.name)
	return d(pp).props.CFrame
end
function Methods.PivotTo(self, cf)
	assert(isType(cf, "CFrame"), "PivotTo: CFrame bekleniyor")
	if Methods.IsA(self, "BasePart") then
		self.CFrame = cf
		return
	end
	local old = Methods.GetPivot(self)
	local ok, err = pcall(function()
		local delta = cf * inverseCF(old)
		for _, c in ipairs(descendants(self, {})) do
			if Methods.IsA(c, "BasePart") then
				c.CFrame = delta * c.CFrame
			end
		end
	end)
	if not ok then
		error("PivotTo(" .. d(self).name .. ") hata: " .. tostring(err) .. " | hedef=" .. tostring(cf) .. " | eski=" .. tostring(old), 2)
	end
end
function Methods.FireAllClients(self, ...)
	d(self).fired = d(self).fired or {}
	table.insert(d(self).fired, { ... })
end
function Methods.FireClient(self, ...)
	d(self).fired = d(self).fired or {}
	table.insert(d(self).fired, { ... })
end
function Methods.GetServerTimeNow(self)
	return MOCK_TIME or 0
end
function Methods.LoadCharacter() end
function Methods.GetPlayers(self)
	local out = {}
	for _, c in ipairs(d(self).children) do
		if d(c).class == "Player" then
			table.insert(out, c)
		end
	end
	return out
end
function Methods.GetPlayerByUserId(self, id)
	for _, c in ipairs(d(self).children) do
		if d(c).class == "Player" and d(c).props.UserId == id then
			return c
		end
	end
	return nil
end
function __fire(inst, signalName, ...)
	getSignal(inst, signalName):Fire(...)
end
function Methods.Emit(self, n)
	d(self).emitted = (d(self).emitted or 0) + n
end

-- Instance.new("X") uretilen tum ornekleri sayan yardimci
function __allInstances()
	return ALL
end

---------------------------------------------------------------------
-- Servisler
---------------------------------------------------------------------
local services = {}
local workspaceInst = Instance.new("Workspace")
workspaceInst.Name = "Workspace"
workspace = workspaceInst
services.Workspace = workspaceInst

local lightingInst = Instance.new("Lighting")
lightingInst.Name = "Lighting"
services.Lighting = lightingInst

services.ReplicatedStorage = Instance.new("ReplicatedStorage")
services.ReplicatedStorage.Name = "ReplicatedStorage"
services.Players = Instance.new("Players")
services.Players.Name = "Players"

-- CollectionService
local tags = {} -- [tag] = { [inst] = true }
local instTags = {}
local tagAdded, tagRemoved = {}, {}
services.CollectionService = {
	AddTag = function(_, inst, tag)
		assert(isType(inst, "Instance"), "AddTag: Instance bekleniyor")
		assert(type(tag) == "string", "AddTag: tag string olmali")
		tags[tag] = tags[tag] or {}
		tags[tag][inst] = true
		instTags[inst] = instTags[inst] or {}
		instTags[inst][tag] = true
	end,
	RemoveTag = function(_, inst, tag)
		if tags[tag] then
			tags[tag][inst] = nil
		end
	end,
	HasTag = function(_, inst, tag)
		return tags[tag] ~= nil and tags[tag][inst] == true
	end,
	GetTags = function(_, inst)
		local out = {}
		for t in pairs(instTags[inst] or {}) do
			table.insert(out, t)
		end
		return out
	end,
	GetTagged = function(_, tag)
		local out = {}
		for inst in pairs(tags[tag] or {}) do
			if isDescendantOf(inst, workspaceInst) then
				table.insert(out, inst)
			end
		end
		return out
	end,
	GetInstanceAddedSignal = function(_, tag)
		tagAdded[tag] = tagAdded[tag] or newSignal()
		return tagAdded[tag]
	end,
	GetInstanceRemovedSignal = function(_, tag)
		tagRemoved[tag] = tagRemoved[tag] or newSignal()
		return tagRemoved[tag]
	end,
	__fireAdded = function(_, tag, inst)
		if tagAdded[tag] then
			tagAdded[tag]:Fire(inst)
		end
	end,
}

-- RunService
local heartbeat, renderStepped = newSignal(), newSignal()
services.RunService = {
	Heartbeat = heartbeat,
	RenderStepped = renderStepped,
	IsStudio = function()
		return true
	end,
	IsRunning = function()
		return true
	end,
	IsServer = function()
		return true
	end,
}

-- TweenService (hedef degerleri aninda uygular)
services.TweenService = {
	Create = function(_, inst, info, goals)
		assert(isType(inst, "Instance"), "TweenService:Create: Instance bekleniyor")
		return {
			Play = function()
				for k, v in pairs(goals) do
					inst[k] = v
				end
			end,
		}
	end,
}
services.Debris = {
	AddItem = function() end,
}
local stores = {}
services.DataStoreService = {
	GetDataStore = function(_, name)
		stores[name] = stores[name] or { data = {}, saves = 0, fail = false }
		local st = stores[name]
		return {
			GetAsync = function(_, key)
				if st.fail then
					error("mock datastore hatasi (GetAsync)")
				end
				return st.data[key]
			end,
			UpdateAsync = function(_, key, fn)
				if st.fail then
					error("mock datastore hatasi (UpdateAsync)")
				end
				local new = fn(st.data[key])
				if new ~= nil then
					st.data[key] = new
					st.saves = st.saves + 1
				end
				return new
			end,
		}
	end,
}
function __store(name)
	stores[name] = stores[name] or { data = {}, saves = 0, fail = false }
	return stores[name]
end

local productPrices = {}
function __setProductPrice(id, price)
	productPrices[id] = price
end
local marketplace = {
	prompts = {},
	PromptProductPurchaseFinished = newSignal(),
	GetProductInfo = function(_, id, infoType)
		local price = productPrices[id]
		if price == nil then
			error("mock: bilinmeyen urun " .. tostring(id))
		end
		return { PriceInRobux = price }
	end,
	PromptProductPurchase = function(self, player, id)
		table.insert(self.prompts, { player = player, id = id })
	end,
}
services.MarketplaceService = marketplace
game = {
	GetService = function(_, name)
		local s = services[name]
		assert(s, "Bilinmeyen servis (mock): " .. tostring(name))
		return s
	end,
	BindToClose = function(_, fn)
		__closeFns = __closeFns or {}
		table.insert(__closeFns, fn)
	end,
	Workspace = workspaceInst,
}
function __services()
	return services
end

---------------------------------------------------------------------
-- Genel yardimcilar
---------------------------------------------------------------------
MOCK_TIME = 0
function __setTime(t)
	MOCK_TIME = t
end
function __fireHeartbeat(dt)
	heartbeat:Fire(dt or 1 / 60)
end

local waiting = {}
local nowT = 0
task = {
	spawn = function(fn, ...)
		return runThread(fn, ...)
	end,
	defer = function(fn, ...)
		return runThread(fn, ...)
	end,
	delay = function(t, fn, ...)
		local args = { ... }
		runThread(function()
			task.wait(t)
			fn(table.unpack(args))
		end)
	end,
	wait = function(t)
		t = t or 0
		local co = coroutine.running()
		if mine[co] then
			table.insert(waiting, { co = co, wake = nowT + t })
			coroutine.yield()
		end
		return t
	end,
}
-- Sanal zamani ilerletir, uyanma zamani gelen coroutine'leri sirayla calistirir
function __advance(dt)
	local target = nowT + dt
	while true do
		local bestI, bestW
		for i, w in ipairs(waiting) do
			if w.wake <= target and (bestW == nil or w.wake < bestW) then
				bestI, bestW = i, w.wake
			end
		end
		if not bestI then
			break
		end
		local w = table.remove(waiting, bestI)
		nowT = math.max(nowT, w.wake)
		local ok, err = coroutine.resume(w.co)
		if not ok then
			error(tostring(err), 0)
		end
	end
	nowT = target
end
warn = function(...)
	print("[WARN]", ...)
end

-- Random: deterministik LCG
Random = {}
function Random.new(seed)
	local state = (seed or 0) * 2654435761 % 4294967296
	local function nextf()
		state = (state * 1664525 + 1013904223) % 4294967296
		return state / 4294967296
	end
	return {
		NextNumber = function(_, a, b)
			if a == nil then
				return nextf()
			end
			return a + (b - a) * nextf()
		end,
		NextInteger = function(_, a, b)
			return a + math.floor(nextf() * (b - a + 1))
		end,
	}
end

-- typeof: mock tablolari icin Roblox turunu dondur
local rawTypeof = typeof
typeof = function(v)
	if type(v) == "table" then
		local t = rawget(v, "__type")
		if t then
			return t
		end
	end
	return rawTypeof(v)
end

-- ModuleScript yukleyici: wrapper fonksiyonlari ile
__moduleFns = {}
local moduleCache = {}
local realRequire = require
require = function(inst)
	if isType(inst, "Instance") then
		local fn = __moduleFns[d(inst).name]
		assert(fn, "require: modul yok (mock): " .. tostring(d(inst).name))
		if moduleCache[inst] == nil then
			moduleCache[inst] = fn(inst)
		end
		return moduleCache[inst]
	end
	return realRequire(inst)
end
