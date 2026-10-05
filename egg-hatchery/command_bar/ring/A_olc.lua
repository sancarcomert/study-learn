-- ADIM A: HARITAYI OLC. Once Explorer'da meydanin gri halka zeminine (veya tum meydan modeline) tikla, sonra bunu yapistir.
local sel = game:GetService("Selection"):Get()[1]
if not sel then
	warn("Once Explorer'dan meydanin gri halka zeminini sec, sonra tekrar Enter.")
	return
end
local cf, size
if sel:IsA("BasePart") then
	cf, size = sel.CFrame, sel.Size
elseif sel:IsA("Model") then
	cf, size = sel:GetBoundingBox()
else
	warn("Secili sey bir Part veya Model olmali: " .. sel.ClassName)
	return
end
local p = cf.Position
local params = RaycastParams.new()
local hit = workspace:Raycast(Vector3.new(p.X, p.Y + 300, p.Z), Vector3.new(0, -600, 0), params)
print("== OLCUM: " .. sel:GetFullName() .. " ==")
print(string.format("Merkez: %.1f, %.1f, %.1f", p.X, p.Y, p.Z))
print(string.format("Boyut: %.1f x %.1f x %.1f", size.X, size.Y, size.Z))
print(string.format("Ust yuz yuksekligi (Y): %.2f", p.Y + size.Y / 2))
if hit then
	print(string.format("Merkezin altindaki zemin (Y): %.2f  [%s]", hit.Position.Y, hit.Instance:GetFullName()))
end
print(string.format("Dis yaricap ~ %.1f stud", math.min(size.X, size.Z) / 2))
local n = 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("LuaSourceContainer") then
		n = n + 1
		print("SCRIPT: " .. d:GetFullName())
	end
end
local ss = game:GetService("ServerScriptService")
for _, d in ipairs(ss:GetDescendants()) do
	if d:IsA("LuaSourceContainer") then
		n = n + 1
		print("SCRIPT: " .. d:GetFullName())
	end
end
print("Toplam script: " .. n .. " (haritada 0 olmasi gerekir; varsa ekran goruntusu at, silme)")
local names = {}
for _, c in ipairs(sel:GetChildren()) do
	table.insert(names, c.Name)
end
print("Alt nesneler: " .. table.concat(names, ", "))
