local Registry = {}

local boothByOwner = {}
local ownerByBooth = {}
local viewing = {} -- [player] = su an paneli acik olan stand

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

-- Panel: oyuncu hangi standa bakiyor (bagis ve besleme dogrulamasi icin)
function Registry.SetViewing(player, booth)
	viewing[player] = booth
end

function Registry.GetViewing(player)
	return viewing[player]
end

function Registry.ClearViewing(player)
	viewing[player] = nil
end

return Registry
