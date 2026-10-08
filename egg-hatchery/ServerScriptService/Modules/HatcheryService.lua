local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Modules = script.Parent
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)
local Registry = require(Modules.BoothRegistry)
local Styler = require(Modules.BoothStyler)
local EggModel = require(Modules.EggModel)

local T = Config.TEXT
local HatcheryService = {}

local RGB = Color3.fromRGB
local DORMANT_COLOR = RGB(190, 186, 178)
local DONATION_COLOR = RGB(255, 210, 70)
local CARD_TOP = RGB(36, 42, 62)
local CARD_BOTTOM = RGB(18, 22, 34)
local MUTED = RGB(160, 168, 186)
local GOLD = RGB(255, 205, 80)

local CLAIMED_W, CLAIMED_H, CLAIMED_H_MSG = 280, 92, 116
local EMPTY_W, EMPTY_H = 210, 52

---------------------------------------------------------------------
-- Stand uzerindeki kart (BillboardGui): avatar, isim, seviye/nadirlik, toplanan Robux, XP cubugu, mesaj
---------------------------------------------------------------------
local function makeLabel(parent, name, font, size, color, x, y, w, h)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(w, h)
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = ""
	label.Parent = parent
	return label
end

local function round(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

local function buildGui(core)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HatcheryGui"
	gui.Size = UDim2.fromOffset(CLAIMED_W, CLAIMED_H)
	gui.StudsOffsetWorldSpace = Vector3.new(0, EggModel.Height + 1.5, 0) -- Refresh yumurta boyuna gore ayarlar
	gui.MaxDistance = 55
	gui.LightInfluence = 0
	gui.Parent = core

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BackgroundTransparency = 0.06
	card.BorderSizePixel = 0
	card.Parent = gui
	round(card, UDim.new(0, 16))
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(CARD_TOP, CARD_BOTTOM)
	gradient.Rotation = 90
	gradient.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 2
	stroke.Color = DORMANT_COLOR
	stroke.Parent = card

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.fromOffset(18, 0)
	accent.Size = UDim2.new(1, -36, 0, 3)
	accent.BackgroundColor3 = DORMANT_COLOR
	accent.BorderSizePixel = 0
	accent.Parent = card
	round(accent, UDim.new(1, 0))

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Position = UDim2.fromOffset(12, 14)
	avatar.Size = UDim2.fromOffset(54, 54)
	avatar.BackgroundColor3 = RGB(46, 52, 74)
	avatar.BorderSizePixel = 0
	avatar.Image = ""
	avatar.Parent = card
	round(avatar, UDim.new(1, 0))
	local avatarStroke = Instance.new("UIStroke")
	avatarStroke.Name = "Ring"
	avatarStroke.Thickness = 2.5
	avatarStroke.Color = DORMANT_COLOR
	avatarStroke.Parent = avatar

	makeLabel(card, "NameLabel", Enum.Font.GothamBold, 19, Color3.new(1, 1, 1), 76, 12, 192, 24)
	makeLabel(card, "LevelLabel", Enum.Font.GothamBold, 14, MUTED, 76, 37, 192, 18)
	makeLabel(card, "RaisedLabel", Enum.Font.GothamMedium, 13, GOLD, 76, 54, 192, 16)

	local back = Instance.new("Frame")
	back.Name = "BarBack"
	back.Position = UDim2.new(0, 14, 0, 76)
	back.Size = UDim2.new(1, -28, 0, 8)
	back.BackgroundColor3 = RGB(46, 52, 74)
	back.BorderSizePixel = 0
	back.Parent = card
	round(back, UDim.new(1, 0))
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = DORMANT_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = back
	round(fill, UDim.new(1, 0))

	local msg = makeLabel(card, "MessageLabel", Enum.Font.GothamMedium, 14, Color3.new(1, 1, 1), 14, 90, CLAIMED_W - 28, 20)
	msg.TextXAlignment = Enum.TextXAlignment.Center
	msg.Visible = false
	return gui
end

-- claimed: dolu stand karti (avatar, istatistik, cubuk); degilse kucuk "Bos Stand" etiketi
local function layoutGui(gui, claimed, hasMessage)
	local card = gui.Card
	card.Avatar.Visible = claimed
	card.RaisedLabel.Visible = claimed
	card.BarBack.Visible = claimed
	card.Accent.Visible = claimed
	card.MessageLabel.Visible = claimed and hasMessage
	local name, level = card.NameLabel, card.LevelLabel
	if claimed then
		gui.Size = UDim2.fromOffset(CLAIMED_W, hasMessage and CLAIMED_H_MSG or CLAIMED_H)
		gui.MaxDistance = 55
		name.Position, name.Size, name.TextXAlignment = UDim2.fromOffset(76, 12), UDim2.fromOffset(192, 24), Enum.TextXAlignment.Left
		level.Position, level.Size, level.TextXAlignment = UDim2.fromOffset(76, 37), UDim2.fromOffset(192, 18), Enum.TextXAlignment.Left
	else
		gui.Size = UDim2.fromOffset(EMPTY_W, EMPTY_H)
		gui.MaxDistance = 32
		name.Position, name.Size, name.TextXAlignment = UDim2.fromOffset(8, 6), UDim2.fromOffset(EMPTY_W - 16, 22), Enum.TextXAlignment.Center
		level.Position, level.Size, level.TextXAlignment = UDim2.fromOffset(8, 28), UDim2.fromOffset(EMPTY_W - 16, 18), Enum.TextXAlignment.Center
	end
end

-- 12500 -> "12.500"
local function formatNumber(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if string.sub(out, 1, 1) == "." then
		out = string.sub(out, 2)
	end
	return out
end

local function guiOf(booth)
	local core = EggModel.Core(booth)
	return core and core:FindFirstChild("HatcheryGui")
end

---------------------------------------------------------------------
-- Stand kurulumu
---------------------------------------------------------------------
function HatcheryService.BuildBooth(booth)
	local base = booth.PrimaryPart or booth:FindFirstChildWhichIsA("BasePart", true)
	assert(base, booth:GetFullName() .. " icinde en az bir Part olmali")
	booth.PrimaryPart = base

	if not (booth:FindFirstChild("Egg") and booth.Egg:IsA("Model")) then
		local F = Styler.Measure(booth)
		assert(F, booth:GetFullName() .. " olculemedi")
		-- yumurta: standin en ust noktasinin biraz uzerinde, on yone (cesme/merkez) donuk
		local anchor = F.frame * CFrame.new(F.xc, F.height + Config.EGG_LIFT, (F.front + F.back) / 2)
		EggModel.Build(booth, anchor)
	end
	local core = EggModel.Core(booth)
	if not core:FindFirstChild("HatcheryGui") then
		buildGui(core)
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

-- Sahibin guncel durumunu karta, yumurtaya, butona ve stand stiline yansitir
function HatcheryService.Refresh(player)
	local booth = Registry.GetBooth(player)
	local levelVal, xpVal = getStats(player)
	if not (booth and levelVal and xpVal) then
		return
	end
	local gui = guiOf(booth)
	if not gui then
		return
	end

	local level, xp = levelVal.Value, xpVal.Value
	local need = Config.XPRequired(level)
	local rarity = Config.GetRarity(level)
	local message = player:GetAttribute("BoothMessage")
	local hasMessage = type(message) == "string" and message ~= ""
	local colorIndex = player:GetAttribute("BoothColor")
	local chosen = colorIndex and Config.STYLE_COLORS[colorIndex]
	local accent = chosen and chosen.Color or rarity.Color
	local raised = player.leaderstats:FindFirstChild("Raised")

	layoutGui(gui, true, hasMessage)
	local card = gui.Card
	card.NameLabel.Text = player.DisplayName
	card.LevelLabel.Text = string.format("Seviye %d  •  %s", level, rarity.Name)
	card.LevelLabel.TextColor3 = rarity.Color
	card.RaisedLabel.Text = string.format("R$ %s toplandı", formatNumber(raised and raised.Value or 0))
	card.Stroke.Color = rarity.Color
	card.Accent.BackgroundColor3 = rarity.Color
	card.Avatar.Ring.Color = rarity.Color
	if card.Avatar:GetAttribute("UserId") ~= player.UserId then
		card.Avatar:SetAttribute("UserId", player.UserId)
		card.Avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId)
	end
	card.BarBack.Fill.BackgroundColor3 = rarity.Color
	TweenService:Create(card.BarBack.Fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1),
	}):Play()
	card.MessageLabel.Text = hasMessage and message or ""
	card.MessageLabel.TextColor3 = accent

	local scale = Config.EggScale(level)
	EggModel.Apply(booth, { Tier = EggModel.TierOf(level), Accent = accent, Scale = scale })
	gui.StudsOffsetWorldSpace = Vector3.new(0, EggModel.Height * scale + 1.5, 0) -- kart yumurtanin ustunde kalsin

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
	local key = style .. ":" .. (colorIndex or 0)
	if booth:GetAttribute("AppliedStyle") ~= key or (style ~= "classic" and not booth:FindFirstChild("StyleDecor")) then
		Styler.Apply(booth, style, colorIndex or 1)
		booth:SetAttribute("AppliedStyle", key)
	end
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

	local gui = guiOf(booth)
	layoutGui(gui, false, false)
	local card = gui.Card
	card.NameLabel.Text = T.Unclaimed
	card.LevelLabel.Text = T.ClaimHint
	card.LevelLabel.TextColor3 = MUTED
	card.Stroke.Color = RGB(110, 118, 140)
	card.BarBack.Fill.Size = UDim2.fromScale(0, 1)
	card.MessageLabel.Text = ""
	card.RaisedLabel.Text = ""
	card.Avatar.Image = ""
	card.Avatar:SetAttribute("UserId", nil)
	Styler.Clear(booth)
	booth:SetAttribute("AppliedStyle", nil)
	EggModel.Apply(booth, { Tier = 0, Accent = DORMANT_COLOR, Scale = 0.8, Instant = true })
	gui.StudsOffsetWorldSpace = Vector3.new(0, EggModel.Height * 0.8 + 1.2, 0)
end

---------------------------------------------------------------------
-- Efektler
---------------------------------------------------------------------
local function flashHeart(booth, color, peak, rest)
	local heart = EggModel.Heart(booth)
	local glow = heart and heart:FindFirstChild("Glow")
	if glow then
		glow.Color = color
		glow.Brightness = peak
		TweenService:Create(glow, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = rest }):Play()
	end
end

function HatcheryService.BurstParticles(booth, rarity)
	local heart = EggModel.Heart(booth)
	if not heart then
		return
	end
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
	emitter.Parent = heart
	emitter:Emit(rarity.BurstCount)
	Debris:AddItem(emitter, 3)
	flashHeart(booth, rarity.Color, 6, (rarity.AuraRate or 0) > 0 and 0.7 or 0)
end

-- Bagis geldiginde standda altin renkli kutlama (sahibin standi)
function HatcheryService.DonationEffect(owner)
	local booth = Registry.GetBooth(owner)
	local heart = booth and EggModel.Heart(booth)
	if not heart then
		return
	end
	EggModel.Pulse(booth, DONATION_COLOR, 11)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(DONATION_COLOR, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Speed = NumberRange.new(8, 18)
	emitter.Acceleration = Vector3.new(0, -14, 0)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Rate = 0
	emitter.Parent = heart
	emitter:Emit(45)
	Debris:AddItem(emitter, 3)
	flashHeart(booth, DONATION_COLOR, 5, EggModel.TierOf(owner.leaderstats.Level.Value) >= 2 and 0.7 or 0)
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

	if booth and EggModel.Heart(booth) then
		EggModel.Pulse(booth, newRarity.Color, 9)
		HatcheryService.BurstParticles(booth, newRarity)
		if rarityUp then
			-- evrim: kabuk beyaza doner, zeminde ikinci buyuk dalga
			EggModel.Flash(booth, 0.35)
			task.delay(0.35, function()
				if booth.Parent and Registry.GetBooth(player) == booth then
					EggModel.Pulse(booth, newRarity.Color, 16)
					HatcheryService.BurstParticles(booth, newRarity)
				end
			end)
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
