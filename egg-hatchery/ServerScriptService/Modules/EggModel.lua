-- EggModel: stand ustundeki yumurtayi parcalardan kurar.
--
--   booth.Egg    (Model, PrimaryPart = Core)  kabuk (gercek yumurta profili), suslemeler, yoringedeki taslar, ic isik
--   booth.EggPad (Model)                      yumurtanin altindaki isik zemini ve (ust seviyelerde) isik sutunu
--
-- Kabuk, ust uca dogru daralan yumurta egrisine teget 13 kuredenin birlesimidir (en iyi dizilim baslangicta taranir, sapma ~0.01 stud).
-- Nadirlige gore malzeme, renk ve suslemeler degisir; oyuncunun sectigi renk suslemelere islenir.
-- Her parcanin "BO" (Core'a gore CFrame) ve "BS" (boyut) attribute'u vardir: olcek degisince sunucu
-- parcalari bunlardan yeniden dizer, istemci (MapFX) de ayni veriyle yumurtayi yuzdurur ve doner.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)

local EggModel = {}

local RGB = Color3.fromRGB

-- Yumurta olculeri (olcek 1'de, stud)
local HALF_W = 1.35 -- yarim genislik
local HALF_H = 1.8 -- yarim yukseklik
local TAPER = 0.3 -- ust uca dogru daralma (gercek yumurta gibi: en genis nokta ortanin biraz altinda)
local GAP = 0.8 -- zemin ile yumurtanin alt ucu arasi bosluk
local SHELL_BALLS = 13
EggModel.Height = GAP + 2 * HALF_H -- zeminden yumurtanin tepesine (olcek 1)

-- Gorunum seviyeleri: 0 = sahipsiz (soluk), 1..4 = Config.RARITIES sirasi
local TIERS = {
	[0] = { Shell = RGB(190, 186, 178), Material = Enum.Material.SmoothPlastic, Reflectance = 0, Specks = 0, Bands = 0, Gems = 0, Beam = false, PadAlpha = 0.9 },
	[1] = { Shell = RGB(246, 238, 218), Material = Enum.Material.SmoothPlastic, Reflectance = 0, Specks = 9, Bands = 1, Gems = 0, Beam = false, PadAlpha = 0.55 },
	[2] = { Shell = RGB(52, 108, 224), Material = Enum.Material.SmoothPlastic, Reflectance = 0.12, Specks = 0, Bands = 2, Gems = 3, Beam = false, PadAlpha = 0.45 },
	[3] = { Shell = RGB(232, 170, 28), Material = Enum.Material.Metal, Reflectance = 0.18, Specks = 0, Bands = 3, Gems = 4, Beam = true, PadAlpha = 0.35 },
	[4] = { Shell = RGB(236, 70, 206), Material = Enum.Material.Neon, Reflectance = 0, Specks = 0, Bands = 3, Gems = 6, Beam = true, PadAlpha = 0.25, DarkBands = true },
}
EggModel.TIERS = TIERS

local SPECK_COLOR = RGB(168, 128, 92)
local DARK_BAND = RGB(60, 14, 64)

---------------------------------------------------------------------
-- Yumurta profili ve kure dizilimi
---------------------------------------------------------------------
local function profile(y)
	local t = y / HALF_H
	return HALF_W * math.sqrt(math.max((1 - t * t) / (1 + TAPER * t), 0))
end

-- Yumurta egrisine en iyi uyan kure dizilimi: merkez aralik kaydirmasi ve ortak buyutme taranir
local shellBalls -- { {y, radius}, ... } (yumurta merkezine gore)
local function getShellBalls()
	if shellBalls then
		return shellBalls
	end
	local samples = {}
	for i = 0, 240 do
		local y = -HALF_H + 2 * HALF_H * i / 240
		table.insert(samples, { profile(y), y })
	end
	local bestErr = math.huge
	for w = -6, 6 do
		local warp = w * 0.05
		local balls = {}
		for i = 1, SHELL_BALLS do
			local u = (i - 0.5) / SHELL_BALLS
			local cy = -HALF_H + 2 * HALF_H * (u + warp * math.sin(2 * math.pi * u) / math.pi)
			local r = math.huge
			for _, s in ipairs(samples) do
				r = math.min(r, math.sqrt(s[1] * s[1] + (s[2] - cy) ^ 2))
			end
			table.insert(balls, { cy, r })
		end
		for g = 0, 8 do
			local grow = g * 0.01
			local err = 0
			for _, s in ipairs(samples) do
				local nearest = math.huge
				for _, b in ipairs(balls) do
					nearest = math.min(nearest, math.abs(math.sqrt(s[1] * s[1] + (s[2] - b[1]) ^ 2) - (b[2] + grow)))
				end
				err = math.max(err, nearest)
			end
			if err < bestErr then
				bestErr = err
				shellBalls = {}
				for _, b in ipairs(balls) do
					table.insert(shellBalls, { b[1], b[2] + grow })
				end
			end
		end
	end
	return shellBalls
end

---------------------------------------------------------------------
-- Parca yerlestirme: BO/BS attribute'lari + guncel olcekte konum
---------------------------------------------------------------------
local function rotationOf(cf)
	return cf - cf.Position
end

local function layoutPart(part, anchor, scale)
	local bo = part:GetAttribute("BO")
	local bs = part:GetAttribute("BS")
	if bo and bs then
		part.Size = bs * scale
		part.CFrame = anchor * CFrame.new(bo.Position * scale) * rotationOf(bo)
	end
end

local function newPart(parent, name, size, rel, color, material, transparency, ctx)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p:SetAttribute("BS", size)
	p:SetAttribute("BO", rel)
	layoutPart(p, ctx.anchor, ctx.scale)
	p.Parent = parent
	return p
end

local UP = CFrame.Angles(0, 0, math.rad(90))

local function newBall(parent, name, diameter, rel, color, material, ctx)
	local p = newPart(parent, name, Vector3.new(diameter, diameter, diameter), rel, color, material, 0, ctx)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Dikey silindir (eksen Y): yukseklik, cap
local function newDisc(parent, name, diameter, height, rel, color, material, transparency, ctx)
	local p = newPart(parent, name, Vector3.new(height, diameter, diameter), rel * UP, color, material, transparency, ctx)
	p.Shape = Enum.PartType.Cylinder
	return p
end

---------------------------------------------------------------------
-- Yumurta
---------------------------------------------------------------------
local function buildEgg(egg, tier, accent, seed, ctx)
	local look = TIERS[tier]
	local centerY = GAP + HALF_H

	-- kabuk
	for i, b in ipairs(getShellBalls()) do
		local ball = newBall(egg, "Shell" .. i, b[2] * 2, CFrame.new(0, centerY + b[1], 0), look.Shell, look.Material, ctx)
		ball.Reflectance = look.Reflectance
		ball.CastShadow = true
	end

	-- bantlar: yumurtayi saran ince halkalar
	local bandSpots = ({
		{},
		{ 0.05 },
		{ -0.30, 0.38 },
		{ -0.45, 0.0, 0.45 },
	})[look.Bands + 1]
	for i, f in ipairs(bandSpots) do
		local y = f * HALF_H
		local color = look.DarkBands and DARK_BAND or accent
		local mat = look.DarkBands and Enum.Material.SmoothPlastic or Enum.Material.Neon
		newDisc(egg, "Band" .. i, (profile(y) + 0.035) * 2, 0.1, CFrame.new(0, centerY + y, 0), color, mat, 0, ctx)
	end

	-- benekler: kabuga yarim gomulu kucuk toplar (her stand icin farkli dizilim)
	for i = 1, look.Specks do
		local a = i * 2.399963 + seed * 0.61
		local y = (-0.7 + 1.4 * (i - 1) / math.max(look.Specks - 1, 1)) * HALF_H
		local r = profile(y) * 0.985
		local d = 0.16 + 0.07 * (i % 3)
		newBall(egg, "Speck" .. i, d, CFrame.new(math.cos(a) * r, centerY + y, math.sin(a) * r), SPECK_COLOR, Enum.Material.SmoothPlastic, ctx)
	end

	-- yoringede donen taslar (donusu istemci yapar; burada baslangic konumlari)
	for i = 1, look.Gems do
		local ring = (look.Gems > 4 and (i % 2)) or 0
		local tilt = (look.Gems > 4) and (ring == 0 and 0.5 or -0.5) or (look.Gems == 4 and ((i % 2 == 0) and 0.35 or -0.35) or 0.25)
		local radius = HALF_W * (1.7 + 0.2 * ring)
		local speed = 0.9 + 0.12 * ring
		local phase = (i - 1) * (2 * math.pi / (look.Gems > 4 and look.Gems / 2 or look.Gems))
		local rest = CFrame.Angles(0, 0, tilt) * CFrame.Angles(0, phase, 0) * CFrame.new(radius, 0, 0)
		local gemRot = CFrame.Angles(math.rad(45), 0, math.rad(35.264)) -- kosesinde duran kup = elmas
		local gem = newPart(egg, "Gem" .. i, Vector3.new(0.34, 0.34, 0.34),
			CFrame.new(rest.Position + Vector3.new(0, centerY, 0)) * gemRot, accent, Enum.Material.Neon, 0, ctx)
		gem:SetAttribute("OR", radius)
		gem:SetAttribute("OS", speed)
		gem:SetAttribute("OP", phase)
		gem:SetAttribute("OT", tilt)
		gem:SetAttribute("OY", centerY)
		gem:SetAttribute("GR", gemRot)

		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name, a1.Name = "TrailTop", "TrailBottom"
		a0.Position, a1.Position = Vector3.new(0, 0.22, 0), Vector3.new(0, -0.22, 0)
		a0.Parent, a1.Parent = gem, gem
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.55
		trail.Color = ColorSequence.new(accent, Color3.new(1, 1, 1))
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = gem
	end

	-- kalp: isik ve kivilcim kaynagi (gorunmez)
	local heart = newPart(egg, "Heart", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, centerY, 0), accent, Enum.Material.SmoothPlastic, 1, ctx)
	heart.Shape = Enum.PartType.Ball
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Range = 14
	glow.Color = accent
	glow.Shadows = false
	glow.Brightness = (tier >= 2) and 0.7 or 0
	glow.Parent = heart
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.LightEmission = 1
	aura.Color = ColorSequence.new(accent, Color3.new(1, 1, 1))
	aura.Lifetime = NumberRange.new(1.2, 2)
	aura.Speed = NumberRange.new(1, 3)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	local rate = tier >= 2 and (Config.RARITIES[tier].AuraRate or 0) or 0
	aura.Rate = rate
	aura.Enabled = rate > 0
	aura.Parent = heart
end

local function buildPad(pad, tier, accent, ctx)
	local look = TIERS[tier]
	newDisc(pad, "PadOuter", HALF_W * 3.4, 0.05, CFrame.new(0, 0.03, 0), accent, Enum.Material.Neon, look.PadAlpha, ctx)
	newDisc(pad, "PadInner", HALF_W * 2.0, 0.05, CFrame.new(0, 0.07, 0), accent:Lerp(Color3.new(1, 1, 1), 0.55), Enum.Material.Neon, math.max(look.PadAlpha - 0.2, 0), ctx)
	if look.Beam then
		newDisc(pad, "Beam", 0.55, 15, CFrame.new(0, 7.6, 0), accent, Enum.Material.Neon, 0.82, ctx)
	end
end

---------------------------------------------------------------------
-- Disari acik
---------------------------------------------------------------------
local function clearContent(model, keep)
	for _, c in ipairs(model:GetChildren()) do
		if c ~= keep then
			c:Destroy()
		end
	end
end

local function seedOf(booth)
	local n = tonumber(string.match(booth.Name, "%d+"))
	return n or 1
end

function EggModel.TierOf(level)
	local tier = 1
	for i, r in ipairs(Config.RARITIES) do
		if level >= r.MinLevel then
			tier = i
		end
	end
	return tier
end

-- Egg + EggPad modellerini olusturur (sahipsiz gorunumle). anchor: zemin ortasi, on yone donuk CFrame
function EggModel.Build(booth, anchor)
	booth:SetAttribute("EggAnchor", anchor)

	local egg = booth:FindFirstChild("Egg")
	if egg and not egg:IsA("Model") then
		egg:Destroy() -- eski tek parcali yumurta
		egg = nil
	end
	if not egg then
		egg = Instance.new("Model")
		egg.Name = "Egg"
		local core = Instance.new("Part")
		core.Name = "Core"
		core.Anchored = true
		core.CanCollide = false
		core.CanTouch = false
		core.CanQuery = false
		core.CastShadow = false
		core.Locked = true
		core.Transparency = 1
		core.Size = Vector3.new(0.4, 0.4, 0.4)
		core.CFrame = anchor
		core.Parent = egg
		egg.PrimaryPart = core
		egg.Parent = booth
	end
	egg:SetAttribute("Anchor", anchor)
	egg:SetAttribute("BobHeight", 0.22)
	egg:SetAttribute("BobSpeed", 1.15)
	egg:SetAttribute("BobPhase", (seedOf(booth) * 0.7) % (math.pi * 2))
	egg:SetAttribute("SpinSpeed", 0.3)
	CollectionService:AddTag(egg, "FX_Egg")

	local pad = booth:FindFirstChild("EggPad")
	if not pad then
		pad = Instance.new("Model")
		pad.Name = "EggPad"
		pad.Parent = booth
	end
	pad:SetAttribute("Anchor", anchor)

	egg:SetAttribute("Tier", nil)
	EggModel.Apply(booth, { Tier = 0, Accent = RGB(190, 186, 178), Scale = 0.8, Instant = true })
	return egg
end

function EggModel.Core(booth)
	local egg = booth:FindFirstChild("Egg")
	return egg and egg.PrimaryPart
end

function EggModel.Heart(booth)
	local egg = booth:FindFirstChild("Egg")
	return egg and egg:FindFirstChild("Heart")
end

-- Olcek: Egg ve EggPad parcalarini yeniden dizer
local function setScale(booth, scale)
	for _, name in ipairs({ "Egg", "EggPad" }) do
		local model = booth:FindFirstChild(name)
		if model then
			local anchor = model:GetAttribute("Anchor")
			model:SetAttribute("Scale", scale)
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") and p ~= model.PrimaryPart then
					layoutPart(p, anchor, scale)
				end
			end
			if model.PrimaryPart then
				model.PrimaryPart.Size = Vector3.new(0.4, 0.4, 0.4) * scale
			end
		end
	end
end

local growToken = {}

-- look = { Tier, Accent, Scale, Instant }
function EggModel.Apply(booth, look)
	local egg = booth:FindFirstChild("Egg")
	local pad = booth:FindFirstChild("EggPad")
	if not (egg and pad) then
		return
	end
	local tier = math.clamp(look.Tier, 0, #TIERS)
	local accent = look.Accent
	local key = tier .. ":" .. accent:ToHex()

	if egg:GetAttribute("LookKey") ~= key then
		local anchor = egg:GetAttribute("Anchor")
		local ctx = { anchor = anchor, scale = look.Scale }
		clearContent(egg, egg.PrimaryPart)
		clearContent(pad, nil)
		buildEgg(egg, tier, accent, seedOf(booth), ctx)
		buildPad(pad, tier, accent, ctx)
		egg:SetAttribute("LookKey", key)
		egg:SetAttribute("Tier", tier)
		egg:SetAttribute("Scale", look.Scale)
		pad:SetAttribute("Scale", look.Scale)
		growToken[booth] = nil
		return
	end

	local current = egg:GetAttribute("Scale") or 1
	if math.abs(current - look.Scale) < 0.001 then
		return
	end
	if look.Instant then
		setScale(booth, look.Scale)
		return
	end

	-- yumusak buyume: kisa adimlarla (seviye atlayinca nadir olur)
	local token = {}
	growToken[booth] = token
	task.spawn(function()
		local steps = 6
		for i = 1, steps do
			task.wait(0.07)
			if growToken[booth] ~= token or not booth.Parent then
				return
			end
			local t = i / steps
			local eased = 1 + 2.2 * (t - 1) ^ 3 + 1.2 * (t - 1) ^ 2 -- hafif tasip yerine oturur
			setScale(booth, current + (look.Scale - current) * eased)
		end
		if growToken[booth] == token and booth.Parent then
			setScale(booth, look.Scale)
		end
	end)
end

-- Zeminde genisleyip sonen isik halkasi
function EggModel.Pulse(booth, color, diameter)
	local anchor = booth:GetAttribute("EggAnchor")
	if not anchor then
		return
	end
	local scale = (booth:FindFirstChild("Egg") and booth.Egg:GetAttribute("Scale")) or 1
	local ring = Instance.new("Part")
	ring.Name = "PulseRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.15
	ring.Size = Vector3.new(0.1, 2, 2)
	ring.CFrame = anchor * CFrame.new(0, 0.1, 0) * UP
	ring.Parent = booth
	TweenService:Create(ring, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, diameter * math.max(scale, 1), diameter * math.max(scale, 1)),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1)
end

-- Kabugu kisa sure beyaz parlatir (evrim ani)
function EggModel.Flash(booth, duration)
	local egg = booth:FindFirstChild("Egg")
	if not egg then
		return
	end
	local saved = {}
	for _, p in ipairs(egg:GetChildren()) do
		if p:IsA("BasePart") and string.sub(p.Name, 1, 5) == "Shell" then
			saved[p] = { color = p.Color, material = p.Material }
			p.Color = Color3.new(1, 1, 1)
			p.Material = Enum.Material.Neon
		end
	end
	task.delay(duration, function()
		for p, s in pairs(saved) do
			if p.Parent then
				p.Color, p.Material = s.color, s.material
			end
		end
	end)
end

return EggModel
