-- ADIM 6/6: ISIK (Technology'yi elle ShadowMap yap: Explorer > Lighting > Properties > Technology)
local L = game:GetService("Lighting")
local c = Color3.fromRGB
for _, x in ipairs(L:GetChildren()) do
	if x:IsA("PostEffect") or x:IsA("Atmosphere") or x:IsA("Sky") or x:IsA("Clouds") then
		x:Destroy()
	end
end
L.ClockTime = 14
L.GeographicLatitude = 20
L.Brightness = 3
L.ExposureCompensation = 0
L.Ambient = c(120, 124, 132)
L.OutdoorAmbient = c(150, 160, 175)
L.EnvironmentDiffuseScale = 1
L.EnvironmentSpecularScale = 1
L.GlobalShadows = true
L.ShadowSoftness = 0.3
local a = Instance.new("Atmosphere")
a.Density = 0.25
a.Offset = 0.15
a.Color = c(199, 225, 255)
a.Decay = c(255, 232, 205)
a.Glare = 0
a.Haze = 0.8
a.Parent = L
local cc = Instance.new("ColorCorrectionEffect")
cc.Brightness = 0.02
cc.Contrast = 0.1
cc.Saturation = 0.2
cc.TintColor = c(255, 250, 240)
cc.Parent = L
local b = Instance.new("BloomEffect")
b.Intensity = 0.15
b.Size = 24
b.Threshold = 1.8
b.Parent = L
local s = Instance.new("SunRaysEffect")
s.Intensity = 0.05
s.Spread = 0.8
s.Parent = L
local sky = Instance.new("Sky")
sky.Parent = L
print("[Adim 6] Isik hazir. Lighting > Technology'yi ShadowMap yap.")
