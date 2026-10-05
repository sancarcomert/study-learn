do
	local function check(c, m) if not c then error("TEST BASARISIZ: " .. m, 2) end print("  ok  " .. m) end
	print("== Halka standlar ==")
	local bs = workspace.Booths:GetChildren()
	local N = #bs
	check(N == 24, "R=84 icin 24 stand (" .. N .. ")")
	local cx, cz, fy = 40, -25, 3
	local minGap = math.huge
	for _, b in ipairs(bs) do
		local p, look = b.Base.Position, b.Base.CFrame.LookVector
		local toC = Vector3.new(cx - p.X, 0, cz - p.Z).Unit
		assert(look:Dot(toC) > 0.999, b.Name .. " merkeze bakmiyor")
		local pp = b.Platform.Position
		local d = math.sqrt((pp.X - cx) ^ 2 + (pp.Z - cz) ^ 2)
		assert(math.abs(d - 84) < 0.01, b.Name .. " yaricap yanlis " .. d)
		assert(math.abs(b.Platform.Position.Y - (fy + 0.25)) < 0.01, b.Name .. " zeminde degil")
	end
	-- komsu standlarin tum parcalari birbirinden en az 2 stud uzak (OBB yaklasigi: kose-mesafe)
	local function corners(b)
		local out = {}
		for _, p in ipairs(b:GetChildren()) do
			if p:IsA("BasePart") and p.CanCollide then
				for _, sx in ipairs({ -0.5, 0.5 }) do for _, sz in ipairs({ -0.5, 0.5 }) do
					out[#out + 1] = p.CFrame * Vector3.new(sx * p.Size.X, 0, sz * p.Size.Z)
				end end
			end
		end
		return out
	end
	for i = 1, N do
		local j = i % N + 1
		local a, b = corners(bs[i]), corners(bs[j])
		for _, u in ipairs(a) do for _, v in ipairs(b) do minGap = math.min(minGap, (u - v).Magnitude) end end
	end
	check(minGap >= 2.5, string.format("komsu standlarin parcalari en az %.1f stud uzakta", minGap))
	check(#game:GetService("CollectionService"):GetTagged("FX_Bob") == 24, "24 yumurta etiketi")
end
