local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("EggRemotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "EggRemotes"
	folder.Parent = ReplicatedStorage
end

local function remote(name)
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = folder
	return ev
end

return {
	Notify = remote("Notify"),
	OpenDonateMenu = remote("OpenDonateMenu"),
	RequestPurchase = remote("RequestPurchase"),
	EggFeedback = remote("EggFeedback"),
}
