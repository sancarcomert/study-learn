local Registry = {}

local boothByOwner = {}
local ownerByBooth = {}

function Registry.Claim(booth, player)
	boothByOwner[player] = booth
	ownerByBooth[booth] = player
end

function Registry.Release(booth)
	local owner = ownerByBooth[booth]
	if owner then
		boothByOwner[owner] = nil
	end
	ownerByBooth[booth] = nil
end

function Registry.GetBooth(player)
	return boothByOwner[player]
end

function Registry.GetOwner(booth)
	return ownerByBooth[booth]
end

function Registry.AllClaimed()
	return table.clone(ownerByBooth)
end

return Registry
