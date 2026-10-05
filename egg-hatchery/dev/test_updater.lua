-- dev/test_updater.lua : UpdateScripts.lua Studio'daki scriptlerin icerigini depodakiyle birebir esliyor mu?
do
	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== Script guncelleme komutu ==")
	local sss = game:GetService("ServerScriptService")
	local want = {
		{ sss.Modules, "Config", "ModuleScript" },
		{ sss.Modules, "HatcheryService", "ModuleScript" },
		{ sss, "EconomyManager", "Script" },
		{ sss, "MarketplaceHook", "Script" },
	}
	for _, w in ipairs(want) do
		local count = 0
		for _, c in ipairs(w[1]:GetChildren()) do
			if c.Name == w[2] then
				count = count + 1
			end
		end
		local inst = w[1]:FindFirstChild(w[2])
		check(count == 1 and inst ~= nil and inst.ClassName == w[3], w[2] .. " tek ve dogru turde (" .. w[3] .. ")")
		check(inst.Source == __EXPECTED[w[2]], w[2] .. " icerigi depodakiyle BIREBIR ayni (" .. #inst.Source .. " bayt)")
	end
	check(sss.Modules:FindFirstChild("Remotes") ~= nil and sss.Modules:FindFirstChild("BoothRegistry") ~= nil, "dokunulmayan moduller (Remotes, BoothRegistry) yerinde")
	check(sss:FindFirstChild("BoothManager") == nil or sss.BoothManager.Source == "", "BoothManager'a dokunulmadi")
end
