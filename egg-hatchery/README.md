# Egg Hatchery (Roblox)

| File | Studio location | Type |
|---|---|---|
| ServerScriptService/Modules/Config.lua | ServerScriptService > Modules > Config | ModuleScript |
| ServerScriptService/Modules/Remotes.lua | ServerScriptService > Modules > Remotes | ModuleScript |
| ServerScriptService/Modules/BoothRegistry.lua | ServerScriptService > Modules > BoothRegistry | ModuleScript |
| ServerScriptService/Modules/HatcheryService.lua | ServerScriptService > Modules > HatcheryService | ModuleScript |
| ServerScriptService/EconomyManager.server.lua | ServerScriptService > EconomyManager | Script |
| ServerScriptService/BoothManager.server.lua | ServerScriptService > BoothManager | Script |
| ServerScriptService/MarketplaceHook.server.lua | ServerScriptService > MarketplaceHook | Script |
| StarterGui/EggClient.client.lua | StarterGui > EggClient | LocalScript |

Setup: create `Workspace > Booths` (Folder) containing one Model per booth (any BasePart inside),
enable Studio API access for DataStores, and put your real gamepass Ids in `Config.GAMEPASSES`.
