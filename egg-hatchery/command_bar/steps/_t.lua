local function tree(parent, x, z, s, kind, rng)
	local K = {
		oak = { RGB(86, 164, 66), RGB(106, 180, 74), RGB(66, 142, 58) },
		birch = { RGB(120, 190, 80), RGB(140, 200, 96) },
		cherry = { RGB(246, 160, 190), RGB(238, 132, 170) },
		maple = { RGB(232, 140, 52), RGB(212, 100, 44) },
	}
	local cols = K[kind]
	local h = 9 * s
	local cf = CFrame.new(x, 0, z)
	Cyl(parent, "Trunk", (kind == "birch" and 1.1 or 1.8) * s, h, cf * CFrame.new(0, h / 2, 0), (kind == "birch") and RGB(232, 228, 216) or RGB(112, 78, 50), Mat.Wood)
	local k = rng:NextInteger(1, #cols)
	local soft = { solid = false }
	Ball(parent, "Leaves", 13 * s, cf * CFrame.new(0, h + 3.5 * s, 0), cols[k], Mat.Grass, soft)
	Ball(parent, "Leaves", 9.5 * s, cf * CFrame.new(3.6 * s, h + 1.5 * s, 1.2 * s), cols[k % #cols + 1], Mat.Grass, soft)
	Ball(parent, "Leaves", 8.5 * s, cf * CFrame.new(-3.2 * s, h + 2 * s, -1.8 * s), cols[(k + 1) % #cols + 1], Mat.Grass, soft)
end
local function lamp(parent, x, z)
	local cf = CFrame.new(x, 0, z)
	local metal = RGB(56, 60, 66)
	Cyl(parent, "LampBase", 1.4, 0.5, cf * CFrame.new(0, 0.25, 0), metal, Mat.Metal)
	Cyl(parent, "LampPole", 0.5, 7, cf * CFrame.new(0, 3.5, 0), metal, Mat.Metal)
	P(parent, "LampHead", Vector3.new(1.3, 1.6, 1.3), cf * CFrame.new(0, 7.8, 0), RGB(255, 214, 140), Mat.Neon, NOCOL)
	P(parent, "LampCap", Vector3.new(1.9, 0.3, 1.9), cf * CFrame.new(0, 8.75, 0), metal, Mat.Metal, { solid = false })
end
