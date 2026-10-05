-- dev/test_layout.lua : Park haritasinin yerlesimi tutarli mi? (ust uste binen stand, kapanan yol, tasan nesne...)
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== Yerlesim ==")

	local function corners(p)
		local cf, s = p.CFrame, p.Size
		local out = {}
		for _, sx in ipairs({ -0.5, 0.5 }) do
			for _, sy in ipairs({ -0.5, 0.5 }) do
				for _, sz in ipairs({ -0.5, 0.5 }) do
					table.insert(out, cf * Vector3.new(sx * s.X, sy * s.Y, sz * s.Z))
				end
			end
		end
		return out
	end
	-- bir parca listesinin eksen hizali sinirlari
	local function bounds(parts)
		local b = { minX = math.huge, maxX = -math.huge, minY = math.huge, maxY = -math.huge, minZ = math.huge, maxZ = -math.huge }
		for _, p in ipairs(parts) do
			for _, c in ipairs(corners(p)) do
				b.minX, b.maxX = math.min(b.minX, c.X), math.max(b.maxX, c.X)
				b.minY, b.maxY = math.min(b.minY, c.Y), math.max(b.maxY, c.Y)
				b.minZ, b.maxZ = math.min(b.minZ, c.Z), math.max(b.maxZ, c.Z)
			end
		end
		return b
	end
	local function partsOf(inst)
		local out = {}
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
		return out
	end

	local booths = workspace.Booths:GetChildren()
	local plazaHalf = workspace.Map.Plaza.PlazaFloor.Size.X / 2
	local parkHalf = 0
	for _, h in ipairs(workspace.Map.Scenery:GetChildren()) do
		if h.Name == "Hedge" then
			parkHalf = math.max(parkHalf, math.abs(h.Position.X), math.abs(h.Position.Z))
		end
	end
	parkHalf = math.floor(parkHalf + 0.5)
	check(#booths == 24 and plazaHalf == 106 and parkHalf == 232, "24 stand; meydan yari boyutu " .. plazaHalf .. ", park " .. parkHalf)

	-- her stand: dogru yone bakiyor, giris yollarini kapatmiyor, meydanin icinde
	local boxes = {}
	local sideCount = { 0, 0, 0, 0 }
	for _, b in ipairs(booths) do
		local base = b.PrimaryPart
		local pos, look = base.Position, base.CFrame.LookVector
		local axisAligned = math.abs(look.X) > 0.9999 or math.abs(look.Z) > 0.9999
		assert(axisAligned, b.Name .. ": on yuz kenara dik degil (" .. tostring(look) .. ")")
		assert(look.X * pos.X + look.Z * pos.Z < 0, b.Name .. ": on yuz meydan merkezine bakmiyor")
		local solid = {}
		for _, p in ipairs(partsOf(b)) do
			if p.CanCollide then
				table.insert(solid, p)
			end
		end
		local sb = bounds(solid)
		local nearAxis = math.min(math.abs(sb.minX), math.abs(sb.maxX), math.abs(sb.minZ), math.abs(sb.maxZ))
		local minAbsX = (sb.minX <= 0 and sb.maxX >= 0) and 0 or math.min(math.abs(sb.minX), math.abs(sb.maxX))
		local minAbsZ = (sb.minZ <= 0 and sb.maxZ >= 0) and 0 or math.min(math.abs(sb.minZ), math.abs(sb.maxZ))
		assert(math.max(minAbsX, minAbsZ) >= 8.4, b.Name .. ": giris yolunu (|x| veya |z| < 8) kapatiyor")
		local all = bounds(partsOf(b))
		assert(math.max(math.abs(all.minX), math.abs(all.maxX), math.abs(all.minZ), math.abs(all.maxZ)) <= plazaHalf - 8, b.Name .. ": meydan disina tasiyor")
		table.insert(boxes, { name = b.Name, b = all })
		local dom = (math.abs(pos.X) > math.abs(pos.Z)) and (pos.X > 0 and 1 or 2) or (pos.Z > 0 and 3 or 4)
		sideCount[dom] = sideCount[dom] + 1
	end
	check(sideCount[1] == 6 and sideCount[2] == 6 and sideCount[3] == 6 and sideCount[4] == 6, "4 kenarin her birinde 6 stand (sira sira, kenara dik)")
	check(true, "her stand kenara dik, merkeze bakiyor, giris yollarini kapatmiyor, meydanin icinde")

	-- hicbir iki stand ust uste binmiyor / birbirine yapismiyor (en az 3 stud bosluk)
	local minGap = math.huge
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, c = boxes[i].b, boxes[j].b
			local gapX = math.max(a.minX, c.minX) - math.min(a.maxX, c.maxX)
			local gapZ = math.max(a.minZ, c.minZ) - math.min(a.maxZ, c.maxZ)
			local gap = math.max(gapX, gapZ)
			assert(gap >= 3, boxes[i].name .. " ve " .. boxes[j].name .. " arasinda yeterli bosluk yok (" .. string.format("%.2f", gap) .. ")")
			minGap = math.min(minGap, gap)
		end
	end
	check(true, string.format("hicbir iki stand ust uste binmiyor (en dar bosluk %.1f stud)", minGap))

	-- yumurta, tabela, tezgah, ankraj
	local signs = game:GetService("CollectionService"):GetTagged("BoothSign")
	local bobs = game:GetService("CollectionService"):GetTagged("FX_Bob")
	check(#signs == 24 and #bobs == 24, "24 tabela etiketi ve 24 yumurta etiketi")
	for _, b in ipairs(booths) do
		for _, n in ipairs({ "Egg", "Counter", "CounterTop", "SignBoard", "Platform", "BackWall", "Base" }) do
			assert(b:FindFirstChild(n), b.Name .. " icinde " .. n .. " yok")
		end
		local label = b.SignBoard.SurfaceGui.TextLabel
		local idx = tonumber(b.Name:match("%d+"))
		assert(label:GetAttribute("BoothNumber") == idx and label.Text == string.format("STAND %02d", idx), b.Name .. ": tabela numarasi yanlis")
		assert(b.SignBoard.SurfaceGui.Face == Enum.NormalId.Front, b.Name .. ": tabela yazisi on yuzde degil")
		local egg, board = b.Egg, b.SignBoard
		assert(egg.Position.Y > board.Position.Y + 1.5, b.Name .. ": yumurta tabelanin ustunde degil")
		assert((egg.Position - board.Position).Magnitude < 6, b.Name .. ": yumurta tabeladan cok uzakta")
	end
	check(true, "her standda tezgah, tabela (numara dogru), yumurta (tabelanin ustunde), ankraj var")

	-- ayakta duran bir karakter tezgahin ustunden gorur; tezgah en fazla 3.6 stud
	local b1 = booths[1]
	check(b1.CounterTop.Position.Y + b1.CounterTop.Size.Y / 2 <= 3.6, "tezgah yuksekligi karakter bel/gogus hizasinda (<= 3.6 stud)")
	local anchorY = b1.PrimaryPart.Position.Y
	check(anchorY > 3.6 and anchorY < 5.2, "istem prompt'u tezgahin hemen ustunde (y=" .. anchorY .. ")")

	-- giris yollari: stand/mobilya/agac hicbiri koridoru (|x| ya da |z| < 8) kapatmiyor
	local checked = 0
	for _, folder in ipairs({ workspace.Map.Decor, workspace.Map.Trees }) do
		for _, p in ipairs(partsOf(folder)) do
			if p.CanCollide then
				local bb = bounds({ p })
				local minAbsX = (bb.minX <= 0 and bb.maxX >= 0) and 0 or math.min(math.abs(bb.minX), math.abs(bb.maxX))
				local minAbsZ = (bb.minZ <= 0 and bb.maxZ >= 0) and 0 or math.min(math.abs(bb.minZ), math.abs(bb.maxZ))
				assert(math.max(minAbsX, minAbsZ) >= 8.4, p:GetFullName() .. " yolu kapatiyor")
				checked = checked + 1
			end
		end
	end
	check(true, checked .. " carpismali mobilya/agac parcasi yollari kapatmiyor")

	-- park agaclari: meydanin disinda, yollardan uzak, citlik icinde
	local parkTrees, cornerTrees = 0, 0
	for _, t in ipairs(workspace.Map.Trees:GetChildren()) do
		if t.Name == "Trunk" then
			local ax, az = math.abs(t.Position.X), math.abs(t.Position.Z)
			if math.max(ax, az) > plazaHalf then
				assert(math.min(ax, az) >= 20 and math.max(ax, az) <= parkHalf - 10, "park agaci kotu yerde: " .. tostring(t.Position))
				parkTrees = parkTrees + 1
			else
				cornerTrees = cornerTrees + 1
			end
		end
	end
	check(cornerTrees == 4 and parkTrees >= 60, "4 kose agaci + " .. parkTrees .. " park agaci, hepsi yollardan uzak ve citligin icinde")

	-- hicbir sey citlikten tasmiyor, cok yuksek degil
	local maxY, tooFar = 0, nil
	for _, folder in ipairs({ workspace.Booths, workspace.Map.Plaza, workspace.Map.Decor, workspace.Map.Trees }) do
		for _, p in ipairs(partsOf(folder)) do
			local bb = bounds({ p })
			maxY = math.max(maxY, bb.maxY)
			if math.max(math.abs(bb.minX), math.abs(bb.maxX), math.abs(bb.minZ), math.abs(bb.maxZ)) > parkHalf then
				tooFar = p:GetFullName()
			end
		end
	end
	check(tooFar == nil, "stand/meydan/mobilya/agaclar park citliginin icinde" .. (tooFar and (" (tasan: " .. tooFar .. ")") or ""))
	check(maxY < 45, string.format("hicbir sey 45 stud'dan yuksek degil (en yuksek %.1f)", maxY))

	-- dogma noktalari meydanda, cesmenin disinda
	for k = 1, 4 do
		local sp = workspace["Spawn" .. k]
		local d = math.sqrt(sp.Position.X ^ 2 + sp.Position.Z ^ 2)
		assert(d > 14 and d < plazaHalf - 20, "Spawn" .. k .. " kotu yerde")
	end
	check(true, "4 dogma noktasi meydanda, cesmenin disinda")

	-- performans butcesi
	local count = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") then
			count = count + 1
		end
	end
	check(count < 2200, "toplam parca sayisi makul (" .. count .. " < 2200)")
end
