	local function check(cond, msg)
		if not cond then
			error("TEST BASARISIZ: " .. msg, 2)
		end
		print("  ok  " .. msg)
	end
	print("== EggClient (istemci arayuzu) ==")
	local gui = __pg:FindFirstChild("EggGui")
	check(gui ~= nil, "EggGui olustu")
	local function find(class, text)
		for _, c in ipairs(gui:GetDescendants()) do
			if c.ClassName == class and c.Text == text then
				return c
			end
		end
	end
	local openBtn = find("TextButton", "Stand Ayarlari")
	check(openBtn ~= nil and openBtn.Visible == false, "Stand Ayarlari dugmesi var, stand yokken gizli")
	__lp:SetAttribute("HasBooth", true)
	check(openBtn.Visible == true, "standi olunca dugme gorunur")
	__fire(openBtn, "Activated")
	local boxes = {}
	for _, c in ipairs(gui:GetDescendants()) do
		if c.ClassName == "TextBox" then
			table.insert(boxes, c)
		end
	end
	check(#boxes == 1 and boxes[1].PlaceholderText:find("40") ~= nil, "panel acildi: yazi kutusu, yer tutucu 40 karakter diyor")
	local panel = boxes[1].Parent
	local sw = {}
	for _, c in ipairs(panel:GetChildren()) do
		if c.ClassName == "TextButton" and c.Size.XO == 34 then
			table.insert(sw, c)
		end
	end
	check(#sw == 8, "8 renk dugmesi (Config'ten okundu)")
	check(sw[1].BackgroundColor3 == game:GetService("ReplicatedStorage").EggRemotes:GetAttribute("StyleColor1"), "renk dugmesi rengi yayinlanan renkle ayni")
	__fire(sw[3], "Activated")
	check(sw[3].Text == "X" and sw[1].Text == "", "secilen rengin ustunde X")
	boxes[1].Text = "Merhaba"
	__fire(find("TextButton", "Kaydet"), "Activated")
	local sent = rawget(game:GetService("ReplicatedStorage").EggRemotes.SetBoothStyle, "_d").firedServer
	check(sent and sent[1][1].Text == "Merhaba" and sent[1][1].Color == 3, "Kaydet: sunucuya {Text='Merhaba', Color=3} gitti")
	check(find("TextButton", "Kaydet") == nil, "kayit sonrasi panel kapandi")
	__fire(openBtn, "Activated")
	local box2
	for _, c in ipairs(gui:GetDescendants()) do
		if c.ClassName == "TextBox" then box2 = c end
	end
	box2.Text = string.rep("b", 60)
	__fire(find("TextButton", "Kaydet"), "Activated")
	check(#sent[2][1].Text == 40, "60 karakterlik yazi istemcide 40'a kisaltildi")
	__fire(openBtn, "Activated")
	__lp:SetAttribute("HasBooth", nil)
	check(openBtn.Visible == false and find("TextButton", "Kaydet") == nil, "stand birakilinca dugme gizlenir, acik panel kapanir")
	local remotesF = game:GetService("ReplicatedStorage").EggRemotes
	__fire(remotesF.Notify, "OnClientEvent", "Merhaba toast")
	local toastText
	for _, c in ipairs(gui:GetChildren()) do
		if c.ClassName == "TextLabel" then toastText = c.Text end
	end
	check(toastText == "Merhaba toast", "bildirim yazisi ekranda: " .. tostring(toastText))
