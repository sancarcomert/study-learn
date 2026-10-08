-- dev/test_egg.lua : EggModel - yumurta sekli, nadirlik gorunumleri, olcek, efektler
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== EggModel ==")
	local Config = require(__SSS.Modules.Config)
	local EggModel = require(__SSS.Modules.EggModel)
	local Hatchery = require(__SSS.Modules.HatcheryService)
	local CS = game:GetService("CollectionService")

	local booth = workspace.Booths.Booth_3
	Hatchery.BuildBooth(booth)
	local egg, pad = booth:FindFirstChild("Egg"), booth:FindFirstChild("EggPad")
	check(egg ~= nil and egg:IsA("Model") and egg.PrimaryPart ~= nil and egg.PrimaryPart.Name == "Core", "Egg bir Model, PrimaryPart=Core")
	check(pad ~= nil and pad:IsA("Model"), "EggPad modeli var")
	check(CS:HasTag(egg, "FX_Egg"), "istemci animasyonu icin FX_Egg etiketi")

	-- konum: standin en ust noktasinin uzerinde, ortada, cesmeye bakar
	local anchor = egg:GetAttribute("Anchor")
	check(anchor ~= nil and anchor.Y > 11 and anchor.Y < 13.5, string.format("yumurta standin ustunde (y=%.2f)", anchor.Y))
	local boothCenter = booth.Platform.Position
	local flat = Vector3.new(anchor.X - boothCenter.X, 0, anchor.Z - boothCenter.Z)
	check(flat.Magnitude < 1.5, string.format("yumurta standin ortasinda (kayma %.2f)", flat.Magnitude))
	local toFountain = (Vector3.new(0, 0, 0) - Vector3.new(anchor.X, 0, anchor.Z)).Unit
	check(anchor.LookVector:Dot(toFountain) > 0.99, "yumurtanin on yuzu cesmeye bakiyor")
	check(booth:GetAttribute("EggAnchor") == anchor, "booth'ta EggAnchor attribute'u (susler icin)")

	-- tum parcalar guvenli: demirli, carpismaz, sorgulanmaz
	local bad = 0
	for _, p in ipairs(egg:GetDescendants()) do
		if p:IsA("BasePart") and not (p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery) then
			bad = bad + 1
		end
	end
	for _, p in ipairs(pad:GetDescendants()) do
		if p:IsA("BasePart") and not (p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery) then
			bad = bad + 1
		end
	end
	check(bad == 0, "yumurta ve zemin parcalari demirli, carpismaz, dokunulmaz")

	-- sekil: kabuk gercek bir yumurta (ust uca dogru dar), sapma kucuk
	EggModel.Apply(booth, { Tier = 1, Accent = Config.RARITIES[1].Color, Scale = 1, Instant = true })
	local balls = {}
	for i = 1, 13 do
		local s = egg:FindFirstChild("Shell" .. i)
		assert(s, "Shell" .. i .. " yok")
		table.insert(balls, { s.Position.Y - anchor.Y, s.Size.X / 2 })
	end
	local function profile(y)
		local t = y / 1.8
		return 1.35 * math.sqrt(math.max((1 - t * t) / (1 + 0.3 * t), 0))
	end
	local worst = 0
	for i = 0, 400 do
		local y = -1.8 + 3.6 * i / 400
		local r = profile(y)
		local best = math.huge
		for _, b in ipairs(balls) do
			best = math.min(best, math.abs(math.sqrt(r * r + (y + 0.8 + 1.8 - b[1]) ^ 2) - b[2]))
		end
		worst = math.max(worst, best)
	end
	check(worst < 0.03, string.format("kabuk yumurta egrisine uyuyor (en kotu sapma %.3f stud)", worst))
	local function envelope(y)
		local e = 0
		for _, b in ipairs(balls) do
			local d = b[2] ^ 2 - (y - b[1]) ^ 2
			if d > 0 then
				e = math.max(e, math.sqrt(d))
			end
		end
		return e
	end
	check(envelope(0.8 + 1.8 + 0.9) < envelope(0.8 + 1.8 - 0.9) - 0.12, "yumurtanin ustu altindan dar (yumurta sekli, kure degil)")

	-- nadirlik gorunumleri
	local function count(prefix)
		local n = 0
		for _, c in ipairs(egg:GetChildren()) do
			if string.sub(c.Name, 1, #prefix) == prefix then
				n = n + 1
			end
		end
		return n
	end
	local function look(tier, accent)
		EggModel.Apply(booth, { Tier = tier, Accent = accent or Config.RARITIES[math.max(tier, 1)].Color, Scale = 1, Instant = true })
	end

	look(0, Color3.fromRGB(190, 186, 178))
	check(count("Shell") == 13 and count("Speck") == 0 and count("Band") == 0 and count("Gem") == 0, "sahipsiz: sade soluk kabuk")
	check(pad.PadOuter.Transparency >= 0.85 and pad:FindFirstChild("Beam") == nil, "sahipsiz: zemin isigi soluk, isik sutunu yok")

	look(1)
	check(count("Speck") == 9 and count("Band") == 1 and count("Gem") == 0, "Yaygin: 9 benek, 1 bant, tas yok")
	check(egg.Shell5.Material == Enum.Material.SmoothPlastic and egg.Shell5.Color.R > 0.9, "Yaygin: krem pürüzsüz kabuk")
	check(pad:FindFirstChild("Beam") == nil, "Yaygin: isik sutunu yok")

	look(2)
	check(count("Speck") == 0 and count("Band") == 2 and count("Gem") == 3, "Nadir: 2 bant, 3 yoringe tasi")
	check(egg.Shell5.Reflectance > 0.05, "Nadir: parlak (yansimali) kabuk")
	local gem = egg.Gem1
	check(gem:GetAttribute("OR") > 1.5 and gem:GetAttribute("OS") > 0 and gem:FindFirstChildOfClass("Trail") ~= nil, "tasin yorunge verisi ve izi (Trail) var")
	check(egg.Heart.Aura.Enabled == true and egg.Heart.Aura.Rate == Config.RARITIES[2].AuraRate, "Nadir: surekli kivilcim")

	look(3)
	check(count("Band") == 3 and count("Gem") == 4 and egg.Shell5.Material == Enum.Material.Metal, "Efsanevi: altin metal, 3 bant, 4 tas")
	check(pad:FindFirstChild("Beam") ~= nil, "Efsanevi: isik sutunu")

	look(4)
	check(count("Gem") == 6 and egg.Shell5.Material == Enum.Material.Neon and egg.Band1.Material == Enum.Material.SmoothPlastic, "Mitik: neon kabuk, koyu bantlar, 6 tas")
	local tilts = {}
	for i = 1, 6 do
		tilts[egg["Gem" .. i]:GetAttribute("OT")] = true
	end
	check(tilts[0.5] and tilts[-0.5], "Mitik: iki farkli yorunge duzlemi")

	-- oyuncunun sectigi renk susleri boyar
	local pink = Config.STYLE_COLORS[8].Color
	look(2, pink)
	check(egg.Band1.Color == pink and egg.Gem1.Color == pink and pad.PadOuter.Color == pink, "secilen renk bant, tas ve zemine islenir")

	-- ayni gorunum tekrar uygulanirsa yeniden kurulmaz; sadece olcek degisirse parcalar korunur
	local shell1 = egg.Shell1
	look(2, pink)
	check(egg.Shell1 == shell1, "ayni gorunumde parcalar yeniden kurulmaz")
	EggModel.Apply(booth, { Tier = 2, Accent = pink, Scale = 1.6, Instant = true })
	check(egg.Shell1 == shell1 and math.abs(shell1.Size.X - shell1:GetAttribute("BS").X * 1.6) < 1e-9, "olcek degisince ayni parcalar buyur")
	check(math.abs(egg:GetAttribute("Scale") - 1.6) < 1e-9 and math.abs(pad:GetAttribute("Scale") - 1.6) < 1e-9, "Scale attribute'u (istemci okur)")
	local bo = shell1:GetAttribute("BO")
	local expectedPos = (anchor * CFrame.new(bo.Position * 1.6)).Position
	check((shell1.Position - expectedPos).Magnitude < 1e-6, "buyuyen parcanin konumu orijine gore olceklenir")
	look(3, pink)
	check(egg.Shell1 ~= shell1, "nadirlik degisince kabuk yeniden kurulur")
	check(egg:GetAttribute("Scale") == 1.6 or math.abs(egg:GetAttribute("Scale") - 1) < 1e-9, "yeniden kurulumda olcek korunur")

	-- yumusak buyume: adim adim, sonunda hedef; yarida yeni hedef gelirse sonuncusu kazanir
	look(2, pink)
	EggModel.Apply(booth, { Tier = 2, Accent = pink, Scale = 1.0, Instant = true })
	EggModel.Apply(booth, { Tier = 2, Accent = pink, Scale = 1.5 })
	check(math.abs(egg:GetAttribute("Scale") - 1.0) < 1e-9, "buyume hemen ziplamaz")
	__advance(0.1)
	local mid = egg:GetAttribute("Scale")
	check(mid > 1.0 and mid < 1.6, string.format("buyume adim adim ilerliyor (ara olcek %.3f)", mid))
	EggModel.Apply(booth, { Tier = 2, Accent = pink, Scale = 2.0 })
	__advance(1)
	check(math.abs(egg:GetAttribute("Scale") - 2.0) < 1e-9, "yarida gelen yeni hedef kazanir (2.0)")
	check(math.abs(egg.Shell1.Size.X - egg.Shell1:GetAttribute("BS").X * 2.0) < 1e-9, "parcalar son olcege oturdu")

	-- Pulse: gecici halka, sonra silinir
	local before = #booth:GetChildren()
	EggModel.Pulse(booth, Color3.fromRGB(255, 210, 70), 11)
	local ring = booth:FindFirstChild("PulseRing")
	check(ring ~= nil and ring.Shape == Enum.PartType.Cylinder and ring.CanCollide == false, "Pulse zeminde carpismayan halka olusturur")
	__advance(0.9)
	check(ring.Transparency > 0.99 and ring.Size.Y > 11, "halka genisleyip sonuyor")
	__advance(0.5)
	check(booth:FindFirstChild("PulseRing") == nil and #booth:GetChildren() == before, "halka kendiliginden silinir " .. tostring(booth:FindFirstChild("PulseRing")) .. " " .. #booth:GetChildren() .. "/" .. before)

	-- Flash: kabuk beyaza doner, sonra eski haline
	look(3)
	local c0, m0 = egg.Shell5.Color, egg.Shell5.Material
	EggModel.Flash(booth, 0.3)
	check(egg.Shell5.Color == Color3.new(1, 1, 1) and egg.Shell5.Material == Enum.Material.Neon, "Flash: kabuk beyaz neon")
	__advance(0.4)
	check(egg.Shell5.Color == c0 and egg.Shell5.Material == m0, "Flash sonrasi kabuk eski rengine dondu")

	-- tier hesabi
	check(EggModel.TierOf(1) == 1 and EggModel.TierOf(4) == 1 and EggModel.TierOf(5) == 2 and EggModel.TierOf(10) == 3 and EggModel.TierOf(20) == 4 and EggModel.TierOf(50) == 4, "seviyeden gorunum seviyesi")

	-- sizinti yok: cok kez yeniden kurulunca parca sayisi sabit
	for i = 1, 30 do
		look((i % 4) + 1, Config.STYLE_COLORS[(i % 8) + 1].Color)
	end
	local total = #egg:GetDescendants() + #pad:GetDescendants()
	look(3, Config.STYLE_COLORS[1].Color)
	local total2 = #egg:GetDescendants() + #pad:GetDescendants()
	check(total2 < 80 and #booth:GetChildren() <= before + 1, "30 yeniden kurulumdan sonra parca birikmedi (" .. total2 .. ")")
	Hatchery.SetUnclaimed(booth)
end
