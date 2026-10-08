-- dev/test_client.lua : MapFX - yumurta yuzme/donme/yoringe animasyonu ve tabela adlari
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== MapFX ==")
	local Players = game:GetService("Players")
	local Config = require(__SSS.Modules.Config)
	local EggModel = require(__SSS.Modules.EggModel)
	local Hatchery = require(__SSS.Modules.HatcheryService)

	local booth = workspace.Booths.Booth_3
	Hatchery.BuildBooth(booth)
	local pink = Config.STYLE_COLORS[8].Color
	EggModel.Apply(booth, { Tier = 2, Accent = pink, Scale = 1.5, Instant = true })
	local egg = booth.Egg
	local anchor = egg:GetAttribute("Anchor")
	local phase, speed, height, spin = egg:GetAttribute("BobPhase"), egg:GetAttribute("BobSpeed"), egg:GetAttribute("BobHeight"), egg:GetAttribute("SpinSpeed")

	local function pivotAt(t, scale)
		local floating = anchor * CFrame.new(0, math.sin(t * speed + phase) * height * scale, 0)
		return floating, floating * CFrame.Angles(0, t * spin + phase, 0)
	end

	-- yeni eklenen yumurta da yakalanir (etiket sonradan geldi)
	__setTime(0.7)
	__fireHeartbeat()
	local floating, pivot = pivotAt(0.7, 1.5)
	check((egg.Core.Position - pivot.Position).Magnitude < 1e-9, string.format("yumurta yuzuyor (y=%.4f beklenen=%.4f)", egg.Core.Position.Y, pivot.Position.Y))
	check(math.abs(egg.Core.Position.X - anchor.X) < 1e-9 and math.abs(egg.Core.Position.Z - anchor.Z) < 1e-9, "yumurta yatayda kaymiyor")
	local shell = egg.Shell5
	local bo = shell:GetAttribute("BO")
	local expected = pivot * CFrame.new(bo.Position * 1.5) * (bo - bo.Position)
	check((shell.Position - expected.Position).Magnitude < 1e-9, "kabuk parcalari cekirdekle birlikte yuzuyor ve donuyor")
	check(math.abs(shell.Size.X - shell:GetAttribute("BS").X * 1.5) < 1e-9, "parca boyutlari olcege uyuyor")

	-- yoringe taslari: yumurta merkezinin etrafinda, yaricap olcekle buyur
	local gem = egg.Gem1
	local center = (floating * CFrame.new(0, gem:GetAttribute("OY") * 1.5, 0)).Position
	local dist = (gem.Position - center).Magnitude
	check(math.abs(dist - gem:GetAttribute("OR") * 1.5) < 1e-6, string.format("tas yoringede: merkeze uzaklik %.3f = yaricap x olcek %.3f", dist, gem:GetAttribute("OR") * 1.5))
	local p1 = gem.Position
	__setTime(1.4)
	__fireHeartbeat()
	local p2 = gem.Position
	check((p1 - p2).Magnitude > 0.5, "tas zamanla hareket ediyor")
	local distLater = (gem.Position - (select(1, pivotAt(1.4, 1.5)) * CFrame.new(0, gem:GetAttribute("OY") * 1.5, 0)).Position).Magnitude
	check(math.abs(distLater - gem:GetAttribute("OR") * 1.5) < 1e-6, "yaricap hareket boyunca sabit")

	-- sunucu parcayi yerinden oynatirsa (coğaltma) bir sonraki karede duzelir
	shell.CFrame = shell.CFrame + Vector3.new(5, 5, 5)
	__setTime(1.5)
	__fireHeartbeat()
	local _, pivot2 = pivotAt(1.5, 1.5)
	local expected2 = pivot2 * CFrame.new(bo.Position * 1.5) * (bo - bo.Position)
	check((shell.Position - expected2.Position).Magnitude < 1e-9, "disaridan oynatilan parca bir sonraki karede yerine doner")

	-- olcek degisimi
	EggModel.Apply(booth, { Tier = 2, Accent = pink, Scale = 2.0, Instant = true })
	__setTime(2.0)
	__fireHeartbeat()
	check(math.abs(shell.Size.X - shell:GetAttribute("BS").X * 2.0) < 1e-9, "olcek 2.0'a cikinca parca boyutlari guncellendi")

	-- yumurta yeniden kurulunca (nadirlik degisti) yeni parcalar da canlanir
	EggModel.Apply(booth, { Tier = 3, Accent = pink, Scale = 2.0, Instant = true })
	__setTime(2.5)
	__fireHeartbeat()
	local newShell = egg.Shell5
	local _, pivot3 = pivotAt(2.5, 2.0)
	local bo3 = newShell:GetAttribute("BO")
	local expected3 = pivot3 * CFrame.new(bo3.Position * 2.0) * (bo3 - bo3.Position)
	check((newShell.Position - expected3.Position).Magnitude < 1e-9, "yeniden kurulan yumurta da animasyona dahil")
	check(egg.Gem4 ~= nil and egg.Gem4:GetAttribute("OR") ~= nil, "Efsanevi gorunumunde 4 yoringe tasi")

	-- uzun sure: hata birikmemeli
	local t0 = os.clock()
	local worst = 0
	for i = 1, 3000 do
		__setTime(3 + i / 30)
		__fireHeartbeat()
		worst = math.max(worst, math.abs(egg.Core.Position.Y - anchor.Y))
	end
	check(worst <= height * 2.0 + 1e-9 and math.abs(egg.Core.Position.X - anchor.X) < 1e-9, string.format("3000 kare sonra yumurta hala sinirlar icinde (sapma %.3f <= %.3f, %.1fs)", worst, height * 2.0, os.clock() - t0))

	-- uzaktaki yumurta (kamera menzili disi) guncellenmez
	local cam0 = workspace.CurrentCamera
	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.new(anchor.Position + Vector3.new(500, 0, 0))
	workspace.CurrentCamera = cam
	local frozen = egg.Core.Position
	__setTime(500)
	__fireHeartbeat()
	check((egg.Core.Position - frozen).Magnitude < 1e-9, "140 stud'dan uzaktaki yumurta guncellenmez (performans)")
	cam.CFrame = CFrame.new(anchor.Position + Vector3.new(20, 0, 0))
	__setTime(501.3)
	__fireHeartbeat()
	check((egg.Core.Position - frozen).Magnitude > 1e-6, "kamera yaklasinca yumurta tekrar canlanir")
	workspace.CurrentCamera = cam0

	-- tabela
	local b2 = workspace.Booths.Booth_2
	local sg = Instance.new("SurfaceGui")
	sg.Parent = b2.SignBoard
	local label = Instance.new("TextLabel")
	label.Parent = sg
	label:SetAttribute("BoothNumber", 1)
	game:GetService("CollectionService"):AddTag(label, "BoothSign")
	check(label.Text == "STAND 01", "sahipsiz stand tabelasi: " .. tostring(label.Text))
	local alice = Instance.new("Player")
	alice.Name = "Alice"
	alice.UserId = 1001
	alice.Parent = Players
	b2:SetAttribute("OwnerUserId", 1001)
	check(label.Text == "Alice", "sahip gelince tabela oyuncunun adini gosteriyor: " .. label.Text)
	b2:SetAttribute("OwnerUserId", nil)
	check(label.Text == "STAND 01", "sahip cikinca tabela tekrar 'STAND 01'")
	b2:SetAttribute("OwnerUserId", 9999)
	check(label.Text == "STAND 01", "bilinmeyen sahip kimligi cokmeden 'STAND 01' gosterir")
	b2:SetAttribute("OwnerUserId", nil)
	alice:Destroy()
	Hatchery.SetUnclaimed(booth)
end
