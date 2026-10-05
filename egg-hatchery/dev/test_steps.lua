-- dev/test_steps.lua : 6 Command Bar adimi (command_bar/steps) sonunda harita dogru mu?
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== Adimlar (Command Bar) ==")
	local map = workspace.Map
	local function descendants(inst)
		local out = {}
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
		return out
	end
	local function bounds(parts)
		local b = { x0 = math.huge, x1 = -math.huge, y0 = math.huge, y1 = -math.huge, z0 = math.huge, z1 = -math.huge }
		for _, p in ipairs(parts) do
			for _, sx in ipairs({ -0.5, 0.5 }) do
				for _, sy in ipairs({ -0.5, 0.5 }) do
					for _, sz in ipairs({ -0.5, 0.5 }) do
						local c = p.CFrame * Vector3.new(sx * p.Size.X, sy * p.Size.Y, sz * p.Size.Z)
						b.x0, b.x1 = math.min(b.x0, c.X), math.max(b.x1, c.X)
						b.y0, b.y1 = math.min(b.y0, c.Y), math.max(b.y1, c.Y)
						b.z0, b.z1 = math.min(b.z0, c.Z), math.max(b.z1, c.Z)
					end
				end
			end
		end
		return b
	end
	for _, n in ipairs({ "Ground", "Plaza", "Center", "Park", "Spawn", "Boards" }) do
		check(map:FindFirstChild(n) ~= nil, "Map." .. n .. " var (" .. #descendants(map[n]) .. " parca)")
	end
	check(workspace:FindFirstChild("Baseplate") == nil, "Baseplate silindi")

	-- standlar
	local booths = workspace.Booths:GetChildren()
	check(#booths == 24, "24 stand (tekrar calistirmada cogalmadi)")
	local boxes = {}
	for _, b in ipairs(booths) do
		for _, n in ipairs({ "Egg", "Counter", "CounterTop", "SignBoard", "Platform", "Base" }) do
			assert(b:FindFirstChild(n), b.Name .. ": " .. n .. " yok")
		end
		assert(b.PrimaryPart == b.Base, b.Name .. ": PrimaryPart Base degil")
		local bb = bounds(descendants(b))
		assert(bb.y1 >= 9 and bb.y1 <= 12, string.format("%s: yukseklik %.1f", b.Name, bb.y1))
		local pos, look = b.Base.Position, b.Base.CFrame.LookVector
		assert(look.X * pos.X + look.Z * pos.Z < 0 and (math.abs(look.X) > 0.999 or math.abs(look.Z) > 0.999), b.Name .. ": merkeze/kenara dik bakmiyor")
		local dist = math.max(math.abs(pos.X), math.abs(pos.Z))
		assert(dist > 80 and dist < 92, b.Name .. ": stand hatti disinda " .. dist)
		assert(math.max(math.abs(bb.x0), math.abs(bb.x1), math.abs(bb.z0), math.abs(bb.z1)) <= 106, b.Name .. ": meydandan tasiyor")
		-- giris yolu (|x| veya |z| < 8) bos
		local solid = {}
		for _, p in ipairs(descendants(b)) do
			if p.CanCollide then
				table.insert(solid, p)
			end
		end
		local sb = bounds(solid)
		local mx = (sb.x0 <= 0 and sb.x1 >= 0) and 0 or math.min(math.abs(sb.x0), math.abs(sb.x1))
		local mz = (sb.z0 <= 0 and sb.z1 >= 0) and 0 or math.min(math.abs(sb.z0), math.abs(sb.z1))
		assert(math.min(mx, mz) >= 8.4, b.Name .. ": yolu kapatiyor")
		table.insert(boxes, { n = b.Name, b = bb })
	end
	local gap = math.huge
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, c = boxes[i].b, boxes[j].b
			local g = math.max(math.max(a.x0, c.x0) - math.min(a.x1, c.x1), math.max(a.z0, c.z0) - math.min(a.z1, c.z1))
			assert(g >= 3, boxes[i].n .. "/" .. boxes[j].n .. " cok yakin " .. g)
			gap = math.min(gap, g)
		end
	end
	check(true, string.format("24 stand: dogru yuksek, kenara dik, yol bos, en dar bosluk %.1f stud", gap))
	local cs = {}
	for _, b in ipairs(booths) do
		local c = b.Counter.Color
		cs[string.format("%.2f,%.2f,%.2f", c.R, c.G, c.B)] = true
	end
	local nc = 0
	for _ in pairs(cs) do nc = nc + 1 end
	check(nc == 8, nc .. " farkli stand rengi")
	local CS = game:GetService("CollectionService")
	check(#CS:GetTagged("FX_Bob") == 24 and #CS:GetTagged("BoothSign") == 24, "24 yumurta + 24 tabela etiketi")

	-- spawn ve panolar
	local spawns = map.Spawn:GetChildren()
	local nsp = 0
	for _, s in ipairs(spawns) do
		if s:IsA("SpawnLocation") then
			nsp = nsp + 1
			assert(math.abs(s.Position.Z - 48) < 0.01 and math.abs(s.Position.X) <= 12, "spawn yeri yanlis")
			for _, b in ipairs(boxes) do
				local bb = b.b
				assert(not (s.Position.X > bb.x0 and s.Position.X < bb.x1 and s.Position.Z > bb.z0 and s.Position.Z < bb.z1), "spawn standin icinde")
			end
		end
	end
	check(nsp == 3, "3 spawn noktasi meydanda (z=48), standlardan uzak")
	local boards = CS:GetTagged("LeaderboardBoard")
	check(#boards == 3, "3 liderlik panosu etiketli")
	local want = { Raised = true, Donated = true, Level = true }
	for _, bd in ipairs(boards) do
		assert(want[bd:GetAttribute("Stat")], "pano Stat yanlis")
		assert(bd.CFrame.LookVector.Z > 0.99, bd.Name .. ": spawn'a (guney) bakmiyor")
		assert(bd.Position.Z < -50 and bd.Position.Z > -60, bd.Name .. ": cesmenin kuzeyinde degil")
		assert(bd.SurfaceGui.Face == Enum.NormalId.Front, "pano yazisi on yuzde degil")
		local d = math.sqrt(bd.Position.X ^ 2 + (bd.Position.Z - 48) ^ 2)
		assert(d < 130, "pano spawn'a cok uzak")
	end
	local walk = (48 + 55) / 16
	check(true, string.format("panolar spawn'a bakiyor; spawn -> pano ~%.0f stud = %.1f sn", 103, walk))
	-- panolar cesme/bank/saksiyla cakismiyor
	local bbb = bounds(descendants(map.Boards))
	for _, p in ipairs(descendants(map.Center)) do
		local pb = bounds({ p })
		assert(not (pb.x1 > bbb.x0 and pb.x0 < bbb.x1 and pb.z1 > bbb.z0 and pb.z0 < bbb.z1 and pb.y0 < bbb.y1), "pano " .. p.Name .. " ile cakisiyor")
	end
	check(true, "panolar merkezdeki hicbir nesneyle cakismiyor")

	-- cesme boyutu
	local cb = bounds({ map.Center.Finial })
	check(cb.y1 <= 8 and map.Center.BasinFloor.Size.Y <= 24, string.format("cesme alcak (en yuksek %.1f stud)", cb.y1))
	-- agaclar yollardan/nehirden uzak
	local trees, bad = 0, nil
	for _, t in ipairs(map.Park:GetChildren()) do
		if t.Name == "Trunk" then
			trees = trees + 1
			local x, z = t.Position.X, t.Position.Z
			if math.min(math.abs(x), math.abs(z)) < 20 or math.abs(x - 150) < 20 or math.max(math.abs(x), math.abs(z)) < 118 then
				bad = tostring(t.Position)
			end
		end
	end
	check(trees >= 60 and bad == nil, trees .. " park agaci, hepsi yoldan, nehirden ve meydandan uzak" .. (bad and (" (kotu: " .. bad .. ")") or ""))
	-- nehir + kopru + yol bosluğu
	local deck = map.Park.BridgeDeck
	check(deck.Position.X - deck.Size.X / 2 < 150 - 5 - 6 and deck.Position.X + deck.Size.X / 2 > 150 + 5 + 6, "kopru nehri (10 stud) iki yandan tasarak kapliyor")
	local overlap = false
	for _, p in ipairs(map.Plaza:GetChildren()) do
		if p.Name == "Path" and p.Position.X > 0 and math.abs(p.Position.Z) < 9 then
			local lo, hi = p.Position.X - p.Size.Z / 2, p.Position.X + p.Size.Z / 2
			if hi > 150 - 13 + 0.01 and lo < 150 + 13 - 0.01 then
				overlap = true
			end
		end
	end
	check(not overlap, "+X yolu nehir uzerinde kesilmis (yol nehri kapatmiyor)")
	-- ay lambalari stand araliklarinda
	local lamps = 0
	for _, p in ipairs(map.Center:GetChildren()) do
		if p.Name == "LampPole" and math.max(math.abs(p.Position.X), math.abs(p.Position.Z)) > 80 then
			lamps = lamps + 1
			local ax, az = math.abs(p.Position.X), math.abs(p.Position.Z)
			local along = math.min(ax, az) > 80 and math.max(ax, az) or math.min(ax, az)
			assert(math.abs(along - 29) < 0.01 or math.abs(along - 53) < 0.01, "lamba stand araliginda degil: " .. along)
		end
	end
	check(lamps == 16, "16 lamba, hepsi iki stand arasindaki bosluklarda")
	-- parca butcesi
	local count = #descendants(workspace)
	check(count < 3500, "toplam parca sayisi makul: " .. count)
	-- isik
	local L = game:GetService("Lighting")
	check(L.Brightness == 3 and L.ClockTime == 14 and L:FindFirstChildOfClass("Atmosphere") ~= nil, "isik: Brightness 3, ClockTime 14, Atmosphere var")
end
