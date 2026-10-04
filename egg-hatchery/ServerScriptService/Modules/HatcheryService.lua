-- ServerScriptService/Modules/HatcheryService  (ModuleScript)
-- Egg XP, evolution logic and all booth visuals (billboard, progress bar, particles).

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Modules = script.Parent
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)
local Registry = require(Modules.BoothRegistry)

local HatcheryService = {}

local DEFAULT_COLOR = Config.RARITIES[1].Color

---------------------------------------------------------------------
-- Booth construction (auto-builds anything missing so any Model works)
---------------------------------------------------------------------

local function makePrompt(parent: BasePart, name: string, action: string, enabled: boolean): ProximityPrompt
	local prompt = parent:FindFirstChild(name) :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.Parent = parent
	end
	prompt = prompt :: ProximityPrompt
	prompt.ActionText = action
	prompt.ObjectText = "Mystic Hatchery"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = enabled
	return prompt
end

local function makeLabel(parent: Instance, name: string, pos: UDim2, size: UDim2): TextLabel
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

-- Ensures Base, Egg, billboard and both prompts exist. Returns (claimPrompt, donatePrompt).
function HatcheryService.BuildBooth(booth: Model): (ProximityPrompt, ProximityPrompt)
	local base = booth.PrimaryPart or booth:FindFirstChildWhichIsA("BasePart", true)
	assert(base, booth:GetFullName() .. " needs at least one BasePart")
	booth.PrimaryPart = base

	-- Egg: use your own part/MeshPart named "Egg", otherwise a neon ellipsoid is generated.
	local egg = booth:FindFirstChild("Egg") :: BasePart?
	if not egg then
		egg = Instance.new("Part")
		egg.Name = "Egg"
		egg.Shape = Enum.PartType.Ball
		egg.Size = Vector3.new(3, 4, 3)
		egg.Material = Enum.Material.Neon
		egg.CFrame = base.CFrame * CFrame.new(0, base.Size.Y / 2 + 3, 0)
		egg.Parent = booth
	end
	egg = egg :: BasePart
	egg.Anchored = true
	egg.CanCollide = false
	egg.Color = DEFAULT_COLOR

	-- Billboard: title + progress bar + progress text, all parented to the egg.
	if not egg:FindFirstChild("HatcheryGui") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "HatcheryGui"
		gui.Size = UDim2.fromOffset(340, 90)
		gui.StudsOffset = Vector3.new(0, 4.5, 0)
		gui.MaxDistance = 120
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
	local donate = makePrompt(base, "DonatePrompt", "Donate to Egg", false)
	CollectionService:AddTag(donate, "DonatePrompt") -- MarketplaceHook discovers prompts by tag

	HatcheryService.SetUnclaimed(booth)
	return claim, donate
end

---------------------------------------------------------------------
-- Visual refresh
---------------------------------------------------------------------

local function getStats(player: Player): (IntValue?, IntValue?)
	local ls = player:FindFirstChild("leaderstats")
	local data = player:FindFirstChild("EggData")
	if not (ls and data) then
		return nil, nil
	end
	return ls:FindFirstChild("EggLevel") :: IntValue?, data:FindFirstChild("EggXP") :: IntValue?
end

-- Redraws title, bar, progress text and egg colour for the booth owned by `player`.
function HatcheryService.Refresh(player: Player)
	local booth = Registry.GetBooth(player)
	local levelVal, xpVal = getStats(player)
	if not (booth and levelVal and xpVal) then
		return
	end
	local egg = booth:FindFirstChild("Egg") :: BasePart?
	local gui = egg and egg:FindFirstChild("HatcheryGui")
	if not (egg and gui) then
		return
	end

	local level, xp = levelVal.Value, xpVal.Value
	local need = Config.XPRequired(level)
	local rarity = Config.GetRarity(level)

	gui.Title.Text = string.format("%s's Hatchery - Level %d", player.Name, level)
	gui.Progress.Text = string.format("%s  |  %d / %d XP", rarity.Name, xp, need)
	gui.BarBack.Fill.BackgroundColor3 = rarity.Color
	TweenService:Create(gui.BarBack.Fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1),
	}):Play()
	egg.Color = rarity.Color
end

function HatcheryService.SetClaimed(booth: Model, player: Player)
	local base = booth.PrimaryPart :: BasePart
	base.ClaimPrompt.Enabled = false
	base.DonatePrompt.Enabled = true
	HatcheryService.Refresh(player)
end

function HatcheryService.SetUnclaimed(booth: Model)
	local base = booth.PrimaryPart :: BasePart
	base.ClaimPrompt.Enabled = true
	base.DonatePrompt.Enabled = false

	local egg = booth:FindFirstChild("Egg") :: BasePart
	local gui = egg.HatcheryGui
	gui.Title.Text = "Unclaimed - Press E to claim!"
	gui.Progress.Text = ""
	gui.BarBack.Fill.Size = UDim2.fromScale(0, 1)
	gui.BarBack.Fill.BackgroundColor3 = DEFAULT_COLOR
	egg.Color = DEFAULT_COLOR
end

---------------------------------------------------------------------
-- Particle burst
---------------------------------------------------------------------

-- Creates a temporary ParticleEmitter on the egg, fires one burst, then cleans up.
function HatcheryService.BurstParticles(egg: BasePart, rarity: { Name: string, Color: Color3, BurstCount: number })
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
	emitter.Rate = 0 -- burst only
	emitter.Parent = egg
	emitter:Emit(rarity.BurstCount)
	Debris:AddItem(emitter, 3)

	-- Egg "pop" so the evolution reads from across the map.
	local original = egg.Size
	TweenService:Create(egg, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true), {
		Size = original * 1.35,
	}):Play()
end

---------------------------------------------------------------------
-- XP + evolution
---------------------------------------------------------------------

-- Awards XP to `player`'s egg, evolving it as many times as the XP allows.
function HatcheryService.AddXP(player: Player, amount: number)
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

-- Fired whenever the egg gains one or more levels.
function HatcheryService.OnEvolve(player: Player, oldLevel: number, newLevel: number)
	local booth = Registry.GetBooth(player)
	local oldRarity, newRarity = Config.GetRarity(oldLevel), Config.GetRarity(newLevel)
	local rarityUp = newRarity ~= oldRarity

	if booth then
		local egg = booth:FindFirstChild("Egg") :: BasePart?
		if egg then
			HatcheryService.BurstParticles(egg, newRarity)
			if rarityUp then -- double burst for a rarity tier-up
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
