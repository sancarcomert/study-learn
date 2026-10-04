-- ServerScriptService/Modules/BoothRegistry  (ModuleScript)
-- Single source of truth for who owns which booth.

local Registry = {}

local boothByOwner: { [Player]: Model } = {}
local ownerByBooth: { [Model]: Player } = {}

function Registry.Claim(booth: Model, player: Player)
	boothByOwner[player] = booth
	ownerByBooth[booth] = player
end

function Registry.Release(booth: Model)
	local owner = ownerByBooth[booth]
	if owner then
		boothByOwner[owner] = nil
	end
	ownerByBooth[booth] = nil
end

function Registry.GetBooth(player: Player): Model?
	return boothByOwner[player]
end

function Registry.GetOwner(booth: Model): Player?
	return ownerByBooth[booth]
end

-- Snapshot copy so callers can release while iterating.
function Registry.AllClaimed(): { [Model]: Player }
	return table.clone(ownerByBooth)
end

return Registry
