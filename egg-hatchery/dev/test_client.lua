-- dev/test_client.lua : MapFX calistiktan sonra animasyonlar dogru mu? (MapFX kaynagi bunun uzerine eklenir)
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== MapFX ==")
	local gyro = workspace.Map.Center.GyroA
	local before = gyro:GetPivot()
	__setTime(1.5)
	__fireHeartbeat()
	local after = gyro:GetPivot()
	check(before.m[4] ~= after.m[4] or before.m[5] ~= after.m[5], "GyroA doner")
	check(math.abs(after.m[2] - before.m[2]) < 1e-6 and math.abs(after.m[1]) < 1e-6, "GyroA yerinde donuyor (konum sabit)")
	-- ic parcalar da donmeli
	local seg = gyro:FindFirstChild("Bead")
	check(seg ~= nil, "GyroA boncuklari var")

	local egg = workspace.Booths.Booth_1.Egg
	local y0 = egg.CFrame.Y
	__setTime(0.7)
	__fireHeartbeat()
	local y1 = egg.CFrame.Y
	local phase = egg:GetAttribute("BobPhase")
	local expected = 6.8 + math.sin(0.7 * 1.1 + phase) * 0.45
	check(math.abs(y1 - expected) < 1e-4, string.format("stand yumurtasi yuzuyor (y=%.4f beklenen=%.4f)", y1, expected))

	local orb = workspace.Booths.Booth_1:FindFirstChild("Orbiter")
	local c = orb:GetAttribute("OrbitCenter")
	local p = orb.CFrame.Position
	local rad = math.sqrt((p.X - c.X) ^ 2 + (p.Z - c.Z) ^ 2)
	check(math.abs(rad - orb:GetAttribute("OrbitRadius")) < 1e-4, "yorunge yaricapi korunuyor")

	local beam = workspace.Booths.Booth_1.BeamBase.SkyBeam
	check(beam.Width0 == 0.9, "bos standda huzme soluk")
	workspace.Booths.Booth_1:SetAttribute("OwnerUserId", 123)
	check(beam.Width0 == 2.6, "sahip gelince huzme parlak")
	workspace.Booths.Booth_1:SetAttribute("OwnerUserId", nil)
	check(beam.Width0 == 0.9, "sahip cikinca huzme tekrar soluk")

	-- Uzun sure: hata birikmemeli (ortonormallik + sabit konum)
	local islet = workspace.Map.FarScenery.Islet_1
	local isletBase = islet:GetPivot().Position
	local t0 = os.clock()
	for i = 1, 3000 do
		__setTime(2 + i / 30)
		__fireHeartbeat()
	end
	print(string.format("  ok  3000 kare calisti (%.1fs)", os.clock() - t0))
	for _, name in ipairs({ "GyroA", "GyroB", "GyroC" }) do
		local g = workspace.Map.Center[name]:GetPivot()
		local m = g.m
		local r1 = m[4] ^ 2 + m[5] ^ 2 + m[6] ^ 2
		local r2 = m[7] ^ 2 + m[8] ^ 2 + m[9] ^ 2
		local r3 = m[10] ^ 2 + m[11] ^ 2 + m[12] ^ 2
		check(math.abs(r1 - 1) < 1e-9 and math.abs(r2 - 1) < 1e-9 and math.abs(r3 - 1) < 1e-9, name .. " ortonormal kaldi")
		check(math.abs(m[1]) < 1e-6 and math.abs(m[2] - 34) < 1e-6 and math.abs(m[3]) < 1e-6, name .. " konumu sabit")
	end
	local ip = islet:GetPivot().Position
	check(math.abs(ip.X - isletBase.X) < 1e-6 and math.abs(ip.Y - isletBase.Y) <= 2 * islet:GetAttribute("BobHeight") + 1e-6 and math.abs(ip.Z - isletBase.Z) < 1e-6, "uzak ada yuzuyor ama yatayda kaymiyor")
end
