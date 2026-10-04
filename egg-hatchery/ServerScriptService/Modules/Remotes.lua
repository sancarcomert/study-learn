-- ServerScriptService/Modules/Remotes  (ModuleScript)
-- Creates ReplicatedStorage.EggRemotes once and returns the events.
-- RequestPurchase is the ONLY client -> server event; XP is never client-authoritative.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("EggRemotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "EggRemotes"
	folder.Parent = ReplicatedStorage
end

local function remote(name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end
	local ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = folder
	return ev
end

return {
	Notify = remote("Notify"),                   -- S->C  (text: string)
	OpenDonateMenu = remote("OpenDonateMenu"),   -- S->C  ({Owner, Passes})
	RequestPurchase = remote("RequestPurchase"), -- C->S  (passId: number)
	EggFeedback = remote("EggFeedback"),         -- S->all C (donation / evolution broadcasts)
}
