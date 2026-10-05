local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Modules = script.Parent
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)
local Registry = require(Modules.BoothRegistry)
local Styler = require(Modules.BoothStyler)

local T = Config.TEXT
local HatcheryService = {}

local DEFAULT_COLOR = Config.RARITIES[1].Color
local CARD_BG = Color3.fromRGB(22, 26, 38)

---------------------------------------------------------------------
-- Stand uzerindeki kart (BillboardGui): isim, seviye/nadirlik, XP cubugu, mesaj
---------------------------------------------------------------------
local function makeLabel(parent, name, font, size, pos, dim)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = dim
	label.Font = font
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

local function buildGui(egg)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HatcheryGui"
	gui.Size = UDim2.fromOffset(280, 76)
	gui.StudsOffset = Vector3.new(0, 3.4, 0) -- ApplyGrowth yumurta boyuna gore ayarlar
	gui.MaxDistance = 60
	gui.Parent = egg

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = CARD_BG
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.Parent = gui
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 2
	stroke.Color = DEFAULT_COLOR
	stroke.Parent = card

	local name = makeLabel(card, "NameLabel", Enum.Font.GothamBold, 20, UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 26))
	name.TextStrokeTransparency = 1
	makeLabel(card, "LevelLabel", Enum.Font.GothamBold, 15, UDim2.fromOffset(12, 32), UDim2.new(1, -24, 0, 20))

	local back = Instance.new("Frame")
	back.Name = "BarBack"
	back.Position = UDim2.new(0, 14, 0, 58)
	back.Size = UDim2.new(1, -28, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(52, 58, 78)
	back.BorderSizePixel = 0
	back.Parent = card
	Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = DEFAULT_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local msg = makeLabel(card, "MessageLabel", Enum.Font.Gotham, 15, UDim2.fromOffset(12, 72), UDim2.new(1, -24, 0, 22))
	msg.Visible = false
	return gui
end

-- mode: "unclaimed" | "claimed"
local function layoutGui(gui, claimed, hasMessage)
	local card = gui.Card
	card.BarBack.Visible = claimed
	card.LevelLabel.Visible = true
	card.MessageLabel.Visible = claimed and hasMessage
	if not claimed then
		gui.Size = UDim2.fromOffset(240, 62)
		card.NameLabel.Position = UDim2.fromOffset(12, 6)
		card.LevelLabel.Position = UDim2.fromOffset(12, 32)
	else
		gui.Size = UDim2.fromOffset(280, hasMessage and 100 or 76)
	end
end

function HatcheryService.BuildBooth(booth)
	local base = booth.PrimaryPart or booth:FindFirstChildWhichIsA("BasePart", true)
	assert(base, booth:GetFullName() .. " icinde en az bir Part olmali")
	booth.PrimaryPart = base

	local egg = booth:FindFirstChild("Egg")
	if not egg then
		egg = Instance.new("Part")
		egg.Name = "Egg"
		egg.Shape = Enum.PartType.Ball
		egg.Size = Vector3.new(3, 4, 3)
		egg.Material = Enum.Material.Neon
		egg.CFrame = base.CFrame * CFrame.new(0, base.Size.Y / 2 + 3, 0)
		egg.Parent = booth
	end
	egg.Anchored = true
	egg.CanCollide = false
	egg.Color = DEFAULT_COLOR
	if egg:GetAttribute("BaseSize") == nil then
		egg:SetAttribute("BaseSize", egg.Size) -- 1. seviye boyutu; buyume buna gore hesaplanir
	end

	if not egg:FindFirstChild("Glow") then
		local glow = Instance.new("PointLight")
		glow.Name = "Glow"
		glow.Range = 14
		glow.Brightness = 0
		glow.Color = DEFAULT_COLOR
		glow.Shadows = false
		glow.Parent = egg
	end
	if not egg:FindFirstChild("Aura") then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "Aura"
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.LightEmission = 1
		aura.Lifetime = NumberRange.new(1.2, 2)
		aura.Speed = NumberRange.new(1, 3)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		aura.Rate = 0
		aura.Enabled = false
		aura.Parent = egg
	end
	if not egg:FindFirstChild("HatcheryGui") then
		buildGui(egg)
	end

	-- Tek etkilesim butonu: bos standda "Standi Al", doluysa "Standa Bak" (panel acar)
	local prompt = base:FindFirstChild("BoothPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BoothPrompt"
		prompt.Parent = base
	end
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true

	HatcheryService.SetUnclaimed(booth)
	return prompt
end

local function getStats(player)
	local ls = player:FindFirstChild("leaderstats")
	local data = player:FindFirstChild("EggData")
	if not (ls and data) then
		return nil, nil
	end
	return ls:FindFirstChild("Level"), data:FindFirstChild("EggXP")
end

-- Yumurta seviye ile buyur; nadirlige gore parlar (Nadir+ surekli kivilcim)
function HatcheryService.ApplyGrowth(egg, level, rarity)
	local base = egg:GetAttribute("BaseSize")
	if base then
		local scale = Config.EggScale(level)
		TweenService:Create(egg, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = base * scale,
		}):Play()
		local gui = egg:FindFirstChild("HatcheryGui")
		if gui then
			gui.StudsOffset = Vector3.new(0, base.Y * scale / 2 + 2.6, 0) -- kart yumurtanin ustunde kalsin
		end
	end
	local aura = egg:FindFirstChild("Aura")
	if aura then
		aura.Color = ColorSequence.new(rarity.Color, Color3.new(1, 1, 1))
		aura.Rate = rarity.AuraRate or 0
		aura.Enabled = (rarity.AuraRate or 0) > 0
	end
	local glow = egg:FindFirstChild("Glow")
	if glow then
		glow.Color = rarity.Color
		glow.Brightness = (rarity.AuraRate or 0) > 0 and 0.6 or 0
	end
end

-- Sahibin guncel durumunu karta, yumurtaya, butona ve stand stiline yansitir
function HatcheryService.Refresh(player)
	local booth = Registry.GetBooth(player)
	local levelVal, xpVal = getStats(player)
	if not (booth and levelVal and xpVal) then
		return
	end
	local egg = booth:FindFirstChild("Egg")
	local gui = egg and egg:FindFirstChild("HatcheryGui")
	if not (egg and gui) then
		return
	end

	local level, xp = levelVal.Value, xpVal.Value
	local need = Config.XPRequired(level)
	local rarity = Config.GetRarity(level)
	local message = player:GetAttribute("BoothMessage")
	local hasMessage = type(message) == "string" and message ~= ""
	local colorIndex = player:GetAttribute("BoothColor") or 1
	local accent = (Config.STYLE_COLORS[colorIndex] or Config.STYLE_COLORS[1]).Color

	layoutGui(gui, true, hasMessage)
	local card = gui.Card
	card.NameLabel.Text = player.DisplayName
	card.LevelLabel.Text = string.format("Seviye %d  •  %s", level, rarity.Name)
	card.LevelLabel.TextColor3 = rarity.Color
	card.Stroke.Color = rarity.Color
	card.BarBack.Fill.BackgroundColor3 = rarity.Color
	TweenService:Create(card.BarBack.Fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1),
	}):Play()
	card.MessageLabel.Text = hasMessage and message or ""
	card.MessageLabel.TextColor3 = accent
	egg.Color = rarity.Color

	local prompt = booth.PrimaryPart:FindFirstChild("BoothPrompt")
	if prompt then
		prompt.ActionText = T.PromptView
		prompt.ObjectText = player.DisplayName
	end

	-- stil: sadece degistiyse yeniden kur
	local style = player:GetAttribute("BoothStyle") or "classic"
	if not Config.IsStyleUnlocked(style, level) then
		style = "classic"
	end
	local key = style .. ":" .. colorIndex
	if booth:GetAttribute("AppliedStyle") ~= key or (style ~= "classic" and not booth:FindFirstChild("StyleDecor")) then
		Styler.Apply(booth, style, colorIndex)
		booth:SetAttribute("AppliedStyle", key)
	end

	HatcheryService.ApplyGrowth(egg, level, rarity)
end

function HatcheryService.SetClaimed(booth, player)
	HatcheryService.Refresh(player)
end

function HatcheryService.SetUnclaimed(booth)
	local base = booth.PrimaryPart
	local prompt = base:FindFirstChild("BoothPrompt")
	if prompt then
		prompt.ActionText = T.PromptClaim
		prompt.ObjectText = T.PromptObject
	end

	local egg = booth:FindFirstChild("Egg")
	local gui = egg.HatcheryGui
	layoutGui(gui, false, false)
	local card = gui.Card
	card.NameLabel.Text = T.Unclaimed
	card.LevelLabel.Text = T.ClaimHint
	card.LevelLabel.TextColor3 = Color3.fromRGB(170, 176, 190)
	card.Stroke.Color = Color3.fromRGB(110, 118, 140)
	card.BarBack.Fill.Size = UDim2.fromScale(0, 1)
	card.BarBack.Fill.BackgroundColor3 = DEFAULT_COLOR
	card.MessageLabel.Text = ""
	egg.Color = DEFAULT_COLOR
	Styler.Clear(booth)
	booth:SetAttribute("AppliedStyle", nil)
	HatcheryService.ApplyGrowth(egg, 1, Config.RARITIES[1])
end

function HatcheryService.BurstParticles(egg, rarity)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(rarity.Color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(15, 35)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Rate = 0
	emitter.Parent = egg
	emitter:Emit(rarity.BurstCount)
	Debris:AddItem(emitter, 3)

	-- kisa isik patlamasi
	local glow = egg:FindFirstChild("Glow")
	if glow then
		glow.Color = rarity.Color
		glow.Brightness = 6
		TweenService:Create(glow, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Brightness = (rarity.AuraRate or 0) > 0 and 0.6 or 0,
		}):Play()
	end
end

function HatcheryService.AddXP(player, amount)
	if not player:GetAttribute("DataLoaded") then
		return
	end
	local levelVal, xpVal = getStats(player)
	if not (levelVal and xpVal) or amount <= 0 then
		return
	end

	local startLevel = levelVal.Value
	xpVal.Value += math.floor(amount)

	while levelVal.Value < Config.MAX_LEVEL do
		local need = Config.XPRequired(levelVal.Value)
		if xpVal.Value < need then
			break
		end
		xpVal.Value -= need
		levelVal.Value += 1
	end
	if levelVal.Value >= Config.MAX_LEVEL then
		xpVal.Value = math.min(xpVal.Value, Config.XPRequired(Config.MAX_LEVEL) - 1)
	end

	HatcheryService.Refresh(player)

	if levelVal.Value > startLevel then
		HatcheryService.OnLevelUp(player, startLevel, levelVal.Value)
	end
end

function HatcheryService.OnLevelUp(player, oldLevel, newLevel)
	local booth = Registry.GetBooth(player)
	local oldRarity, newRarity = Config.GetRarity(oldLevel), Config.GetRarity(newLevel)
	local rarityUp = newRarity ~= oldRarity

	if booth then
		local egg = booth:FindFirstChild("Egg")
		if egg then
			HatcheryService.BurstParticles(egg, newRarity)
			if rarityUp then
				task.delay(0.35, function()
					if egg.Parent then
						HatcheryService.BurstParticles(egg, newRarity)
					end
				end)
			end
		end
	end

	-- herkese: seviye atladi
	Remotes.EggFeedback:FireAllClients({
		Kind = "Evolve",
		Owner = player.DisplayName,
		Level = newLevel,
		Rarity = newRarity.Name,
		RarityUp = rarityUp,
		Color = newRarity.Color,
	})
	-- sadece sahibe: yeni acilan stiller
	local unlocked = Config.NewUnlocks(oldLevel, newLevel)
	if #unlocked > 0 then
		local names = {}
		for _, s in ipairs(unlocked) do
			table.insert(names, s.Name)
		end
		Remotes.EggFeedback:FireClient(player, { Kind = "Unlock", Styles = names, Level = newLevel })
	end
end

return HatcheryService
