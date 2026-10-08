-- StarterPlayer/StarterPlayerScripts/MapFX  (LocalScript)
--
-- Sunucunun isaretledigi (CollectionService tag) nesneleri istemcide canlandirir.
-- Hepsi SADECE bu oyuncunun ekraninda olur: sunucuya yuk bindirmez.
--   FX_Egg   : EggModel yumurtasi yukari-asagi yuzer, yavasca doner, taslar yoringede doner
--   BoothSign: stand tabelasi; sahipsiz = "STAND 07", sahipli = oyuncunun adi (booth OwnerUserId attribute'u)
--
-- Konumlar her karede sunucunun verdigi sabit "Anchor" ve parcalarin "BO/BS" verisinden MUTLAK hesaplanir:
-- sunucu bir parcayi guncellese bile bir sonraki karede duzelir, sayisal hata birikmez.

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
-- EggModel yumurtalari
---------------------------------------------------------------------
local EGG_RANGE = 140 -- bundan uzaktaki yumurtalar guncellenmez (sunucudaki sabit konumunda kalir)
local eggs = {}

local function collectParts(egg, d)
	d.parts = {}
	for _, p in ipairs(egg:GetDescendants()) do
		if p:IsA("BasePart") and p ~= d.core then
			local bo, bs = p:GetAttribute("BO"), p:GetAttribute("BS")
			if bo and bs then
				table.insert(d.parts, {
					part = p,
					pos = bo.Position,
					rot = bo - bo.Position,
					size = bs,
					orbit = p:GetAttribute("OR") ~= nil,
					radius = p:GetAttribute("OR"),
					speed = p:GetAttribute("OS"),
					phase = p:GetAttribute("OP"),
					tilt = p:GetAttribute("OT"),
					height = p:GetAttribute("OY"),
					gemRot = p:GetAttribute("GR"),
				})
			end
		end
	end
	d.dirty = false
end

watch("FX_Egg", function(egg)
	if eggs[egg] then
		return
	end
	local d = { core = egg.PrimaryPart or egg:FindFirstChild("Core"), dirty = true, scale = nil }
	eggs[egg] = d
	egg.DescendantAdded:Connect(function()
		d.dirty = true
	end)
	egg.DescendantRemoving:Connect(function()
		d.dirty = true
	end)
end, function(egg)
	eggs[egg] = nil
end)

local function placeEgg(egg, d, t)
	local anchor = egg:GetAttribute("Anchor")
	d.core = d.core or egg.PrimaryPart
	local core = d.core
	if not (anchor and core and core.Parent) then
		return
	end
	if d.dirty then
		collectParts(egg, d)
	end
	local scale = egg:GetAttribute("Scale") or 1
	local phase = egg:GetAttribute("BobPhase") or 0
	local bob = CFrame.new(0, math.sin(t * (egg:GetAttribute("BobSpeed") or 1) + phase) * (egg:GetAttribute("BobHeight") or 0.2) * scale, 0)
	local floating = anchor * bob
	local pivot = floating * CFrame.Angles(0, t * (egg:GetAttribute("SpinSpeed") or 0) + phase, 0)
	local resize = d.scale ~= scale
	d.scale = scale
	core.CFrame = pivot
	for _, e in ipairs(d.parts) do
		local p = e.part
		if p.Parent then
			if resize then
				p.Size = e.size * scale
			end
			if e.orbit then
				local angle = t * e.speed + e.phase
				p.CFrame = floating * CFrame.new(0, e.height * scale, 0) * CFrame.Angles(0, 0, e.tilt)
					* CFrame.Angles(0, angle, 0) * CFrame.new(e.radius * scale, 0, 0) * e.gemRot
			else
				p.CFrame = pivot * CFrame.new(e.pos * scale) * e.rot
			end
		end
	end
end

RunService.Heartbeat:Connect(function()
	local t = Workspace:GetServerTimeNow()
	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	for egg, d in pairs(eggs) do
		if egg.Parent then
			local anchor = egg:GetAttribute("Anchor")
			if anchor and (camPos == nil or (anchor.Position - camPos).Magnitude < EGG_RANGE) then
				placeEgg(egg, d, t)
			end
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
