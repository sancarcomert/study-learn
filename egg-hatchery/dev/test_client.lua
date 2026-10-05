-- dev/test_client.lua : MapFX calistiktan sonra yumurta yuzmesi ve tabela adlari dogru mu?
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== MapFX ==")
	local Players = game:GetService("Players")
	local booth = workspace.Booths.Booth_1
	local egg = booth.Egg
	local baseCF = egg.CFrame
	local phase = egg:GetAttribute("BobPhase")

	__setTime(0.7)
	__fireHeartbeat()
	local expected = baseCF.Y + math.sin(0.7 * 1.2 + phase) * 0.2
	check(math.abs(egg.CFrame.Y - expected) < 1e-9, string.format("yumurta yuzuyor (y=%.4f beklenen=%.4f)", egg.CFrame.Y, expected))
	check(math.abs(egg.CFrame.X - baseCF.X) < 1e-9 and math.abs(egg.CFrame.Z - baseCF.Z) < 1e-9, "yumurta yatayda kaymiyor")

	local label = booth.SignBoard.SurfaceGui.TextLabel
	check(label.Text == "STAND 01", "sahipsiz stand tabelasi: " .. label.Text)
	local alice = Instance.new("Player")
	alice.Name = "Alice"
	alice.UserId = 1001
	alice.Parent = Players
	booth:SetAttribute("OwnerUserId", 1001)
	check(label.Text == "Alice", "sahip gelince tabela oyuncunun adini gosteriyor: " .. label.Text)
	booth:SetAttribute("OwnerUserId", nil)
	check(label.Text == "STAND 01", "sahip cikinca tabela tekrar 'STAND 01'")
	booth:SetAttribute("OwnerUserId", 9999)
	check(label.Text == "STAND 01", "bilinmeyen sahip kimligi cokmeden 'STAND 01' gosterir")
	booth:SetAttribute("OwnerUserId", nil)
	alice:Destroy()

	-- Uzun sure: hata birikmemeli
	local t0 = os.clock()
	for i = 1, 5000 do
		__setTime(2 + i / 30)
		__fireHeartbeat()
	end
	local dev = math.abs(egg.CFrame.Y - baseCF.Y)
	check(dev <= 0.2 + 1e-9 and math.abs(egg.CFrame.X - baseCF.X) < 1e-9, string.format("5000 kare sonra yumurta hala sinirlar icinde (sapma %.3f <= 0.2, %.1fs)", dev, os.clock() - t0))
end
