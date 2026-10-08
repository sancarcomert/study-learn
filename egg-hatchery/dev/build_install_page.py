#!/usr/bin/env python3
"""dev/build_install_page.py : tum scriptleri tek HTML sayfasinda toplar (her dosya icin Kopyala dugmesi).
Kullanim: build_install_page.py cikti.html"""
import json
import sys

ROOT = __file__.rsplit("/", 2)[0]
M = "ModuleScript"
FILES = [
    ("Config", "ServerScriptService/Modules/Config.lua", "ServerScriptService → Modules (klasör)", M),
    ("Remotes", "ServerScriptService/Modules/Remotes.lua", "ServerScriptService → Modules", M),
    ("BoothRegistry", "ServerScriptService/Modules/BoothRegistry.lua", "ServerScriptService → Modules", M),
    ("Products", "ServerScriptService/Modules/Products.lua", "ServerScriptService → Modules", M),
    ("BoothStyler", "ServerScriptService/Modules/BoothStyler.lua", "ServerScriptService → Modules", M),
    ("EggModel", "ServerScriptService/Modules/EggModel.lua", "ServerScriptService → Modules", M),
    ("HatcheryService", "ServerScriptService/Modules/HatcheryService.lua", "ServerScriptService → Modules", M),
    ("EconomyManager", "ServerScriptService/EconomyManager.server.lua", "ServerScriptService", "Script"),
    ("BoothManager", "ServerScriptService/BoothManager.server.lua", "ServerScriptService", "Script"),
    ("MarketplaceHook", "ServerScriptService/MarketplaceHook.server.lua", "ServerScriptService", "Script"),
    ("LeaderboardService", "ServerScriptService/LeaderboardService.server.lua", "ServerScriptService", "Script"),
    ("BoothAdapter", "ServerScriptService/BoothAdapter.server.lua", "ServerScriptService", "Script"),
    ("EggClient", "StarterGui/EggClient.client.lua", "StarterGui", "LocalScript"),
    ("MapFX", "StarterPlayer/StarterPlayerScripts/MapFX.client.lua", "StarterPlayer → StarterPlayerScripts", "LocalScript"),
]

data = [dict(name=n, type=t, where=w, code=open(f"{ROOT}/{p}", encoding="utf-8").read()) for n, p, w, t in FILES]
payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")

TEMPLATE = open(__file__.rsplit("/", 1)[0] + "/install_page_template.html", encoding="utf-8").read()
html = TEMPLATE.replace("__MODULE_COUNT__", str(sum(1 for f in FILES if f[3] == M))).replace("__PAYLOAD__", payload).replace("__TOTAL__", str(len(FILES)))
open(sys.argv[1], "w", encoding="utf-8").write(html)
print("yazildi:", sys.argv[1], len(html), "bayt,", len(FILES), "dosya")
