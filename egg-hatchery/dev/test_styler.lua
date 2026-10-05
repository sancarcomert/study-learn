-- dev/test_styler.lua : BoothStyler - dondurulmus bir stand uzerinde her stilin parcalari dogru yerde mi?
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== BoothStyler ==")
	local Config = require(__SSS.Modules.Config)
	local Styler = require(__SSS.Modules.BoothStyler)

	-- sentetik, dondurulmus stand: merkezden 60 stud uzakta, rastgele yone donuk
	local fountain = Instance.new("Model")
	fountain.Name = "Fountain"
	local fp = Instance.new("Part")
	fp.Anchored = true
	fp.Size = Vector3.new(10, 6, 10)
	fp.CFrame = CFrame.new(0, 3, 0)
	fp.Parent = fountain
	fountain.Parent = workspace

	for _, yaw in ipairs({ 0, 0.7, 2.2, -1.3 }) do
		local booth = Instance.new("Model")
		booth.Name = "TestBooth"
		local pos = CFrame.new(60 * math.cos(yaw + 1), 0, 60 * math.sin(yaw + 1)) * CFrame.Angles(0, yaw, 0)
		local function mk(name, size, off)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.Size = size
			p.CFrame = pos * CFrame.new(off.X, size.Y / 2 + off.Y, off.Z)
			p.Parent = booth
			return p
		end
		mk("Base", Vector3.new(10, 1, 6), Vector3.new(0, 0, 0))
		mk("Wall", Vector3.new(10, 6, 0.5), Vector3.new(0, 1, 3))
		local egg = mk("Egg", Vector3.new(2, 3, 2), Vector3.new(0, 8, 0))
		booth.PrimaryPart = booth.Base
		booth.Parent = workspace

		local F = Styler.Measure(booth)
		check(F ~= nil and F.width > 8 and F.height > 6, string.format("olcum: genislik %.1f yukseklik %.1f (yaw %.1f)", F.width, F.height, yaw))
		-- on yuz cesmeye (merkeze) bakmali
		local toFountain = (Vector3.new(0, 0, 0) - Vector3.new(F.frame.X, 0, F.frame.Z)).Unit
		check(F.frame.LookVector:Dot(toFountain) > 0.999, "stand on yuzu cesmeye bakiyor")

		for _, style in ipairs(Config.STYLES) do
			Styler.Apply(booth, style.Id, 2)
			local decor = booth:FindFirstChild("StyleDecor")
			if style.Id == "classic" then
				assert(decor == nil, "classic susu olmamali")
			else
				assert(decor ~= nil, style.Id .. ": StyleDecor yok")
				local n = 0
				for _, p in ipairs(decor:GetDescendants()) do
					if p:IsA("BasePart") then
						n = n + 1
						assert(p.CanCollide == false, style.Id .. "." .. p.Name .. " carpismali (oyuncuyu engeller)")
						-- hicbir sus standin arkasinda degil: on yone gore stand merkezinden ileride/yaninda
					end
				end
				assert(n >= 3 and n <= 70, style.Id .. ": parca sayisi makul degil (" .. n .. ")")
				-- on tarafta mi? en az bir sus parcasi standin onunde (cesmeye dogru)
				local front = 0
				for _, p in ipairs(decor:GetDescendants()) do
					if p:IsA("BasePart") then
						local rel = F.frame:PointToObjectSpace(p.Position)
						if rel.Z < F.front + 1 then
							front = front + 1
						end
					end
				end
				assert(front >= 2, style.Id .. ": sus parcalari standin onunde degil")
			end
			-- tekrar uygulama: eskisi silinir, cogalmaz
			Styler.Apply(booth, style.Id, 2)
			local count = 0
			for _, c in ipairs(booth:GetChildren()) do
				if c.Name == "StyleDecor" then
					count = count + 1
				end
			end
			assert(count <= 1, style.Id .. ": StyleDecor cogaldi")
		end
		-- ayni olcum sus eklendikten sonra degismemeli (olcum susu saymaz)
		local F2 = Styler.Measure(booth)
		assert(math.abs(F2.width - F.width) < 1e-6 and math.abs(F2.height - F.height) < 1e-6, "sus eklenince olcum degisti")
		-- fener ve efsane stilleri isik/parcacik icerir
		Styler.Apply(booth, "lantern", 1)
		local lights = 0
		for _, d in ipairs(booth.StyleDecor:GetDescendants()) do
			if d.ClassName == "PointLight" then
				lights = lights + 1
			end
		end
		assert(lights == 2, "fenerli stilde 2 isik olmali")
		Styler.Apply(booth, "legend", 1)
		assert(booth.StyleDecor:FindFirstChild("LightBeam") and booth.StyleDecor.Sparkles.ParticleEmitter, "efsane stilde isik sutunu ve kivilcim olmali")
		Styler.Clear(booth)
		assert(booth:FindFirstChild("StyleDecor") == nil, "Clear sus parcalarini siler")
		booth:Destroy()
	end
	check(true, "7 stil x 4 farkli yon: carpismasiz, makul parca sayisi, on tarafta, tekrar uygulamada cogalmaz, olcum sabit")
	fountain:Destroy()
end
