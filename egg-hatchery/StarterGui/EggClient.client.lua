local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local remotes = ReplicatedStorage:WaitForChild("EggRemotes")
local gui = Instance.new("ScreenGui")
gui.Name = "EggGui"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Ust bildirim yazisi
local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 20)
toast.Size = UDim2.fromOffset(460, 44)
toast.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.Font = Enum.Font.GothamBold
toast.TextSize = 18
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Parent = gui
Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)

local toastId = 0
local function showToast(text, color)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = color or Color3.new(1, 1, 1)
	toast.BackgroundTransparency = 0.2
	toast.TextTransparency = 0
	task.delay(4, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end

remotes.Notify.OnClientEvent:Connect(showToast)

-- Destek menusu
local menu
local function closeMenu()
	if menu then
		menu:Destroy()
		menu = nil
	end
end

remotes.OpenDonateMenu.OnClientEvent:Connect(function(payload)
	closeMenu()
	menu = Instance.new("Frame")
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.fromScale(0.5, 0.5)
	menu.Size = UDim2.fromOffset(340, 80 + #payload.Passes * 52)
	menu.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	menu.Parent = gui
	Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 12)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = payload.Owner .. " oyuncusunun yumurtasini besle"
	title.Parent = menu

	for i, pass in ipairs(payload.Passes) do
		local btn = Instance.new("TextButton")
		btn.Position = UDim2.new(0.5, 0, 0, 50 + (i - 1) * 52)
		btn.AnchorPoint = Vector2.new(0.5, 0)
		btn.Size = UDim2.new(1, -30, 0, 44)
		btn.BackgroundColor3 = Color3.fromRGB(70, 160, 90)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 17
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Text = string.format("%s  -  R$ %d", pass.Name, pass.Price)
		btn.Parent = menu
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
		btn.Activated:Connect(function()
			remotes.RequestPurchase:FireServer(pass.Id)
			closeMenu()
		end)
	end

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -8)
	close.Size = UDim2.new(1, -30, 0, 22)
	close.BackgroundTransparency = 1
	close.Font = Enum.Font.Gotham
	close.TextSize = 14
	close.TextColor3 = Color3.fromRGB(170, 170, 170)
	close.Text = "Kapat"
	close.Parent = menu
	close.Activated:Connect(closeMenu)
end)

-- Herkese gorunen duyurular
remotes.EggFeedback.OnClientEvent:Connect(function(data)
	if data.Kind == "Donation" then
		showToast(string.format("%s, %s oyuncusunun yumurtasini besledi (+%d XP)", data.Donor, data.Owner, data.XP), Color3.fromRGB(120, 255, 150))
	elseif data.Kind == "Evolve" then
		showToast(string.format("%s oyuncusunun yumurtasi Lv %d oldu [%s]!", data.Owner, data.Level, data.Rarity), data.Color)
	end
end)

-- Stand ayarlari: sahibi mesaj + renk secer (sunucu filtreler ve dogrular)
local player = Players.LocalPlayer
local maxLength = remotes:GetAttribute("StyleMaxLength") or 40
local colorCount = remotes:GetAttribute("StyleColorCount") or 0
local selectedColor = 1
local panel

local openBtn = Instance.new("TextButton")
openBtn.AnchorPoint = Vector2.new(0, 1)
openBtn.Position = UDim2.new(0, 16, 1, -16)
openBtn.Size = UDim2.fromOffset(160, 42)
openBtn.BackgroundColor3 = Color3.fromRGB(70, 160, 90)
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 17
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Text = "Stand Ayarlari"
openBtn.Visible = false
openBtn.Parent = gui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 10)

local function closePanel()
	if panel then
		panel:Destroy()
		panel = nil
	end
end

local function openPanel()
	closePanel()
	selectedColor = player:GetAttribute("BoothColor") or 1
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 270)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 44)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "Stand ayarlarin"
	title.Parent = panel

	local box = Instance.new("TextBox")
	box.Position = UDim2.fromOffset(20, 52)
	box.Size = UDim2.new(1, -40, 0, 44)
	box.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	box.Font = Enum.Font.Gotham
	box.TextSize = 17
	box.TextColor3 = Color3.new(1, 1, 1)
	box.PlaceholderText = "Mesajin (en fazla " .. maxLength .. " karakter)"
	box.PlaceholderColor3 = Color3.fromRGB(150, 150, 160)
	box.ClearTextOnFocus = false
	box.Text = player:GetAttribute("BoothMessage") or ""
	box.Parent = panel
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

	local swatches = {}
	local function paint()
		for i, sw in ipairs(swatches) do
			sw.Text = (i == selectedColor) and "X" or ""
		end
	end
	for i = 1, colorCount do
		local sw = Instance.new("TextButton")
		sw.Position = UDim2.fromOffset(20 + (i - 1) * 40, 112)
		sw.Size = UDim2.fromOffset(34, 34)
		sw.BackgroundColor3 = remotes:GetAttribute("StyleColor" .. i) or Color3.new(1, 1, 1)
		sw.Font = Enum.Font.GothamBlack
		sw.TextSize = 18
		sw.TextColor3 = Color3.fromRGB(20, 20, 20)
		sw.Text = ""
		sw.Parent = panel
		Instance.new("UICorner", sw).CornerRadius = UDim.new(0, 8)
		sw.Activated:Connect(function()
			selectedColor = i
			paint()
		end)
		swatches[i] = sw
	end
	paint()

	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.fromOffset(20, 156)
	hint.Size = UDim2.new(1, -40, 0, 22)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 13
	hint.TextColor3 = Color3.fromRGB(170, 170, 180)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = "Mesajin yumurtanin ustunde herkese gorunur."
	hint.Parent = panel

	local save = Instance.new("TextButton")
	save.AnchorPoint = Vector2.new(0.5, 0)
	save.Position = UDim2.new(0.5, 0, 0, 188)
	save.Size = UDim2.new(1, -40, 0, 40)
	save.BackgroundColor3 = Color3.fromRGB(70, 160, 90)
	save.Font = Enum.Font.GothamBold
	save.TextSize = 17
	save.TextColor3 = Color3.new(1, 1, 1)
	save.Text = "Kaydet"
	save.Parent = panel
	Instance.new("UICorner", save).CornerRadius = UDim.new(0, 8)
	save.Activated:Connect(function()
		local text = box.Text
		if utf8.len(text) and utf8.len(text) > maxLength then
			text = string.sub(text, 1, utf8.offset(text, maxLength + 1) - 1)
		end
		remotes.SetBoothStyle:FireServer({ Text = text, Color = selectedColor })
		closePanel()
	end)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -6)
	close.Size = UDim2.new(1, -40, 0, 22)
	close.BackgroundTransparency = 1
	close.Font = Enum.Font.Gotham
	close.TextSize = 14
	close.TextColor3 = Color3.fromRGB(170, 170, 170)
	close.Text = "Kapat"
	close.Parent = panel
	close.Activated:Connect(closePanel)
end

openBtn.Activated:Connect(openPanel)

local function refreshButton()
	openBtn.Visible = player:GetAttribute("HasBooth") == true
	if not openBtn.Visible then
		closePanel()
	end
end
player:GetAttributeChangedSignal("HasBooth"):Connect(refreshButton)
refreshButton()
