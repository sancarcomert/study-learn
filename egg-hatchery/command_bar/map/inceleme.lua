-- HARITA INCELEME: haritadaki isimleri gruplayip sayar, standlari ve scriptleri listeler. Hicbir seyi degistirmez.
local root
for _, c in ipairs(workspace:GetChildren()) do
	if c:IsA("Model") and string.find(string.lower(c.Name), "pls") then
		root = c
	end
end
if not root then
	warn("Pls adli harita modeli bulunamadi")
	return
end
local counts, order = {}, {}
for _, c in ipairs(root:GetChildren()) do
	local key = c.Name .. " [" .. c.ClassName .. "]"
	if not counts[key] then
		counts[key] = 0
		table.insert(order, key)
	end
	counts[key] = counts[key] + 1
end
table.sort(order)
print("== " .. root:GetFullName() .. ": " .. #root:GetChildren() .. " alt nesne ==")
for _, k in ipairs(order) do
	print(counts[k] .. " x " .. k)
end
local scripts = 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
		scripts = scripts + 1
		print("SCRIPT: " .. d:GetFullName())
	end
end
print("Toplam script: " .. scripts)
local function tree(inst, depth, maxDepth)
	if depth > maxDepth then
		return
	end
	local kids = inst:GetChildren()
	for i, k in ipairs(kids) do
		if i > 12 then
			print(string.rep("  ", depth) .. "... (+" .. (#kids - 12) .. ")")
			break
		end
		print(string.rep("  ", depth) .. k.ClassName .. ": " .. k.Name)
		tree(k, depth + 1, maxDepth)
	end
end
local shown = 0
for _, c in ipairs(root:GetChildren()) do
	local n = string.lower(c.Name)
	if shown < 2 and (string.find(n, "stand") or string.find(n, "booth") or string.find(n, "stall") or string.find(n, "sign") or string.find(n, "shop")) then
		shown = shown + 1
		print("== ORNEK STAND YAPISI: " .. c.Name .. " ==")
		tree(c, 1, 3)
	end
end
if shown == 0 then
	print("Stand benzeri isim bulunamadi; ilk 3 nesnenin yapisi:")
	for i = 1, math.min(3, #root:GetChildren()) do
		local c = root:GetChildren()[i]
		print("== " .. c.Name .. " ==")
		tree(c, 1, 2)
	end
end
