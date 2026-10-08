-- dev/preview_extra.lua : onizleme sahnesine stilleri ekler (preview.sh otomatik ekler)
do
	local Config = require(__SSS.Modules.Config)
	local Styler = require(__SSS.Modules.BoothStyler)
	local ids = { "rug", "flags", "lantern", "garden", "gold", "legend" }
	local colors = { 1, 6, 2, 4, 3, 8 }
	for i, id in ipairs(ids) do
		Styler.Apply(workspace.Booths["Booth_" .. i], id, colors[i])
	end
end
