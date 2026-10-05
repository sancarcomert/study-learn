-- dev/dump_parts.lua : kurulum bittikten sonra butun parcalari satir satir yazdirir (onizleme icin)
local lines = {}
local count, perGroup = 0, {}
for _, inst in ipairs(workspace:GetDescendants()) do
	if inst:IsA("BasePart") then
		count = count + 1
		local group = "Workspace"
		local p = inst.Parent
		while p and p ~= workspace do
			group = p.Name
			p = p.Parent
		end
		perGroup[group] = (perGroup[group] or 0) + 1
		local cf = inst.CFrame
		local sh = nil
		if inst:IsA("Part") then
			sh = inst.Shape
		end
		local shape = sh and sh.Name or "Block"
		local mesh = inst:FindFirstChildOfClass("SpecialMesh") and 1 or 0
		local c = inst.Color or { R = 0.64, G = 0.64, B = 0.65 }
		table.insert(lines, table.concat({
			"P", inst.Name, shape, mesh, inst.Size.X, inst.Size.Y, inst.Size.Z,
			cf.m[1], cf.m[2], cf.m[3], cf.m[4], cf.m[5], cf.m[6], cf.m[7], cf.m[8], cf.m[9], cf.m[10], cf.m[11], cf.m[12],
			c.R, c.G, c.B, (inst.Material and inst.Material.Name or "Plastic"), inst.Transparency, inst.CanCollide and 1 or 0, group,
		}, "|"))
	end
end
print("STATS|parts=" .. count .. "|instances=" .. #__allInstances())
for g, n in pairs(perGroup) do
	print("GROUP|" .. g .. "|" .. n)
end
for _, l in ipairs(lines) do
	print(l)
end
