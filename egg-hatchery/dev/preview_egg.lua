-- dev/preview_egg.lua : yumurta onizlemesi icin sahne (dev/preview.sh ile calisir)
do
	local Config = require(__SSS.Modules.Config)
	local EggModel = require(__SSS.Modules.EggModel)
	local Hatchery = require(__SSS.Modules.HatcheryService)
	local looks = {
		{ 1, Config.RARITIES[1].Color, Config.EggScale(3) },
		{ 2, Config.RARITIES[2].Color, Config.EggScale(7) },
		{ 3, Config.RARITIES[3].Color, Config.EggScale(15) },
		{ 4, Config.RARITIES[4].Color, Config.EggScale(30) },
		{ 3, Config.STYLE_COLORS[5].Color, Config.EggScale(12) },
		{ 0, Color3.fromRGB(190, 186, 178), 0.8 },
	}
	for i, l in ipairs(looks) do
		local booth = workspace.Booths["Booth_" .. i]
		Hatchery.BuildBooth(booth)
		EggModel.Apply(booth, { Tier = l[1], Accent = l[2], Scale = l[3], Instant = true })
		local a = booth:GetAttribute("EggAnchor")
		print(string.format("ANCHOR|%d|%f|%f|%f|%f|%f|%f", i, a.X, a.Y, a.Z, a.LookVector.X, a.LookVector.Y, a.LookVector.Z))
	end
end
