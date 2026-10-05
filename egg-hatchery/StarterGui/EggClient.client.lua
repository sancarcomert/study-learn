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
