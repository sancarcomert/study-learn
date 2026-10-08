-- dev/test_world.lua : testler icin kucuk bir dunya: cesme + 6 stand ("propy's booth" benzeri, farkli yonlere donuk)
do
	local fountain = Instance.new("Model")
	fountain.Name = "Fountain"
	local fp = Instance.new("Part")
	fp.Name = "Basin"
	fp.Anchored = true
	fp.Size = Vector3.new(12, 3, 12)
	fp.CFrame = CFrame.new(0, 1.5, 0)
	fp.Parent = fountain
	fountain.PrimaryPart = fp
	fountain.Parent = workspace

	local folder = Instance.new("Folder")
	folder.Name = "Booths"
	folder.Parent = workspace
	for i = 1, 6 do
		local ang = (i - 1) * math.pi / 3 + 0.3
		local pos = Vector3.new(38 * math.cos(ang), 0, 38 * math.sin(ang))
		local base = CFrame.lookAt(pos, Vector3.new(0, 0, 0)) -- on yuz (-Z) cesmeye bakar
		local booth = Instance.new("Model")
		booth.Name = "Booth_" .. i
		local function mk(name, size, x, y, z)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.Size = size
			p.CFrame = base * CFrame.new(x, y + size.Y / 2, z)
			p.Parent = booth
			return p
		end
		local platform = mk("Platform", Vector3.new(10, 0.6, 8), 0, 0, 0)
		mk("BackWall", Vector3.new(10, 7, 0.5), 0, 0.6, 3.75)
		mk("Counter", Vector3.new(8, 3, 1.4), 0, 0.6, -2.4)
		mk("Roof", Vector3.new(11, 0.6, 9), 0, 7.6, 0)
		mk("SignBoard", Vector3.new(6, 1.6, 0.4), 0, 8.2, -4.2)
		booth.PrimaryPart = platform
		booth.Parent = folder
	end
end
