-- StarterPlayer/StarterPlayerScripts/MapFX  (LocalScript)
--
-- MapBuilder'in isaretledigi (CollectionService tag) nesneleri istemcide anime eder.
-- Hepsi SADECE bu oyuncunun ekraninda olur: sunucuya yuk bindirmez, tum oyuncular ayni fazi gorur.
--   FX_Spin  : kendi ekseni etrafinda doner   (SpinSpeed)
--   FX_Bob   : yukari-asagi yuzer, istege bagli yavasca doner (BobHeight, BobSpeed, BobPhase, SpinSpeed)
--   FX_Orbit : bir merkez etrafinda yorunge  (OrbitCenter, OrbitRadius, OrbitSpeed, OrbitPhase, OrbitHeight, OrbitBob)
--   BoothBeam: standin isik huzmesi; stand sahipliyse parlak, bossa soluk
--
-- Onemli: modeller her karede PivotTo ile "arttirilarak" degil, baslangic ofsetlerinden MUTLAK olarak
-- yeniden hesaplanir. Boylece sayisal hata birikmez (uzun oturumlarda bile kayma olmaz).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FAR_DISTANCE = 200 -- adanin merkezinden bu kadar uzaktaki dekor 3 karede bir guncellenir

local spinners = {}
local bobbers = {}
local orbiters = {}

-- Model ya da parcanin baslangic pivotunu ve her parcanin pivota gore SABIT ofsetini saklar
local function captureRig(inst)
	if inst:IsA("Model") then
		local base = inst:GetPivot()
		local inverse = base:Inverse()
		local parts, offsets = {}, {}
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
				table.insert(offsets, inverse * d.CFrame)
			end
		end
		return { base = base, parts = parts, offsets = offsets }
	end
	return { base = inst.CFrame, parts = { inst }, offsets = { CFrame.new() } }
end

local function applyRig(rig, pivot)
	local parts, offsets = rig.parts, rig.offsets
	for i = 1, #parts do
		parts[i].CFrame = pivot * offsets[i]
	end
end

-- tag'li nesneleri (var olanlar + sonradan akan/gelenler) takip eder
local function watch(tagName, store, make)
	local function add(inst)
		if store[inst] == nil then
			local data = make(inst)
			if data then
				store[inst] = data
			end
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(inst)
		store[inst] = nil
	end)
end

local function newEntry(inst, extra)
	local rig = captureRig(inst)
	extra.rig = rig
	extra.far = rig.base.Position.Magnitude > FAR_DISTANCE
	extra.slot = math.random(0, 2)
	return extra
end

watch("FX_Spin", spinners, function(inst)
	return newEntry(inst, { speed = inst:GetAttribute("SpinSpeed") or 0.3 })
end)

watch("FX_Bob", bobbers, function(inst)
	return newEntry(inst, {
		height = inst:GetAttribute("BobHeight") or 1,
		speed = inst:GetAttribute("BobSpeed") or 0.5,
		phase = inst:GetAttribute("BobPhase") or 0,
		spin = inst:GetAttribute("SpinSpeed") or 0,
	})
end)

watch("FX_Orbit", orbiters, function(inst)
	local center = inst:GetAttribute("OrbitCenter")
	if not center then
		return nil
	end
	return {
		center = center,
		radius = inst:GetAttribute("OrbitRadius") or 5,
		speed = inst:GetAttribute("OrbitSpeed") or 1,
		phase = inst:GetAttribute("OrbitPhase") or 0,
		height = inst:GetAttribute("OrbitHeight") or 0,
		bob = inst:GetAttribute("OrbitBob") or 0,
	}
end)

local frame = 0

RunService.Heartbeat:Connect(function()
	frame += 1
	local t = Workspace:GetServerTimeNow()

	for inst, d in pairs(spinners) do
		if inst.Parent and (not d.far or frame % 3 == d.slot) then
			applyRig(d.rig, d.rig.base * CFrame.Angles(0, t * d.speed, 0))
		end
	end

	for inst, d in pairs(bobbers) do
		if inst.Parent and (not d.far or frame % 3 == d.slot) then
			local pivot = d.rig.base
			if d.spin ~= 0 then
				pivot = pivot * CFrame.Angles(0, t * d.spin, 0)
			end
			applyRig(d.rig, pivot + Vector3.new(0, math.sin(t * d.speed + d.phase) * d.height, 0))
		end
	end

	for inst, d in pairs(orbiters) do
		if inst.Parent then
			local a = t * d.speed + d.phase
			local offset = Vector3.new(math.cos(a) * d.radius, d.height + math.sin(a * 1.7) * d.bob, math.sin(a) * d.radius)
			inst.CFrame = CFrame.new(d.center + offset) * CFrame.Angles(a, a * 0.7, 0)
		end
	end
end)

---------------------------------------------------------------------
-- Stand huzmeleri: sahipli = parlak sutun, bos = soluk
---------------------------------------------------------------------
local function applyBeam(beam, claimed)
	if claimed then
		beam.Width0 = 2.6
		beam.Width1 = 0.6
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		beam.Width0 = 0.9
		beam.Width1 = 0.3
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

local function hookBeam(beam)
	local booth = beam:FindFirstAncestorOfClass("Model")
	if not booth then
		return
	end
	local function refresh()
		applyBeam(beam, booth:GetAttribute("OwnerUserId") ~= nil)
	end
	refresh()
	booth:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
end

for _, beam in ipairs(CollectionService:GetTagged("BoothBeam")) do
	hookBeam(beam)
end
CollectionService:GetInstanceAddedSignal("BoothBeam"):Connect(hookBeam)
