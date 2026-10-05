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
-- onizleme icin arazi dolgularini yaklasik parcalar olarak yaz (hava oyuklari cizilemez; su/kum ince disk olarak ustte gosterilir)
do
	local terr = workspace.Terrain
	local colors = { Grass = { 0.38, 0.64, 0.27 }, Sand = { 0.87, 0.78, 0.59 }, Water = { 0.25, 0.59, 0.75 } }
	local function emit(shape, size, cf, mat)
		local c = colors[mat]
		if not c then
			return
		end
		table.insert(lines, table.concat({
			"P", "Terrain" .. mat, shape, 0, size.X, size.Y, size.Z,
			cf.m[1], cf.m[2], cf.m[3], cf.m[4], cf.m[5], cf.m[6], cf.m[7], cf.m[8], cf.m[9], cf.m[10], cf.m[11], cf.m[12],
			c[1], c[2], c[3], "Grass", 0, 1, "Terrain",
		}, "|"))
	end
	for _, f in ipairs(terr:GetFills_MOCK()) do
		local a, mat = f.args, f.args[#f.args].Name
		if f.kind == "Block" then
			if mat == "Grass" then
				emit("Block", Vector3.new(a[2].X, 1, a[2].Z), CFrame.new(a[1].Position.X, -0.5, a[1].Position.Z), mat)
			elseif mat == "Sand" or mat == "Water" then
				local target = (mat == "Sand") and 0.02 or 0.05
				emit("Block", Vector3.new(a[2].X, 0.05, a[2].Z), a[1] * CFrame.new(0, target - a[1].Position.Y, 0), mat)
			end
		elseif f.kind == "Ball" then
			emit("Ball", Vector3.new(a[2] * 2, a[2] * 2, a[2] * 2), CFrame.new(a[1]), mat)
		elseif f.kind == "Cylinder" and (mat == "Sand" or mat == "Water") then
			emit("Cylinder", Vector3.new(0.05, a[3] * 2, a[3] * 2), CFrame.new(a[1].Position.X, mat == "Sand" and 0.02 or 0.05, a[1].Position.Z) * CFrame.Angles(0, 0, math.rad(90)), mat)
		end
	end
end
print("STATS|parts=" .. count .. "|instances=" .. #__allInstances())
for g, n in pairs(perGroup) do
	print("GROUP|" .. g .. "|" .. n)
end
for _, l in ipairs(lines) do
	print(l)
end
