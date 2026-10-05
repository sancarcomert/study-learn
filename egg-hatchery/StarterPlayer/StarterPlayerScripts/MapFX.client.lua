-- StarterPlayer/StarterPlayerScripts/MapFX  (LocalScript)
--
-- MapBuilder'in isaretledigi (CollectionService tag) nesneleri istemcide gunceller.
-- Hepsi SADECE bu oyuncunun ekraninda olur: sunucuya yuk bindirmez.
--   FX_Bob   : stand yumurtasi yukari-asagi hafifce yuzer (BobHeight, BobSpeed, BobPhase)
--   BoothSign: stand tabelasi; sahipsiz = "STAND 07", sahipli = oyuncunun adi (booth OwnerUserId attribute'u)
--
-- Yuzme her karede baslangic konumundan MUTLAK hesaplanir; sayisal hata birikmez.

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
-- Yumurtalar
---------------------------------------------------------------------
local bobbers = {}

watch("FX_Bob", function(inst)
	if bobbers[inst] == nil then
		bobbers[inst] = {
			base = inst.CFrame,
			height = inst:GetAttribute("BobHeight") or 0.3,
			speed = inst:GetAttribute("BobSpeed") or 1,
			phase = inst:GetAttribute("BobPhase") or 0,
		}
	end
end, function(inst)
	bobbers[inst] = nil
end)

RunService.Heartbeat:Connect(function()
	local t = Workspace:GetServerTimeNow()
	for inst, d in pairs(bobbers) do
		if inst.Parent then
			inst.CFrame = d.base + Vector3.new(0, math.sin(t * d.speed + d.phase) * d.height, 0)
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
