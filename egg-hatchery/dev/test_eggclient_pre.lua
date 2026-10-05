local __Players = game:GetService("Players")
local __lp = Instance.new("Player")
__lp.Name = "LocalGuy"
__lp.UserId = 9
__lp.Parent = __Players
local __pg = Instance.new("PlayerGui")
__pg.Name = "PlayerGui"
__pg.Parent = __lp
local __ls = Instance.new("Folder")
__ls.Name = "leaderstats"
__ls.Parent = __lp
for _, n in ipairs({ "Raised", "Donated", "Level" }) do
	local v = Instance.new("IntValue")
	v.Name = n
	v.Parent = __ls
end
__ls.Level.Value = 1
local __ed = Instance.new("Folder")
__ed.Name = "EggData"
__ed.Parent = __lp
local __xp = Instance.new("IntValue")
__xp.Name = "EggXP"
__xp.Parent = __ed
__Players.LocalPlayer = __lp
