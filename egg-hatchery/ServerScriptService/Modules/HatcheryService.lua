local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Modules = script.Parent
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)
local Registry = require(Modules.BoothRegistry)

local HatcheryService = {}

local DEFAULT_COLOR = Config.RARITIES[1].Color

local function makePrompt(parent, name, action, enabled)
	local prompt = parent:FindFirstChild(name)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.Parent = parent
	end
	prompt.ActionText = action
	prompt.ObjectText = "Mystic Hatchery"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = enabled
	return prompt
end

-- sahipsiz stand: tek satir; sahipli stand: baslik + XP cubugu + ilerleme
local function layoutGui(gui, claimed)
	gui.BarBack.Visible = claimed
	gui.Progress.Visible = claimed
	gui.Title.Size = claimed and UDim2.fromScale(1, 0.45) or UDim2.fromScale(1, 0.6)
	gui.Title.Position = claimed and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 0.2)
end

local function makeLabel(parent, name, pos, size)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = parent
	return label
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

	if not egg:FindFirstChild("HatcheryGui") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "HatcheryGui"
		gui.Size = UDim2.fromOffset(260, 66)
		gui.StudsOffset = Vector3.new(0, 3.4, 0)
		gui.MaxDistance = 45 -- uzaktan 24 yazi ust uste binmesin
		gui.Parent = egg

		makeLabel(gui, "Title", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.45))

		local back = Instance.new("Frame")
		back.Name = "BarBack"
		back.Position = UDim2.fromScale(0.05, 0.52)
		back.Size = UDim2.fromScale(0.9, 0.2)
		back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		back.BorderSizePixel = 0
		back.Parent = gui
		Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = DEFAULT_COLOR
		fill.BorderSizePixel = 0
		fill.Parent = back
		Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

		makeLabel(gui, "Progress", UDim2.fromScale(0, 0.76), UDim2.fromScale(1, 0.24))
	end

	local claim = makePrompt(base, "ClaimPrompt", "Claim Booth", true)
	local donate = makePrompt(base, "DonatePrompt", "Support Egg", false)
	CollectionService:AddTag(donate, "DonatePrompt")

	HatcheryService.SetUnclaimed(booth)
	return claim, donate
end

local function getStats(player)
	local ls = player:FindFirstChild("leaderstats")
	local data = player:FindFirstChild("EggData")
	if not (ls and data) then
		return nil, nil
	end
	return ls:FindFirstChild("EggLevel"), data:FindFirstChild("EggXP")
end

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

	layoutGui(gui, true)
	gui.Title.Text = string.format("%s's Hatchery - Level %d", player.Name, level)
	gui.Progress.Text = string.format("%s  |  %d / %d XP", rarity.Name, xp, need)
	gui.BarBack.Fill.BackgroundColor3 = rarity.Color
	TweenService:Create(gui.BarBack.Fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1),
	}):Play()
	egg.Color = rarity.Color
end

function HatcheryService.SetClaimed(booth, player)
	local base = booth.PrimaryPart
	base.ClaimPrompt.Enabled = false
	base.DonatePrompt.Enabled = true
	HatcheryService.Refresh(player)
end

function HatcheryService.SetUnclaimed(booth)
	local base = booth.PrimaryPart
	base.ClaimPrompt.Enabled = true
	base.DonatePrompt.Enabled = false

	local egg = booth:FindFirstChild("Egg")
	local gui = egg.HatcheryGui
	layoutGui(gui, false)
	gui.Title.Text = "Unclaimed - Press E to claim!"
	gui.Progress.Text = ""
	gui.BarBack.Fill.Size = UDim2.fromScale(0, 1)
	gui.BarBack.Fill.BackgroundColor3 = DEFAULT_COLOR
	egg.Color = DEFAULT_COLOR
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

	local original = egg.Size
	TweenService:Create(egg, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true), {
		Size = original * 1.35,
	}):Play()
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
		HatcheryService.OnEvolve(player, startLevel, levelVal.Value)
	end
end

function HatcheryService.OnEvolve(player, oldLevel, newLevel)
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

	Remotes.EggFeedback:FireAllClients({
		Kind = "Evolve",
		Owner = player.Name,
		Level = newLevel,
		Rarity = newRarity.Name,
		RarityUp = rarityUp,
		Color = newRarity.Color,
	})
end

return HatcheryService
