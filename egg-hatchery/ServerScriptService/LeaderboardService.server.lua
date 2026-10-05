-- ServerScriptService/LeaderboardService (Script)
--
-- Haritadaki panolara kucuk bir "ilk 10" tablosu cizer.
-- Pano = Workspace'te herhangi bir yerde, adi Board_Raised / Board_Donated / Board_Level olan Part
--        (ya da "LeaderboardBoard" etiketi + "Stat" attribute'u olan Part).
-- Veri EconomyManager'in yazdigi OrderedDataStore'lardan okunur; her Config.LEADERBOARD_REFRESH sn'de yenilenir.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")

local Modules = script.Parent:WaitForChild("Modules")
local Config = require(Modules.Config)

local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Oyuncu" .. userId)
	return nameCache[userId]
end

-- panoyu bul: ad veya etiket ile
local function statOf(part)
	for stat in pairs(Config.LEADERBOARDS) do
		if part.Name == "Board_" .. stat then
			return stat
		end
	end
	if CollectionService:HasTag(part, "LeaderboardBoard") then
		local s = part:GetAttribute("Stat")
		if Config.LEADERBOARDS[s] then
			return s
		end
	end
	return nil
end

local function makeGui(part, stat)
	local old = part:FindFirstChild("LB")
	if old then
		old:Destroy()
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "LB"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = part

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(34, 40, 52)
	bg.BorderSizePixel = 0
	bg.Parent = sg

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.14)
	title.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	title.BorderSizePixel = 0
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(50, 36, 20)
	title.Text = Config.LEADERBOARDS[stat].Title
	title.Parent = bg

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.fromScale(0.05, 0.17)
	body.Size = UDim2.fromScale(0.9, 0.8)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamBold
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextScaled = true
	body.TextColor3 = Color3.fromRGB(240, 244, 250)
	body.Text = "Yukleniyor..."
	body.Parent = bg
	return body
end

local function format(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local boards = {} -- [part] = { stat, body }

local function register(part)
	if boards[part] or not part:IsA("BasePart") then
		return
	end
	local stat = statOf(part)
	if stat then
		boards[part] = { stat = stat, body = makeGui(part, stat) }
	end
end

for _, d in ipairs(Workspace:GetDescendants()) do
	register(d)
end
Workspace.DescendantAdded:Connect(register)

local function refresh()
	local cache = {} -- ayni stat icin tek okuma
	for part, b in pairs(boards) do
		if not part.Parent then
			boards[part] = nil
		else
			if not cache[b.stat] then
				local ok, page = pcall(function()
					return DataStoreService:GetOrderedDataStore(Config.LEADERBOARDS[b.stat].Store):GetSortedAsync(false, Config.LEADERBOARD_SIZE):GetCurrentPage()
				end)
				cache[b.stat] = ok and page or false
			end
			local page = cache[b.stat]
			if page == false then
				-- hata: eski yaziyi birak (bos kalmasin)
			elseif #page == 0 then
				b.body.Text = "Henuz kimse yok"
			else
				local lines = {}
				for i, entry in ipairs(page) do
					table.insert(lines, string.format("%d. %s  -  %s", i, nameOf(tonumber(entry.key) or 0), format(entry.value)))
				end
				b.body.Text = table.concat(lines, "\n")
			end
		end
	end
end

task.spawn(function()
	while true do
		refresh()
		task.wait(Config.LEADERBOARD_REFRESH)
	end
end)
