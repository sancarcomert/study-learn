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
		if h.Name == "Barrier" then
			parkHalf = math.max(parkHalf, math.abs(h.Position.X), math.abs(h.Position.Z))
		end
	end
	parkHalf = math.floor(parkHalf + 0.5) - 3 -- gorunmez duvar parkin 3 stud disinda
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
	check(cornerTrees == 4 and parkTrees >= 50, "4 kose agaci + " .. parkTrees .. " park agaci, hepsi yollardan uzak ve citligin icinde")

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
	check(count < 7000, "toplam parca sayisi makul (" .. count .. " < 7000)")

	---------------------------------------------------------------------
	-- Arazi, su, kopru, renkler
	---------------------------------------------------------------------
	print("== Arazi / su / dekor ==")
	local fills = workspace.Terrain:GetFills_MOCK()
	local pools, segs, hillsN = {}, {}, 0
	for _, f in ipairs(fills) do
		local mat = f.args[#f.args].Name
		if f.kind == "Cylinder" and mat == "Air" then
			table.insert(pools, { x = f.args[1].Position.X, z = f.args[1].Position.Z, r = f.args[3] })
		elseif f.kind == "Block" and mat == "Air" then
			local cf, size = f.args[1], f.args[2]
			local look = cf.LookVector
			table.insert(segs, { x = cf.Position.X, z = cf.Position.Z, lx = look.X, lz = look.Z, half = size.Z / 2, w = size.X })
		elseif f.kind == "Ball" then
			hillsN = hillsN + 1
			local c, R = f.args[1], f.args[2]
			local h = c.Y + R
			local foot = math.sqrt(2 * R * h - h * h)
			local d = math.sqrt(c.X ^ 2 + c.Z ^ 2)
			assert(d - foot >= parkHalf + 30, string.format("tepe parka giriyor (mesafe %.0f, taban %.0f)", d, foot))
		end
	end
	check(#pools == 2 and #segs == 8 and hillsN == 16, string.format("2 gol, %d dere parcasi, %d tepe; hicbir tepe parka girmiyor", #segs, hillsN))
	-- su sirasi: kum -> hava -> su (kum en sona kalirsa suyu doldurur)
	local order = {}
	for _, f in ipairs(fills) do
		table.insert(order, f.args[#f.args].Name)
	end
	local lastSand, firstAir, lastAir, firstWater = 0, math.huge, 0, math.huge
	for i, m in ipairs(order) do
		if m == "Sand" then lastSand = i end
		if m == "Air" then firstAir = math.min(firstAir, i); lastAir = i end
		if m == "Water" then firstWater = math.min(firstWater, i) end
	end
	check(lastSand < firstAir and lastAir < firstWater, "dolgu sirasi dogru: once kum, sonra oyuk, en sonda su")

	local function distToSeg(px, pz, s)
		local dx, dz = px - s.x, pz - s.z
		local along = math.clamp(dx * s.lx + dz * s.lz, -s.half, s.half)
		local cx, cz = s.x + s.lx * along, s.z + s.lz * along
		return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
	end
	local function waterDistance(px, pz)
		local best = math.huge
		for _, pl in ipairs(pools) do
			best = math.min(best, math.sqrt((px - pl.x) ^ 2 + (pz - pl.z) ^ 2) - pl.r)
		end
		for _, sg in ipairs(segs) do
			best = math.min(best, distToSeg(px, pz, sg) - sg.w / 2)
		end
		return best
	end
	local minTree = math.huge
	for _, t in ipairs(workspace.Map.Trees:GetChildren()) do
		if t.Name == "Trunk" then
			minTree = math.min(minTree, waterDistance(t.Position.X, t.Position.Z))
		end
	end
	check(minTree >= 6, string.format("hicbir agac suya 6 stud'dan yakin degil (en yakin %.1f)", minTree))
	local minDecor = math.huge
	for _, p in ipairs(partsOf(workspace.Map.Decor)) do
		if p.CanCollide then
			minDecor = math.min(minDecor, waterDistance(p.Position.X, p.Position.Z))
		end
	end
	check(minDecor >= 1, string.format("carpismali mobilya suyun icinde degil (en yakin %.1f)", minDecor))

	-- kopru dereyi tamamen kapliyor, yol parcasi kopruyle cakismiyor
	local deck = workspace.Map.Water.BridgeDeck
	local streamX
	for _, sg in ipairs(segs) do
		if math.abs(sg.z) < 20 and math.abs(sg.lz) > 0.5 then
			local t = (0 - sg.z) / sg.lz
			if math.abs(t) <= sg.half then
				streamX = sg.x + sg.lx * t
			end
		end
	end
	assert(streamX, "dere z=0'da bulunamadi")
	check(deck.Position.X - deck.Size.X / 2 < streamX - 4 - 3 and deck.Position.X + deck.Size.X / 2 > streamX + 4 + 3, string.format("kopru dereyi (x=%.1f) iki yandan tasarak kapliyor", streamX))
	local deckMin, deckMax = deck.Position.X - deck.Size.X / 2, deck.Position.X + deck.Size.X / 2
	for _, p in ipairs(workspace.Map.Plaza:GetChildren()) do
		if p.Name == "Path" and math.abs(p.Position.Z) < 9 and p.Position.X > 0 then
			local lo, hi = p.Position.X - p.Size.Z / 2, p.Position.X + p.Size.Z / 2
			-- +X yolu X ekseninde uzar
			assert(hi <= deckMin + 0.5 or lo >= deckMax - 0.5, "yol parcasi dereyi/kopruyu ortuyor")
		end
	end
	check(true, "+X yolu dere uzerinde kesilmis, kopru oraya oturuyor")

	-- stand renkleri: 8 farkli renk, yan yana iki stand ayni renkte degil
	local colors, same = {}, 0
	local list = workspace.Booths:GetChildren()
	table.sort(list, function(a, b) return tonumber(a.Name:match("%d+")) < tonumber(b.Name:match("%d+")) end)
	local prev
	local distinct = {}
	for idx, b in ipairs(list) do
		local c = b.Awning.Color
		local key = string.format("%.2f,%.2f,%.2f", c.R, c.G, c.B)
		distinct[key] = true
		if prev == key and (idx - 1) % 6 ~= 0 then
			same = same + 1
		end
		prev = key
	end
	local n = 0
	for _ in pairs(distinct) do n = n + 1 end
	check(n == 8 and same == 0, n .. " farkli stand rengi, yan yana ayni renk yok")

	-- 4 yol kapisi, 4 patika, su kenari esyalari
	local gates, stones = 0, 0
	for _, p in ipairs(workspace.Map.Decor:GetChildren()) do
		if p.Name == "GateSign" then gates = gates + 1 end
		if p.Name == "StepStone" then stones = stones + 1 end
	end
	check(gates == 4 and stones >= 80, gates .. " kapi tabelasi, " .. stones .. " patika tasi")
	check(workspace.Map.Water:FindFirstChild("DockPlank") ~= nil and #workspace.Map.Water:GetChildren() > 100, "iskele, kopru, kamis, nilufer ve kayalar var")
end
